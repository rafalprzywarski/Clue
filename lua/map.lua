require 'class'

clue.class("Map")

function clue.Map:init(...)
    local values = {}
    for i=1,select("#", ...),2 do
        values[select(i, ...)] = select(i + 1, ...)
    end
    self.values = values
end

function clue.Map:__call(k)
    return self.values[k]
end

function clue.Map:at(k)
    return self.values[k]
end

function clue.Map:each(f)
    for k,v in pairs(self.values) do
        f(k, v)
    end
end

function clue.Map:assoc(k,v)
    local n = clue.map()
    for k,v in pairs(self.values) do
        n.values[k] = v
    end
    n.values[k] = v
    return n
end

function clue.Map:equals(other)
    if clue.type(other) ~= clue.Map then
        return false
    end
    for k,v in pairs(self.values) do
        if not clue.equals(other.values[k], v) then
            return false
        end
    end
    for k,v in pairs(other.values) do
        if not clue.equals(self.values[k], v) then
            return false
        end
    end
    return true
end

clue.map = clue.Map.new
