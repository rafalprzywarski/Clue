require 'class'

clue.class("Vector")

function clue.Vector:init(...)
    self.size = 0
    for i=1,select("#", ...) do
        self:append(select(i, ...))
    end
end

function clue.Vector:unpack()
    return unpack(self, 1, self.size)
end

function clue.Vector:append(e)
    self.size = self.size + 1
    self[self.size] = e
    return self
end

function clue.Vector:cons(e)
    local v = clue.Vector.new(self:unpack())
    v:append(e)
    return v
end

function clue.Vector:concat(delimiter)
    return table.concat(self, delimiter)
end

function clue.Vector:empty()
    return self.size == 0
end

function clue.Vector:first()
    return self[1]
end

function clue.Vector:next()
    return self:subvec(2)
end

function clue.Vector:subvec(index)
    if index > self.size then
        return nil
    end
    if index == self.size then
        return clue.cons(self[index])
    end
    return clue.cons(self[index], clue.lazy_seq(function() return self:subvec(index + 1) end))
end

function clue.Vector:with_meta(m)
    local wm = clue.Vector.new(self:unpack())
    wm.meta = m
    return wm
end

clue.vector = clue.Vector.new
