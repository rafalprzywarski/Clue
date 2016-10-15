require 'core'
require 'reader'

clue = clue or {}
clue.compiler = clue.compiler or {}
clue.compiler.special_forms = {
    fn = function(params, ...)
        local param_names = clue.map_array(function(s) return s.name end, params.value)
        local locals = clue.to_set(param_names)
        local translated = {}
        for i = 1, select("#", ...) do
            table.insert(translated, clue.compiler.translate_expr(locals, select(i, ...)))
        end
        translated[#translated] = "return " .. translated[#translated]
        return "function(" .. table.concat(param_names, ", ") .. ") " .. table.concat(translated, "; ") .. " end"
    end
}

function clue.compiler.translate_call(locals, fn, ...)
    if fn.type == "symbol" and fn.ns == nil and clue.compiler.special_forms[fn.name] then
        return clue.compiler.special_forms[fn.name](...)
    end
    local s = clue.compiler.translate_expr(locals, fn) .. "(";
    for i = 1, select("#", ...) do
        if i > 1 then s = s .. ", " end
        s = s .. clue.compiler.translate_expr(locals, select(i, ...))
    end
    return s .. ")"
end

function clue.compiler.translate_vector(locals, vector)
    local translated = {}
    for _, v in ipairs(vector) do
        table.insert(translated, clue.compiler.translate_expr(locals, v))
    end
    return "{" .. table.concat(translated, ", ").. "}"
end

function clue.compiler.translate_expr(locals, expr)
    if type(expr) ~= "table" then
        return tostring(expr)
    end
    if expr.type == "list" then
        return clue.compiler.translate_call(locals, unpack(expr.value))
    elseif expr.type == "symbol" then
        if not expr.ns then
            if locals[expr.name] then
                return expr.name
            end
            return "clue._ns_[\"" .. expr.name .. "\"]"
        end
        return "clue.var(\"" .. expr.ns .. "\", \"" .. expr.name .. "\")"
    elseif expr.type == "vector" then
        return clue.compiler.translate_vector(locals, expr.value)
    else
        error("unexpected expression type")
    end
end

function clue.compiler.translate(exprs)
    local s = ""
    for _, expr in ipairs(exprs) do
    	s = s .. clue.compiler.translate_expr({}, expr)
    end
    return s
end

function clue.compiler.compile(source)
    return clue.compiler.translate(clue.reader.read(source))
end
