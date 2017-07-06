require 'clue.class'

clue.class("Map")

function clue.Map:init(...)
    local values = {}
    local size = 0
    for i=1,select("#", ...),2 do
        values[tostring(select(i, ...))] = {key = select(i, ...), val = select(i + 1, ...)}
        size = size + 1
    end
    self.values = values
    self.size = size
end

function clue.Map:__call(k)
    local v = self.values[tostring(k)]
    return v and v.val
end

function clue.Map:at(k)
    local v = self.values[tostring(k)]
    return v and v.val
end

function clue.Map:contains(k)
    return self.values[tostring(k)] ~= nil
end

function clue.Map:each(f)
    for _,v in pairs(self.values) do
        f(v.key, v.val)
    end
end

function clue.Map:assoc(k,v)
    local n = clue.map()
    for k,v in pairs(self.values) do
        n.values[tostring(k)] = v
    end
    n.size = self.size
    if not n.values[tostring(k)] then
        n.size = n.size + 1
    end
    n.values[tostring(k)] = {key = k, val = v}
    return n
end

function clue.Map:merge(other)
    local n = clue.map()
    for k,v in pairs(self.values) do
        n.values[tostring(k)] = v
    end
    local size = self.size
    if other then
        for k,v in pairs(other.values) do
            if not n.values[tostring(k)] then
                size = size + 1
            end
            n.values[tostring(k)] = v
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
        if not clue.equals(other.values[tostring(k)], v) then
            return false
        end
    end
    for k,v in pairs(other.values) do
        if not clue.equals(self.values[tostring(k)], v) then
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
