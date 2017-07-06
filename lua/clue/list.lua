require 'clue.class'

local M = clue.class("List")

function M:init(...)
    self:init_n(select("#", ...), ...)
end

function M:init_n(n, first, ...)
    self.size = n
    if n == 0 then return end
    self.first_ = first
    if n == 1 then return end
    self.next_ = M.new(...)
end

function M:empty()
    return self.size == 0
end

function M:first()
    return self.first_
end

function M:next()
    return self.next_
end

function M:cons(e)
    local l = M.new()
    l.size = self.size + 1
    l.first_ = e
    l.next_ = self
    return l
end

function M:with_meta(m)
    local wm = M.new()
    wm.size = n
    wm.first_ = self.first_
    wm.next_ = self.next_
    wm.meta = m
    return wm
end

clue.list = M.new
