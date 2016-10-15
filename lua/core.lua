clue = clue or {}

clue.nil_ = { nil__ = true }

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

function clue.map_array(f, a)
    local m = {}
    for _, v in ipairs(a) do
        table.insert(m, f(v))
    end
    return m
end
