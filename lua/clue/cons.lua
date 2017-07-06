require 'clue.class'

local M = clue.class("Cons")

function M:init(x, coll)
    self.first_ = x
    self.next_ = clue.seq(coll)
end

function M:empty()
    return false
end

function M:first()
    return self.first_
end

function M:next()
    return self.next_
end

function M:with_meta(m)
    local wm = M.new(self.first_, self.next_)
    wm.meta = m
    return wm
end

clue.cons = M.new
