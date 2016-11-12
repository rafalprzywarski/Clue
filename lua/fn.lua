require 'class'

clue.class("Fn")

function clue.Fn:init(fn)
    self.fn = fn
end

function clue.Fn:__call(...)
    return self.fn(...)
end

function clue.Fn:__tostring()
    return tostring(self.fn)
end

function clue.Fn:__eq(other)
    return self.fn == other.fn
end

function clue.Fn:with_meta(m)
    local wm = clue.Fn.new(self.fn)
    wm.meta = m
    return wm
end

clue.fn = clue.Fn.new
