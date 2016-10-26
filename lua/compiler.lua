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
        local param_names = clue.map_array(function(s) return s.name end, params.value)
        locals = clue.set_union(locals, clue.to_set(param_names))
        local translated = {}
        for i = 1, select("#", ...) do
            table.insert(translated, clue.compiler.translate_expr(ns, locals, select(i, ...)))
        end
        translated[#translated] = "return " .. translated[#translated]
        return "(function(" .. table.concat(param_names, ", ") .. ") " .. table.concat(translated, "; ") .. " end)"
    end,
    def = function(ns, locals, sym, value)
        return "clue.namespaces[\"" .. ns.name .. "\"][\"" .. sym.name .. "\"] = " .. clue.compiler.translate_expr(ns, {}, value)
    end,
    let = function(ns, locals, defs, ...)
        if select("#", ...) == 0 and #defs.value == 0 then
            return "clue.nil_"
        end
        local translated = {}
        local locals = clue.set_union(locals, {})
        for i = 1, #defs.value, 2 do
            table.insert(translated, "local " .. defs.value[i].name .. " = " .. clue.compiler.translate_expr(ns, locals, defs.value[i + 1]))
            locals[defs.value[i].name] = true
        end
        for i = 1, select("#", ...) do
            table.insert(translated, clue.compiler.translate_expr(ns, locals, select(i, ...)))
        end
        if select("#", ...) == 0 then
            table.insert(translated, "clue.nil_")
        end
        translated[#translated] = "return " .. translated[#translated]
        return "(function() " .. table.concat(translated, "; ") .. " end)()"
    end,
    ns = function(ns, locals, sym, requires)
        local translated_reqs = ""
        local aliases = {}
        if requires then
            local reqs = {}
            for i=2,#requires.value do
                local req_ns, req_alias
                if requires.value[i].type == 'vector' then
                    req_ns = requires.value[i].value[1].name
                    req_alias = requires.value[i].value[3].name
                    aliases[req_alias] = req_ns
                else
                    req_ns = requires.value[i].name
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
    ["."] = function(ns, locals, ...)
        local args = "(";
        for i = 3, select("#", ...) do
            if i > 3 then args = args .. ", " end
            args = args .. clue.compiler.translate_expr(ns, locals, select(i, ...))
        end
        args = args .. ")"
        return clue.compiler.translate_expr(ns, locals, select(1, ...)) .. "[\"" .. select(2, ...).name .. "\"]" .. args
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
    for _, v in ipairs(vector) do
        table.insert(translated, clue.compiler.translate_expr(ns, locals, v))
    end
    return "{" .. table.concat(translated, ", ").. "}"
end

function clue.compiler.translate_expr(ns, locals, expr)
    if type(expr) ~= "table" then
        return tostring(expr)
    end
    if expr.type == "list" then
        return clue.compiler.translate_call(ns, locals, unpack(expr.value))
    elseif expr.type == "symbol" then
        if not expr.ns then
            if locals[expr.name] then
                return expr.name
            end
            return "clue.namespaces[\"" .. ns.name .. "\"][\"" .. expr.name .. "\"]"
        end
        return "clue.namespaces[\"" .. ((ns.aliases or {})[expr.ns] or expr.ns) .. "\"][\"" .. expr.name .. "\"]"
    elseif expr.type == "vector" then
        return clue.compiler.translate_vector(ns, locals, expr.value)
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
