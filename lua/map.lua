require 'class'

clue.class("Map")

function clue.Map:init(...)
    local values = {}
    local size = 0
    for i=1,select("#", ...),2 do
        values[select(i, ...)] = select(i + 1, ...)
        size = size + 1
    end
    self.values = values
    self.size = size
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
    n.size = self.size
    if not n.values[k] then
        n.size = n.size + 1
    end
    n.values[k] = v
    return n
end

function clue.Map:merge(other)
    local n = clue.map()
    for k,v in pairs(self.values) do
        n.values[k] = v
    end
    local size = self.size
    if other then
        for k,v in pairs(other.values) do
            if n.values[k] == nil then
                size = size + 1
            end
            n.values[k] = v
        end
    end
    n.size = size
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

function clue.Map:with_meta(m)
    local wm = clue.Map.new()
    wm.values = self.values
    wm.meta = m
    return wm
end

clue.map = clue.Map.new
