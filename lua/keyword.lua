require 'class'

local M = clue.class("Keyword")

function M:init(ns, name)
    self.ns = ns
    self.name = name
end

function M:__eq(other)
    return self.ns == other.ns and self.name == other.name
end

function M:__tostring()
    return M.normalize(self.ns, self.name)
end

function M.normalize(ns, name)
    if ns then
        return ":" .. ns .. "/" .. name
    end
    return ":" .. name
end

function M:__call(map)
    return map:at(self)
end

function M.intern(ns, name)
    local norm = M.normalize(ns, name)
    local interned = M.keywords[norm]
    if interned then
        return interned
    end
    local kw = M.new(ns, name)
    M.keywords[norm] = kw
    return kw
end

M.keywords = {}

function clue.keyword(ns, name)
    if name == nil then
        name = ns
        ns = nil
    end
    return M.intern(ns, name)
end
