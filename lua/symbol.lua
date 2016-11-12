require 'class'

clue.class("Symbol")

function clue.Symbol:init(ns, name)
    self.ns = ns
    self.name = name
end

function clue.Symbol:__eq(other)
    return self.ns == other.ns and self.name == other.name
end

function clue.Symbol:__tostring()
    local ns = self.ns
    if ns then
        return ns .. "/" .. self.name
    end
    return self.name
end

function clue.Symbol:with_meta(m)
    local wm = clue.Symbol.new(self.ns, self.name)
    wm.meta = m
    return wm
end

function clue.symbol(ns, name)
    if name == nil then
        name = ns
        ns = nil
    end
    return clue.Symbol.new(ns, name)
end

function clue.is_symbol(s)
    return clue.type(s) == clue.Symbol
end
