require 'clue.class'

clue.class("Set")

function clue.Set:init(...)
    local values = {}
    for i=1,select("#", ...) do
        values[select(i, ...)] = true
    end
    self.values = values
end

function clue.Set:__call(k)
    if self.values[k] then
        return k
    end
    return nil
end

function clue.Set:at(k)
    if self.values[k] then
        return k
    end
    return nil
end

function clue.Set:cons(k)
    local n = clue.set()
    for k,_ in pairs(self.values) do
        n.values[k] = true
    end
    n.values[k] = true
    return n
end

function clue.Set:union(other)
    local n = clue.set()
    for k,_ in pairs(self.values) do
        n.values[k] = true
    end
    if other then
        for k,_ in pairs(other.values) do
            n.values[k] = true
        end
    end
    return n
end

function clue.Set:equals(other)
    if clue.type(other) ~= clue.Set then
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

function clue.Set:with_meta(m)
    local wm = clue.Set.new()
    wm.values = self.values
    wm.meta = m
    return wm
end

clue.set = clue.Set.new
