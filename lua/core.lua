clue = clue or {}

function clue.symbol(ns, name)
    if name == nil then
        name = ns
        ns = nil
    end
    return {type = "symbol", ns = ns, name = name}
end

function clue.list(...)
    return {type = "list", value = {...}}
end

function clue.vector(...)
    return {type = "vector", value = {...}}
end
