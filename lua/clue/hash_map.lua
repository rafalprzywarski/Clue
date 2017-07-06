require 'clue.class'

local M = clue.class("HashMap")

function M:init(...)
    local values = {}
    local size = 0
    for i=1,select("#", ...),2 do
        values[tostring(select(i, ...))] = {key = select(i, ...), val = select(i + 1, ...)}
        size = size + 1
    end
    self.values = values
    self.size = size
end

function M:__call(k)
    local v = self.values[tostring(k)]
    return v and v.val
end

function M:at(k)
    local v = self.values[tostring(k)]
    return v and v.val
end

function M:contains(k)
    return self.values[tostring(k)] ~= nil
end

function M:each(f)
    for _,v in pairs(self.values) do
        f(v.key, v.val)
    end
end

function M:assoc(k,v)
    local n = M.new()
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

function M:merge(other)
    local n = M.new()
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

function M:equals(other)
    if clue.type(other) ~= M then
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

function M:with_meta(m)
    local wm = M.new()
    wm.values = self.values
    wm.meta = m
    return wm
end

clue.hash_map = M.new
