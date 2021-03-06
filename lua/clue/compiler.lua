require 'clue.core'
require 'clue.reader'

clue.compiler = {}
local M = clue.compiler

M.LIST = clue.symbol("lua", "clue.list")
M.SYMBOL = clue.symbol("lua", "clue.symbol")
M.QUOTE = clue.symbol("quote")
M.CONCAT = clue.symbol("clue.core", "concat")
M.SEQ = clue.symbol("clue.core", "seq")
M.VEC = clue.symbol("clue.core", "vec")
M.UNQUOTE_SPLICING = clue.symbol("unquote-splicing")
M.UNQUOTE = clue.symbol("unquote")

function M.translate_and_concat_expressions(ns, locals, delimiter, exprs, opt)
    local translated = {}
    exprs = clue.seq(exprs)
    while exprs do
        table.insert(translated, M.translate_expr(ns, locals, exprs:first()))
        exprs = exprs:next()
    end
    if opt == "return-last" then
        translated[#translated] = "return " .. translated[#translated]
    end
    return table.concat(translated, delimiter)
end

function M.translate_fn(ns, locals, exprs)
    local function parse_params(params)
        local param_names = clue.vector()
        local va_name = nil
        for i=1,params.size do
            if params[i].name == "&" then
                va_name = params[i + 1].name
                param_names:append("...")
                break
            end
            param_names:append(params[i].name)
        end
        return param_names, va_name
    end
    local function add_locals(locals, param_names, va_name)
        locals = locals:merge(clue.to_self_map(param_names))
        if va_name then
            locals = locals:assoc(va_name, va_name)
        end
        return locals
    end
    local function partial_body(ns, locals, va_name, exprs)
        local translated = {}
        if va_name then
            table.insert(translated, "local " .. va_name .. " = clue.list(...)")
        end
        exprs = clue.seq(exprs)
        while exprs do
            table.insert(translated, M.translate_expr(ns, locals, exprs:first()))
            exprs = exprs:next()
        end
        translated[#translated] = "return " .. translated[#translated]
        return table.concat(translated, "; ")
    end
    local function function_wrap(param_names, body)
        return "(function(" .. param_names:concat(", ") .. ") " .. body .. " end)"
    end
    local function translate_body(ns, locals, params, exprs)
        local param_names, va_name = parse_params(params)
        locals = add_locals(locals, param_names, va_name)
        local body = partial_body(ns, locals, va_name, exprs)
        if param_names.size > 0 then
            body = function_wrap(param_names, body)
        end
        if param_names.size > 0 and not va_name or param_names.size > 1 then
            body = "return " .. body .. "(...)"
        end
        local cond, va_n
        if va_name then
            va_n = param_names.size - 1
            if param_names.size > 1 then
                cond = ">= " .. (param_names.size - 1)
            end
        else
            cond = "== " .. param_names.size
        end
        if cond then
            body = "if arg_count_ " .. cond .. " then " .. body .. " end"
        end
        return body, va_n
    end
    local bodies = {}
    local va_body, va_n
    exprs = clue.seq(exprs)
    while exprs do
        local params_and_exprs = exprs:first()
        local body, n = translate_body(ns, locals, params_and_exprs:first(), params_and_exprs:next())
        if n then
            va_body = body
            va_n = n
        else
            table.insert(bodies, body)
        end
        exprs = exprs:next()
    end
    if #bodies == 0 and va_n == 0 then
        return "clue.fn" .. va_body
    end
    if va_body then
        table.insert(bodies, va_body)
    end
    table.insert(bodies, "clue.arg_count_error(arg_count_);")
    return "clue.fn(function(...) local arg_count_ = select(\"#\", ...); " .. table.concat(bodies, "; ") .. " end)"
end

function M.syntax_quote(ns, expr)
    local quote_expr
    local function quote_list_items(ns, gens, l)
        local first = l:first()
        local next = l:next()
        local qfirst
        if clue.type(first) == clue.List and first:first() == M.UNQUOTE_SPLICING then
            qfirst = clue.second(first)
        else
            qfirst = clue.list(M.LIST, quote_expr(ns, gens, first))
        end
        if not next then
            return clue.list(qfirst)
        end
        return quote_list_items(ns, gens, next):cons(qfirst)
    end
    local function quote_list(ns, gens, l)
        if l:empty() then
            return clue.list(M.LIST)
        end
        if l:first() == M.UNQUOTE then
            return l:next():first()
        end
        return clue.list(M.SEQ, quote_list_items(ns, gens, l):cons(M.CONCAT))
    end
    local function quote_vector(ns, gens, v)
        if v:empty() then
            return clue.vector()
        end
        return clue.list(M.VEC, quote_list_items(ns, gens, v):cons(M.CONCAT))
    end
    local function quote_symbol(ns, gens, s)
        if s.name:sub(s.name:len()) == "#" then
            local gname = gens[s.name]
            if not gname then
                ns.gen_index = (ns.gen_index or 0) + 1
                gname = s.name:sub(1, s.name:len() - 1) .. "__" .. ns.gen_index .. "__auto__"
                gens[s.name] = gname
            end
            s = clue.symbol(gname)
        else
            local rs = M.resolve_symbol(ns, clue.hash_map(), s)
            if not rs then
                rs = clue.symbol(s.ns or ns.name, s.name)
            end
            s = rs
        end
        return clue.list(M.QUOTE, s)
    end
    local function quote_map(ns, gens, m)
        local q = clue.hash_map()
        m:each(function(k, v) q = q:assoc(quote_expr(ns, gens, k), quote_expr(ns, gens, v)) end)
        return q
    end
    quote_expr = function(ns, gens, expr)
        local etype = clue.type(expr)
        if clue.type(expr) == clue.List then
            return quote_list(ns, gens, expr)
        end
        if clue.type(expr) == clue.Symbol then
            return quote_symbol(ns, gens, expr)
        end
        if clue.type(expr) == clue.Vector then
            return quote_vector(ns, gens, expr)
        end
        if clue.type(expr) == clue.HashMap then
            return quote_map(ns, gens, expr)
        end
        return expr
    end
    local gens = {}
    return quote_expr(ns, gens, expr)
end

M.special_forms = {
    fn = function(ns, locals, meta, fns)
        if fns.size > 0 and clue.type(fns:first()) == clue.Vector then
            fns = clue.list(fns)
        end
        return M.translate_fn(ns, locals, fns) .. M.translate_meta(meta)
    end,
    def = function(ns, locals, meta, args)
        local sym, value = clue.first(args), clue.second(args)
        local var = clue.Var.new(ns.name, sym.name):with_meta(sym.meta)
        ns:add(var)
        local val = loadstring("return " .. M.translate_expr(ns, clue.hash_map(), value))
        var:reset(val())
        return "clue.def(\"" .. ns.name .. "\", \"" .. sym.name .. "\", " .. M.translate_expr(ns, clue.hash_map(), value) .. ", " .. M.translate_expr(nil, nil, sym.meta) .. ")"
    end,
    var = function(ns, locals, meta, args)
        local sym = clue.first(args)
        sym = M.resolve_var(ns, locals, sym)
        return "clue.var(\"" .. sym.ns .. "\", \"" .. sym.name  .. "\")"
    end,
    let = function(ns, locals, meta, args)
        local defs, exprs = clue.first(args), clue.next(args)
        if not exprs and defs.size == 0 then
            return "nil"
        end
        local translated = {}
        for i = 1, defs.size, 2 do
            table.insert(translated, "local " .. defs[i].name .. " = " .. M.translate_expr(ns, locals, defs[i + 1]))
            locals = locals:assoc(defs[i].name, defs[i].name)
        end
        local expr = clue.seq(exprs)
        while expr do
            table.insert(translated, M.translate_expr(ns, locals, expr:first()))
            expr = expr:next()
        end
        if not exprs then
            table.insert(translated, "nil")
        end
        translated[#translated] = "return " .. translated[#translated]
        return "(function() " .. table.concat(translated, "; ") .. " end)()"
    end,
    ns = function(ns, locals, meta, args)
        local sym, requires = clue.first(args), clue.second(args)
        local translated_reqs = ""
        local aliases = clue.hash_map()
        if requires then
            local reqs = {}
            requires = clue.seq(requires):next()
            while requires do
                local req = requires:first()
                local req_ns, req_alias
                if clue.type(req) == clue.Vector then
                    req_ns = req[1].name
                    req_alias = req[3].name
                    aliases = aliases:assoc(req_alias, req_ns)
                else
                    req_ns = req.name
                    req_alias = req_ns
                end
                table.insert(reqs, "\"" .. req_alias .. "\", \"" .. req_ns .. "\"")
                requires = requires:next()
            end
            translated_reqs = ", " .. "clue.hash_map(" .. table.concat(reqs, ", ") .. ")"
        end
        clue.ns(sym.name, aliases)
        return "clue.ns(\"" .. sym.name .. "\"" .. translated_reqs .. ")"
    end,
    ["in-ns"] = function(ns, locals, meta, args)
        local sym = clue.first(args)
        clue.in_ns(sym.name)
        return "clue.in_ns(\"" .. sym.name .. "\")"
    end,
    ["."] = function(ns, locals, meta, dargs)
        local instance, call = clue.first(dargs), clue.second(dargs)
        local name, args, op
        if clue.type(call) == clue.List then
            name = call:first().name
            args = "("
            op = ":"
            call = call:next()
            local translated = {}
            while call do
                table.insert(translated, M.translate_expr(ns, locals, call:first()))
                call = call:next()
            end
            args = "(" .. table.concat(translated, ", ") .. ")"
        else
            name = call.name
            args = ""
            op = "."
        end
        return M.translate_expr(ns, locals, instance) .. op .. name .. args
    end,
    ["if"] = function(ns, locals, meta, args)
        local cond, then_, else_ = clue.first(args), clue.second(args), clue.nth(args, 2)
        return "(function() if (" .. M.translate_expr(ns, locals, cond) .. ") then " ..
            "return " .. M.translate_expr(ns, locals, then_) .. "; else " ..
            "return " .. M.translate_expr(ns, locals, else_) .. "; end end)()"
    end,
    ["do"] = function(ns, locals, meta, exprs)
        if exprs.size == 0 then
            return "nil"
        end
        if exprs.size == 1 then
            return M.translate_expr(ns, locals, exprs:first())
        end
        return "(function() " .. M.translate_and_concat_expressions(ns, locals, "; ", exprs, "return-last") .. "; end)()"
    end,
    ["quote"] = function(ns, locals, meta, exprs)
        local quote_expr
        local function quote_list(l)
            if not l then
                return nil
            end
            local next = l:next()
            if not next then
                return clue.list(quote_expr(l:first()))
            end
            return quote_list(l:next()):cons(quote_expr(l:first()))
        end
        local function quote_vector(v)
            local q = clue.vector()
            for i=0,v.size - 1 do
                q:append(quote_expr(v:at(i)))
            end
            return q
        end
        local function quote_symbol(s)
            if not s.ns then
                return clue.list(M.SYMBOL, s.name)
            end
            return clue.list(M.SYMBOL, s.ns, s.name)
        end
        local function quote_map(m)
            local q = clue.hash_map()
            m:each(function(k, v) q = q:assoc(quote_expr(k), quote_expr(v)) end)
            return q
        end
        quote_expr = function(expr)
            local etype = clue.type(expr)
            if clue.type(expr) == clue.List then
                if expr:empty() then
                    return clue.list(M.LIST)
                end
                return quote_list(expr):cons(M.LIST)
            end
            if clue.type(expr) == clue.Symbol then
                return quote_symbol(expr)
            end
            if clue.type(expr) == clue.Vector then
                return quote_vector(expr)
            end
            if clue.type(expr) == clue.HashMap then
                return quote_map(expr)
            end
            return expr
        end
        return M.translate_expr(ns, locals, quote_expr(exprs:first()))
    end,
    ["syntax-quote"] = function(ns, locals, meta, exprs)
        return M.translate_expr(ns, locals, M.syntax_quote(ns, exprs:first()))
    end,
    try = function(ns, locals, meta, exprs)
        exprs = clue.seq(exprs)
        local to_try = clue.vector()
        while exprs and exprs:first():first() ~= clue.symbol("finally") do
            to_try:append(exprs:first())
            exprs = exprs:next()
        end

        return "(function() local ok, val = pcall(function() " .. M.translate_and_concat_expressions(ns, locals, "; ", to_try, "return-last") .. "; end); " .. M.translate_and_concat_expressions(ns, locals, "; ", exprs:first():next()) .. "; if ok then return val else error(val) end end)()"
    end,
    ["finally"] = function()
        error("finally without try")
    end,
    ["deftype"] = function(ns, locals, meta, exprs)
        exprs = clue.seq(exprs)
        local name, fields, sigs = clue.first(exprs), clue.second(exprs), clue.nnext(exprs)
        local self_fields = {}
        local source_fields = {}
        local args = {}
        local field_names = {}
        local fields = clue.seq(fields)
        while fields do
            local field = fields:first().name
            table.insert(field_names, field)
            table.insert(args, ", " .. field)
            table.insert(self_fields, "self." .. field)
            table.insert(source_fields, field)
            fields = fields:next()
        end
        local init = ""
        if #self_fields > 0 then
            init = table.concat(self_fields, ", ") .. " = " .. table.concat(source_fields, ", ") .. " "
        end
        local tsigs = {}
        if sigs then
            local protocol = sigs:first().name
            sigs = sigs:next()
            while sigs do
                local sig = sigs:first()
                local prefixed_fields = clue.hash_map()
                for _, f in ipairs(field_names) do
                    prefixed_fields = prefixed_fields:assoc(f, clue.first(clue.second(sig)).name .. "." .. f)
                end
                table.insert(tsigs, ", \"" .. ns.name .. "/" .. protocol .. "." .. clue.first(sig).name .. "__" .. clue.second(sig).size .. "\", " .. M.translate_fn(ns, locals:merge(prefixed_fields), clue.list(clue.next(sig))))
                sigs = sigs:next()
            end
        end
        local def = "clue.def_type(\"" .. name.name .. "\", function(self" .. table.concat(args) .. ") " .. init .. "end" .. table.concat(tsigs) .. ")"
        loadstring(def)()
        return def
    end,
    ["defprotocol"] = function(ns, locals, meta, exprs)
        exprs = clue.seq(exprs)
        local name, sigs = clue.first(exprs).name, clue.next(exprs)
        local proto_def = "clue.def(\"".. ns.name .. "\", \"" .. name .. "\", clue.Protocol.new(clue.symbol(\"" .. ns.name .. "\", \"" .. name .. "\")))"
        local defs = {proto_def}
        while sigs do
            local sig = clue.first(sigs)
            local mname, param_groups = clue.first(sig).name, clue.next(sig)
            local rets = {}
            local should_check = clue.next(param_groups) ~= nil
            while param_groups do
                local params = clue.first(param_groups)
                local this = "select(1, ...)"
                local ret = "return (" .. this .. "[\"".. ns.name .. "/" .. name .. "." .. mname .. "__" .. params.size .. "\"] or clue.var(\"" .. ns.name .. "\", \"" .. name .. "\"):get().extended:at(\"" .. mname .. "\"):at(tostring(clue.type(select(1, ...)))))(...)"
                if should_check then
                    ret = "if arg_count_ == " .. params.size .. " then " .. ret .. " end;"
                end
                table.insert(rets, ret)
                param_groups = clue.next(param_groups)
            end
            local body = table.concat(rets, " ")
            if should_check then
                body = "local arg_count_ = select(\"#\", ...); " .. body .. " clue.arg_count_error(arg_count_);"
            end
            table.insert(defs, "clue.def(\"" .. ns.name .. "\", \"" .. mname .. "\", clue.fn(function(...) " .. body .. " end), nil)")
            sigs = clue.next(sigs)
        end
        defs = table.concat(defs, "\n")
        loadstring(defs)()
        return defs
    end
}

M.optimized = {
    ["clue.core/+"] = function(ns, locals, meta, args)
        return "(" .. M.translate_and_concat_expressions(ns, locals, " + ", args) .. ")"
    end,
    ["clue.core/-"] = function(ns, locals, meta, args)
        local translated = M.translate_and_concat_expressions(ns, locals, " - ", args)
        if args.size == 1 then
            translated = "-" .. translated
        end
        return "(" .. translated .. ")"
    end,
    ["clue.core/*"] = function(ns, locals, meta, args)
        return "(" .. M.translate_and_concat_expressions(ns, locals, " * ", args) .. ")"
    end,
    ["clue.core//"] = function(ns, locals, meta, args)
        return "(" .. M.translate_and_concat_expressions(ns, locals, " / ", args) .. ")"
    end,
    ["clue.core/%"] = function(ns, locals, meta, args)
        return "(" .. M.translate_and_concat_expressions(ns, locals, " % ", args) .. ")"
    end
}

function M.expand_macro1(ns, locals, meta, form)
    if not clue.is_seq(form) then
        return form
    end
    local fn, args = clue.first(form), (form:next() or clue.list())
    if not clue.is_symbol(fn) then
        return form
    end
    if fn.name:len() > 1 and fn.name:sub(fn.name:len()) == "." then
        return clue.cons(clue.symbol("new"), clue.cons(clue.symbol(fn.ns, fn.name:sub(1, fn.name:len() - 1)), args))
    end
    fn = M.resolve_var(ns, locals, fn)
    if ns and ns:get(fn.name) and ns:get(fn.name):is_macro() then
        return clue.apply_to(ns:get(fn.name):get(), args)
    end
    return form
end

function M.expand_macro(ns, locals, meta, form)
    local ex = M.expand_macro1(ns, locals, meta, form)
    if ex == form then
        return form
    end
    return M.expand_macro(ns, locals, meta, ex)
end

function M.translate_call(ns, locals, meta, form)
    local fn, args = clue.first(form), (form:next() or clue.list())
    if clue.is_symbol(fn) then
        if fn.ns == nil and M.special_forms[fn.name] then
            return M.special_forms[fn.name](ns, locals, meta, args)
        end
        local optimized = M.optimized[tostring(M.resolve_symbol(ns, locals, fn))]
        if optimized then
            return optimized(ns, locals, meta, args)
        end
    end
    local translated = {}
    args = clue.seq(args)
    while args do
        local te = M.translate_expr(ns, locals, args:first())
        table.insert(translated, te)
        args = args:next()
    end
    return M.translate_expr(ns, locals, fn) .. "(" .. table.concat(translated, ", ") .. ")"
end

function M.translate_meta(meta)
    if not meta then
        return ""
    end
    return ":with_meta(" .. M.translate_map(nil, nil, meta) .. ")"
end

function M.translate_vector(ns, locals, vector)
    local translated = {}
    for i=1,vector.size do
        table.insert(translated, M.translate_expr(ns, locals, vector[i]))
    end
    return "clue.vector(" .. table.concat(translated, ", ").. ")" .. M.translate_meta(vector.meta)
end

function M.translate_map(ns, locals, map)
    local translated = {}
    map:each(function(k, v)
        table.insert(translated, M.translate_expr(ns, locals, k) .. ", " .. M.translate_expr(ns, locals, v))
    end)
    return "clue.hash_map(" .. table.concat(translated, ", ").. ")" .. M.translate_meta(map.meta)
end

function M.resolve_symbol(ns, locals, sym)
    local sym_ns = sym.ns
    if sym_ns then
        sym_ns = ns.aliases:at(sym_ns) or sym_ns
    end
    if sym_ns == "lua" then
        return clue.symbol(sym_ns, sym.name)
    end
    if not sym_ns then
        if locals:at(sym.name) then
            return clue.symbol(nil, locals:at(sym.name))
        end
        if M.special_forms[sym.name] then
            return sym
        end
        sym_ns = ns.name
    end
    local var = clue.namespaces:at(sym_ns) and clue.namespaces:at(sym_ns):get(sym.name)
    if not var then
        return nil
    end
    return clue.symbol(var.ns, var.name)
end

function M.resolve_var(ns, locals, sym)
    local r = M.resolve_symbol(ns, locals, sym)
    if not r then
        error("unable to resolve symbol " .. tostring(sym))
    end
    return r
end

function M.translate_symbol(ns, locals, expr)
    local sym = M.resolve_var(ns, locals, expr)
    if not sym.ns or sym.ns == "lua" then
        return sym.name
    end
    return "clue.var(\"" .. sym.ns .. "\", \"" .. sym.name .. "\"):get()"
end

function M.translate_keyword(ns, locals, expr)
    if expr.ns then
        return "clue.keyword(\"" .. expr.ns .. "\", \"" .. expr.name .. "\")" .. M.translate_meta(expr.meta)
    end
    return "clue.keyword(\"" .. expr.name .. "\")" .. M.translate_meta(expr.meta)
end

function M.translate_expr(ns, locals, expr)
    local etype = clue.type(expr)
    if etype == "string" then
        return "\"" .. expr:gsub("\n", "\\n") .. "\""
    end
    if type(expr) ~= "table" then
        return tostring(expr)
    end
    expr = M.expand_macro(ns, locals, expr.meta, expr)
    etype = clue.type(expr)
    if clue.is_seq(expr) then
        return M.translate_call(ns, locals, expr.meta, expr)
    elseif etype == clue.Symbol then
        return M.translate_symbol(ns, locals, expr)
    elseif etype == clue.Keyword then
        return M.translate_keyword(ns, locals, expr)
    elseif etype == clue.Vector then
        return M.translate_vector(ns, locals, expr)
    elseif etype == clue.HashMap then
        return M.translate_map(ns, locals, expr)
    elseif etype == "table" then
        return tostring(expr)
    else
        error("unexpected expression type " .. clue.pr_str(expr))
    end
end

function M.translate(exprs)
    local translated = {}
    local expr = clue.seq(exprs)
    while expr do
        local t = M.translate_expr(clue._ns_, clue.hash_map(), expr:first())
    	table.insert(translated, t)
        expr = expr:next()
    end
    return table.concat(translated, ";\n")
end

function M.compile(source)
    return M.translate(clue.reader.read(source))
end

function M.read_file(path)
    local file = io.open(path, "rb")
    if not file then error("Cannot read file " .. path) end
    local content = file:read("*a")
    file:close()
    return content
end

function M.compile_file(filename)
    clue._file_ = filename
    local c = M.compile(M.read_file(filename))
    clue._file_ = nil
    return c
end

return clue.compiler
