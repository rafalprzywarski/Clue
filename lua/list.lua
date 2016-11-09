require 'class'

clue.class("List")

function clue.List:init(...)
    self.size = 0
    for i=1,select("#", ...) do
        self:append(select(i, ...))
    end
end

function clue.List:append(e)
    self.size = self.size + 1
    self[self.size] = e
    return self
end

function clue.List:concat(delimiter)
    return table.concat(self, delimiter)
end

function clue.List:empty()
    return self.size == 0
end

function clue.List:first()
    return self[1]
end

function clue.List:next()
    return self:sublist(2)
end

function clue.List:sublist(index)
    if index > self.size then
        return nil
    end
    if index == self.size then
        return clue.cons(self[index])
    end
    return clue.cons(self[index], clue.lazy_seq(function() return self:sublist(index + 1) end))
end

clue.list = clue.List.new
