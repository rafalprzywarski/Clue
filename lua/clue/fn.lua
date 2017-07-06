require 'clue.class'

local M = clue.class("Fn")

function M:init(fn)
    self.fn = fn
end

function M:__call(...)
    return self.fn(...)
end

function M:__tostring()
    return tostring(self.fn)
end

function M:__eq(other)
    return self.fn == other.fn
end

function M:with_meta(m)
    local wm = M.new(self.fn)
    wm.meta = m
    return wm
end

clue.fn = M.new

function clue.apply_to(f, args)
    local function unpack_seq(s)
        if not s then
            return
        end
        return s:first(), unpack_seq(s:next())
    end
    return f(unpack_seq(clue.seq(args)))
end
