require 'core'
require 'reader'

clue = clue or {}
clue.compiler = clue.compiler or {}

function clue.compiler.translate_call(fn, ...)
    local s = clue.compiler.translate_expr(fn) .. "(";
    for i = 1, select("#", ...) do
        if i > 1 then s = s .. ", " end
        s = s .. clue.compiler.translate_expr(select(i, ...))
    end
    return s .. ")"
end

function clue.compiler.translate_expr(expr)
    if type(expr) ~= "table" then
        return tostring(expr)
    end
    if expr.type == "list" then
        return clue.compiler.translate_call(unpack(expr.value))
    elseif expr.type == "symbol" then
        if not expr.ns then
            return "clue._ns_[\"" .. expr.name .. "\"]"
        end
        return "clue.var(\"" .. expr.ns .. "\", \"" .. expr.name .. "\")"
    else
        error("unexpected expression type")
    end
end

function clue.compiler.translate(exprs)
    local s = ""
    for _, expr in ipairs(exprs) do
    	s = s .. clue.compiler.translate_expr(expr)
    end
    return s
end

function clue.compiler.compile(source)
    return clue.compiler.translate(clue.reader.read(source))
end
