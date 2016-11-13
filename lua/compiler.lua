require 'core'
require 'reader'

clue = clue or {}
clue.compiler = clue.compiler or {}

clue.compiler.LIST = clue.symbol("lua", "clue.list")
clue.compiler.SYMBOL = clue.symbol("lua", "clue.symbol")

function clue.compiler.translate_and_concat_expressions(ns, locals, delimiter, exprs)
    local translated = {}
    exprs = clue.seq(exprs)
    while exprs do
        table.insert(translated, clue.compiler.translate_expr(ns, locals, exprs:first()))
        exprs = exprs:next()
    end
    return table.concat(translated, delimiter)
end

function clue.compiler.translate_fn(ns, locals, exprs)
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
        locals = clue.set_union(locals, clue.to_set(param_names))
        if va_name then
            locals[va_name] = true
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
            table.insert(translated, clue.compiler.translate_expr(ns, locals, exprs:first()))
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

clue.compiler.special_forms = {
    fn = function(ns, locals, meta, fns)
        if fns.size > 0 and clue.type(fns:first()) == clue.Vector then
            fns = clue.list(fns)
        end
        return clue.compiler.translate_fn(ns, locals, fns) .. clue.compiler.translate_meta(meta)
    end,
    def = function(ns, locals, meta, args)
        local sym, value = clue.first(args), clue.second(args)
        return "(function() clue.namespaces[\"" .. ns.name .. "\"][\"" .. sym.name .. "\"] = " .. clue.compiler.translate_expr(ns, {}, value) .. " end)()"
    end,
    let = function(ns, locals, meta, args)
        local defs, exprs = clue.first(args), clue.next(args)
        if not exprs and defs.size == 0 then
            return "nil"
        end
        local translated = {}
        local locals = clue.set_union(locals, {})
        for i = 1, defs.size, 2 do
            table.insert(translated, "local " .. defs[i].name .. " = " .. clue.compiler.translate_expr(ns, locals, defs[i + 1]))
            locals[defs[i].name] = true
        end
        local expr = clue.seq(exprs)
        while expr do
            table.insert(translated, clue.compiler.translate_expr(ns, locals, expr:first()))
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
        local aliases = {}
        if requires then
            local reqs = {}
            requires = clue.seq(requires):next()
            while requires do
                local req = requires:first()
                local req_ns, req_alias
                if clue.type(req) == clue.Vector then
                    req_ns = req[1].name
                    req_alias = req[3].name
                    aliases[req_alias] = req_ns
                else
                    req_ns = req.name
                    req_alias = req_ns
                end
                table.insert(reqs, "[\"" .. req_alias .. "\"" .. "] = " .. "\"" .. req_ns .. "\"")
                requires = requires:next()
            end
            translated_reqs = ", " .. "{" .. table.concat(reqs, ", ") .. "}"
        end
        return "clue.ns(\"" .. sym.name .. "\"" .. translated_reqs .. ")", {name = sym.name, aliases = aliases}
    end,
    ["+"] = function(ns, locals, meta, args)
        return "(" .. clue.compiler.translate_and_concat_expressions(ns, locals, " + ", args) .. ")"
    end,
    ["-"] = function(ns, locals, meta, args)
        local translated = clue.compiler.translate_and_concat_expressions(ns, locals, " - ", args)
        if args.size == 1 then
            translated = "-" .. translated
        end
        return "(" .. translated .. ")"
    end,
    ["*"] = function(ns, locals, meta, args)
        return "(" .. clue.compiler.translate_and_concat_expressions(ns, locals, " * ", args) .. ")"
    end,
    ["/"] = function(ns, locals, meta, args)
        return "(" .. clue.compiler.translate_and_concat_expressions(ns, locals, " / ", args) .. ")"
    end,
    ["%"] = function(ns, locals, meta, args)
        return "(" .. clue.compiler.translate_and_concat_expressions(ns, locals, " % ", args) .. ")"
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
                table.insert(translated, clue.compiler.translate_expr(ns, locals, call:first()))
                call = call:next()
            end
            args = "(" .. table.concat(translated, ", ") .. ")"
        else
            name = call.name
            args = ""
            op = "."
        end
        return clue.compiler.translate_expr(ns, locals, instance) .. op .. name .. args
    end,
    ["if"] = function(ns, locals, meta, args)
        local cond, then_, else_ = clue.first(args), clue.second(args), clue.nth(args, 2)
        return "(function() if (" .. clue.compiler.translate_expr(ns, locals, cond) .. ") then " ..
            "return " .. clue.compiler.translate_expr(ns, locals, then_) .. "; else " ..
            "return " .. clue.compiler.translate_expr(ns, locals, else_) .. "; end end)()"
    end,
    ["do"] = function(ns, locals, meta, exprs)
        if exprs.size == 0 then
            return "nil"
        end
        if exprs.size == 1 then
            return clue.compiler.translate_expr(ns, locals, exprs:first())
        end
        local translated = {}
        exprs = clue.seq(exprs)
        while exprs do
            table.insert(translated, clue.compiler.translate_expr(ns, locals, exprs:first()))
            exprs = exprs:next()
        end
        translated[#translated] = "return " .. translated[#translated]
        return "(function() " .. table.concat(translated, "; ") .. "; end)()"
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
                return clue.list(clue.compiler.SYMBOL, s.name)
            end
            return clue.list(clue.compiler.SYMBOL, s.ns, s.name)
        end
        local function quote_map(m)
            local q = clue.map()
            m:each(function(k, v) q = q:assoc(quote_expr(k), quote_expr(v)) end)
            return q
        end
        quote_expr = function(expr)
            local etype = clue.type(expr)
            if clue.type(expr) == clue.List then
                if expr:empty() then
                    return clue.list(clue.compiler.LIST)
                end
                return quote_list(expr):cons(clue.compiler.LIST)
            end
            if clue.type(expr) == clue.Symbol then
                return quote_symbol(expr)
            end
            if clue.type(expr) == clue.Vector then
                return quote_vector(expr)
            end
            if clue.type(expr) == clue.Map then
                return quote_map(expr)
            end
            return expr
        end
        return clue.compiler.translate_expr(ns, locals, quote_expr(exprs:first()))
    end
}

clue.compiler.macros = {
    ["lazy-seq"] = function(args)
        return clue.list(clue.symbol("lua", "clue.lazy_seq"), clue.list(clue.symbol("fn"), clue.vector(), clue.first(args)))
    end
}

function clue.compiler.translate_call(ns, locals, meta, form)
    local fn, args = clue.first(form), (form:next() or clue.list())
    if clue.is_symbol(fn) and fn.ns == nil and clue.compiler.special_forms[fn.name] then
        if fn.name == "fn" then
            return clue.compiler.special_forms[fn.name](ns, locals, meta, args)
        end
        return clue.compiler.special_forms[fn.name](ns, locals, meta, args)
    end
    if clue.is_symbol(fn) and fn.ns == nil and clue.compiler.macros[fn.name] then
        return clue.compiler.translate_expr(ns, locals, clue.compiler.macros[fn.name](args))
    end
    local translated = {}
    args = clue.seq(args)
    while args do
        local te = clue.compiler.translate_expr(ns, locals, args:first())
        table.insert(translated, te)
        args = args:next()
    end
    return clue.compiler.translate_expr(ns, locals, fn) .. "(" .. table.concat(translated, ", ") .. ")"
end

function clue.compiler.translate_meta(meta)
    if not meta then
        return ""
    end
    return ":with_meta(" .. clue.compiler.translate_map(nil, nil, meta) .. ")"
end

function clue.compiler.translate_vector(ns, locals, vector)
    local translated = {}
    for i=1,vector.size do
        table.insert(translated, clue.compiler.translate_expr(ns, locals, vector[i]))
    end
    return "clue.vector(" .. table.concat(translated, ", ").. ")" .. clue.compiler.translate_meta(vector.meta)
end

function clue.compiler.translate_map(ns, locals, map)
    local translated = {}
    map:each(function(k, v)
        table.insert(translated, clue.compiler.translate_expr(ns, locals, k) .. ", " .. clue.compiler.translate_expr(ns, locals, v))
    end)
    return "clue.map(" .. table.concat(translated, ", ").. ")" .. clue.compiler.translate_meta(map.meta)
end

function clue.compiler.resolve_ns(ns, locals, sym)
    if not sym.ns then
        if locals[sym.name] then
            return nil
        end
        return ns.name
    end
    local resolved_ns = ns.aliases and ns.aliases[sym.ns] or sym.ns
    if resolved_ns == "lua" then
        return nil
    end
    return resolved_ns
end

function clue.compiler.resolve_symbol(ns, locals, sym)
    return clue.symbol(clue.compiler.resolve_ns(sym), sym.name)
end

function clue.compiler.translate_symbol(ns, locals, expr)
    local resolved_ns = clue.compiler.resolve_ns(ns, locals, expr)
    if not resolved_ns then
        return expr.name
    end
    return "clue.namespaces[\"" .. resolved_ns .. "\"][\"" .. expr.name .. "\"]"
end

function clue.compiler.translate_keyword(ns, locals, expr)
    if expr.ns then
        return "clue.keyword(\"" .. expr.ns .. "\", \"" .. expr.name .. "\")" .. clue.compiler.translate_meta(expr.meta)
    end
    return "clue.keyword(\"" .. expr.name .. "\")" .. clue.compiler.translate_meta(expr.meta)
end

function clue.compiler.translate_expr(ns, locals, expr)
    local etype = clue.type(expr)
    if etype == "string" then
        return "\"" .. expr .. "\""
    end
    if type(expr) ~= "table" then
        return tostring(expr)
    end
    if etype == clue.List then
        return clue.compiler.translate_call(ns, locals, expr.meta, expr)
    elseif etype == clue.Symbol then
        return clue.compiler.translate_symbol(ns, locals, expr)
    elseif etype == clue.Keyword then
        return clue.compiler.translate_keyword(ns, locals, expr)
    elseif etype == clue.Vector then
        return clue.compiler.translate_vector(ns, locals, expr)
    elseif etype == clue.Map then
        return clue.compiler.translate_map(ns, locals, expr)
    elseif etype == "table" then
        return tostring(expr)
    else
        error("unexpected expression type")
    end
end

function clue.compiler.translate(ns, exprs)
    local translated = {}
    local expr = clue.seq(exprs)
    while expr do
        local t, new_ns = clue.compiler.translate_expr(ns, {}, expr:first())
        if new_ns then ns = new_ns end
    	table.insert(translated, t)
        expr = expr:next()
    end
    return table.concat(translated, ";\n")
end

function clue.compiler.compile(ns, source)
    return clue.compiler.translate(ns, clue.reader.read(source))
end

function clue.compiler.read_file(path)
    local file = io.open(path, "rb")
    if not file then error("Cannot read file " .. path) end
    local content = file:read("*a")
    file:close()
    return content
end

function clue.compiler.compile_file(filename)
    return clue.compiler.compile(nil, clue.compiler.read_file(filename))
end
