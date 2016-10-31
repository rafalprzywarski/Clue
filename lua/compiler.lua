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
                if requires[i].type == 'vector' then
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
        if call.type == "list" then
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
        if else_ == nil then
            else_ = clue.nil_
        end
        return "(function() if (" .. clue.compiler.translate_expr(ns, locals, cond) .. ") then " ..
            "return " .. clue.compiler.translate_expr(ns, locals, then_) .. "; else " ..
            "return " .. clue.compiler.translate_expr(ns, locals, else_) .. "; end end)()"
    end,
    ["do"] = function(ns, locals, ...)
        if select("#", ...) == 0 then
            return clue.compiler.translate_expr(ns, locals, clue.nil_)
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
    end,
    ["lazy-seq"] = function(ns, locals, body)
        return "clue.lazy_seq(" .. clue.compiler.translate_expr(ns, locals, clue.list(clue.symbol("fn"), clue.vector(), body)) .. ")"
    end
}

function clue.compiler.translate_call(ns, locals, fn, ...)
    if fn.type == "symbol" and fn.ns == nil and clue.compiler.special_forms[fn.name] then
        return clue.compiler.special_forms[fn.name](ns, locals, ...)
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

function clue.compiler.translate_expr(ns, locals, expr)
    if (type(expr)) == "string" then
        return "\"" .. expr .. "\""
    end
    if type(expr) ~= "table" then
        return tostring(expr)
    end
    if expr.nil__ then
        return "nil"
    end
    if expr.type == "list" then
        return clue.compiler.translate_call(ns, locals, expr:unpack())
    elseif expr.type == "symbol" then
        local resolved_ns
        if not expr.ns then
            if locals[expr.name] then
                return expr.name
            end
            resolved_ns = ns.name
        else
            resolved_ns = (ns.aliases or {})[expr.ns] or expr.ns
        end
        if resolved_ns == "lua" then
            return expr.name
        end
        return "clue.namespaces[\"" .. resolved_ns .. "\"][\"" .. expr.name .. "\"]"
    elseif expr.type == "vector" then
        return clue.compiler.translate_vector(ns, locals, expr)
    elseif expr.type == "map" then
        return clue.compiler.translate_map(ns, locals, expr)
    else
        error("unexpected expression type")
    end
end

function clue.compiler.translate(ns, exprs)
    local translated = {}
    for _, expr in ipairs(exprs) do
        local t, new_ns = clue.compiler.translate_expr(ns, {}, expr)
        if new_ns then ns = new_ns end
    	table.insert(translated, t)
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
