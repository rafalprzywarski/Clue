require 'class'

clue.class("Cons")

function clue.Cons:init(x, coll)
    self.first_ = x
    self.next_ = clue.seq(coll)
end

function clue.Cons:empty()
    return false
end

function clue.Cons:first()
    return self.first_
end

function clue.Cons:next()
    return self.next_
end

clue.cons = clue.Cons.new
