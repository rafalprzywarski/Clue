require 'clue.class'

local M = clue.class("Symbol")

function M:init(ns, name)
    self.ns = ns
    self.name = name
end

function M:__eq(other)
    return self.ns == other.ns and self.name == other.name
end

function M:__tostring()
    local ns = self.ns
    if ns then
        return ns .. "/" .. self.name
    end
    return self.name
end

function M:with_meta(m)
    local wm = M.new(self.ns, self.name)
    wm.meta = m
    return wm
end

function clue.symbol(ns, name)
    if name == nil then
        name = ns
        ns = nil
    end
    return M.new(ns, name)
end

function clue.is_symbol(s)
    return clue.type(s) == M
end
