require 'class'

clue.class("Symbol")

function clue.Symbol:init(ns, name)
    self.ns = ns
    self.name = name
end

function clue.Symbol:equals(other)
    return clue.type(self) == clue.type(other) and self.ns == other.ns and self.name == other.name
end

function clue.Symbol:to_string()
    local ns = self.ns
    if ns then
        return ns .. "/" .. self.name
    end
    return self.name
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
