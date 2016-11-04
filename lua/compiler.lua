require 'core'
require 'reader'

clue = clue or {}
clue.compiler = clue.compiler or {}

function clue.compiler.translate_and_concat_expressions(ns, locals, delimiter, ...)
    local translated = {}
    for i = 1, select("#", ...) do
        table.insert(translated, clue.compiler.translate_expr(ns, locals, select(i, ...)))
    end
    return table.concat(translated, delimiter)
end

clue.compiler.special_forms = {
    fn = function(ns, locals, params, ...)
        local param_names = clue.vector()
        local va_index = nil
        for i=1,params.size do
            if params[i].name == "&" then
                va_index = i + 1
                break
            end
            param_names:append(params[i].name)
        end
        locals = clue.set_union(locals, clue.to_set(param_names))
        if va_index then
            locals[params[va_index].name] = true
        end
        local translated = {}
        if va_index then
            table.insert(translated, "local " .. params[va_index].name .. " = clue.list(...)")
        end
        for i = 1, select("#", ...) do
            table.insert(translated, clue.compiler.translate_expr(ns, locals, select(i, ...)))
        end
        translated[#translated] = "return " .. translated[#translated]
        if va_index then
            param_names:append("...")
        end
        return "(function(" .. param_names:concat(", ") .. ") " .. table.concat(translated, "; ") .. " end)"
    end,
    def = function(ns, locals, sym, value)
        return "clue.namespaces[\"" .. ns.name .. "\"][\"" .. sym.name .. "\"] = " .. clue.compiler.translate_expr(ns, {}, value)
    end,
    let = function(ns, locals, defs, ...)
        if select("#", ...) == 0 and defs.size == 0 then
            return "nil"
        end
        local translated = {}
        local locals = clue.set_union(locals, {})
        for i = 1, defs.size, 2 do
            table.insert(translated, "local " .. defs[i].name .. " = " .. clue.compiler.translate_expr(ns, locals, defs[i + 1]))
            locals[defs[i].name] = true
        end
        for i = 1, select("#", ...) do
            table.insert(translated, clue.compiler.translate_expr(ns, locals, select(i, ...)))
        end
        if select("#", ...) == 0 then
            table.insert(translated, "nil")
        end
        translated[#translated] = "return " .. translated[#translated]
        return "(function() " .. table.concat(translated, "; ") .. " end)()"
    end,
    ns = function(ns, locals, sym, requires)
        local translated_reqs = ""
        local aliases = {}
        if requires then
            local reqs = {}
            for i=2,requires.size do
                local req_ns, req_alias
                if clue.type(requires[i]) == 'vector' then
                    req_ns = requires[i][1].name
                    req_alias = requires[i][3].name
                    aliases[req_alias] = req_ns
                else
                    req_ns = requires[i].name
                    req_alias = req_ns
                end
                table.insert(reqs, "[\"" .. req_alias .. "\"" .. "] = " .. "\"" .. req_ns .. "\"")
            end
            translated_reqs = ", " .. "{" .. table.concat(reqs, ", ") .. "}"
        end
        return "clue.ns(\"" .. sym.name .. "\"" .. translated_reqs .. ")", {name = sym.name, aliases = aliases}
    end,
    ["+"] = function(ns, locals, ...)
        return "(" .. clue.compiler.translate_and_concat_expressions(ns, locals, " + ", ...) .. ")"
    end,
    ["-"] = function(ns, locals, ...)
        local translated = clue.compiler.translate_and_concat_expressions(ns, locals, " - ", ...)
        if select("#", ...) == 1 then
            translated = "-" .. translated
        end
        return "(" .. translated .. ")"
    end,
    ["*"] = function(ns, locals, ...)
        return "(" .. clue.compiler.translate_and_concat_expressions(ns, locals, " * ", ...) .. ")"
    end,
    ["/"] = function(ns, locals, ...)
        return "(" .. clue.compiler.translate_and_concat_expressions(ns, locals, " / ", ...) .. ")"
    end,
    ["%"] = function(ns, locals, ...)
        return "(" .. clue.compiler.translate_and_concat_expressions(ns, locals, " % ", ...) .. ")"
    end,
    ["."] = function(ns, locals, instance, call)
        local name, args, op
        if clue.type(call) == "list" then
            name = call[1].name
            args = "("
            op = ":"
            for i = 2,call.size do
                if i > 2 then args = args .. ", " end
                args = args .. clue.compiler.translate_expr(ns, locals, call[i])
            end
            args = args .. ")"
        else
            name = call.name
            args = ""
            op = "."
        end
        return clue.compiler.translate_expr(ns, locals, instance) .. op .. name .. args
    end,
    ["if"] = function(ns, locals, cond, then_, else_)
        return "(function() if (" .. clue.compiler.translate_expr(ns, locals, cond) .. ") then " ..
            "return " .. clue.compiler.translate_expr(ns, locals, then_) .. "; else " ..
            "return " .. clue.compiler.translate_expr(ns, locals, else_) .. "; end end)()"
    end,
    ["do"] = function(ns, locals, ...)
        if select("#", ...) == 0 then
            return "nil"
        end
        if select("#", ...) == 1 then
            return clue.compiler.translate_expr(ns, locals, select(1, ...))
        end
        local translated = {}
        for i = 1, select("#", ...) do
            table.insert(translated, clue.compiler.translate_expr(ns, locals, select(i, ...)))
        end
        translated[#translated] = "return " .. translated[#translated]
        return "(function() " .. table.concat(translated, "; ") .. "; end)()"
    end
}

clue.compiler.macros = {
    ["lazy-seq"] = function(body)
        return clue.list(clue.symbol("lua", "clue.lazy_seq"), clue.list(clue.symbol("fn"), clue.vector(), body))
    end
}

function clue.compiler.translate_call(ns, locals, fn, ...)
    if clue.is_symbol(fn) and fn.ns == nil and clue.compiler.special_forms[fn.name] then
        return clue.compiler.special_forms[fn.name](ns, locals, ...)
    end
    if clue.is_symbol(fn) and fn.ns == nil and clue.compiler.macros[fn.name] then
        return clue.compiler.translate_expr(ns, locals, clue.compiler.macros[fn.name](...))
    end
    local s = clue.compiler.translate_expr(ns, locals, fn) .. "(";
    for i = 1, select("#", ...) do
        if i > 1 then s = s .. ", " end
        s = s .. clue.compiler.translate_expr(ns, locals, select(i, ...))
    end
    return s .. ")"
end

function clue.compiler.translate_vector(ns, locals, vector)
    local translated = {}
    for i=1,vector.size do
        table.insert(translated, clue.compiler.translate_expr(ns, locals, vector[i]))
    end
    return "clue.vector(" .. table.concat(translated, ", ").. ")"
end

function clue.compiler.translate_map(ns, locals, map)
    local translated = {}
    map:each(function(k, v)
        table.insert(translated, clue.compiler.translate_expr(ns, locals, k) .. ", " .. clue.compiler.translate_expr(ns, locals, v))
    end)
    return "clue.map(" .. table.concat(translated, ", ").. ")"
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

function clue.compiler.translate_expr(ns, locals, expr)
    local etype = clue.type(expr)
    if (type(expr)) == "string" then
        return "\"" .. expr .. "\""
    end
    if type(expr) ~= "table" then
        return tostring(expr)
    end
    if etype == "list" then
        return clue.compiler.translate_call(ns, locals, expr:unpack())
    elseif etype == "symbol" then
        local resolved_ns = clue.compiler.resolve_ns(ns, locals, expr)
        if not resolved_ns then
            return expr.name
        end
        return "clue.namespaces[\"" .. resolved_ns .. "\"][\"" .. expr.name .. "\"]"
    elseif etype == "keyword" then
        if expr.ns then
            return "clue.keyword(\"" .. expr.ns .. "\", \"" .. expr.name .. "\")"
        end
        return "clue.keyword(\"" .. expr.name .. "\")"
    elseif etype == "vector" then
        return clue.compiler.translate_vector(ns, locals, expr)
    elseif etype == "map" then
        return clue.compiler.translate_map(ns, locals, expr)
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
