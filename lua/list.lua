require 'class'

clue.class("List")

function clue.List:init(...)
    self:init_n(select("#", ...), ...)
end

function clue.List:init_n(n, first, ...)
    self.size = n
    if n == 0 then return end
    self.first_ = first
    if n == 1 then return end
    self.next_ = clue.List.new(...)
end

function clue.List:empty()
    return self.size == 0
end

function clue.List:first()
    return self.first_
end

function clue.List:next()
    return self.next_
end

function clue.List:cons(e)
    local l = clue.List.new()
    l.size = self.size + 1
    l.first_ = e
    l.next_ = self
    return l
end

clue.list = clue.List.new
