require 'class'

clue.class("Keyword")

function clue.Keyword:init(ns, name)
    self.ns = ns
    self.name = name
end

function clue.Keyword:__eq(other)
    return self.ns == other.ns and self.name == other.name
end

function clue.Keyword:__tostring()
    return clue.Keyword.normalize(self.ns, self.name)
end

function clue.Keyword.normalize(ns, name)
    if ns then
        return ":" .. ns .. "/" .. name
    end
    return ":" .. name
end

function clue.Keyword:__call(map)
    return map:at(self)
end

function clue.Keyword.intern(ns, name)
    local norm = clue.Keyword.normalize(ns, name)
    local interned = clue.Keyword.keywords[norm]
    if interned then
        return interned
    end
    local kw = clue.Keyword.new(ns, name)
    clue.Keyword.keywords[norm] = kw
    return kw
end

clue.Keyword.keywords = {}

function clue.keyword(ns, name)
    if name == nil then
        name = ns
        ns = nil
    end
    return clue.Keyword.intern(ns, name)
end
