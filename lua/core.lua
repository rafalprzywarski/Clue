clue = clue or {}
clue.namespaces = clue.namespaces or {}
clue.namespaces["lua"] = setmetatable({}, {__index = _G})

clue.nil_ = { nil__ = true }

function clue.symbol(ns, name)
    if name == nil then
        name = ns
        ns = nil
    end
    return {type = "symbol", ns = ns, name = name}
end

function clue.list(...)
    local l = {type="list", mt={__index = {...}}, size=select("#", ...)}
    function l:unpack() return unpack(self.mt.__index) end
    function l:append(e) self.size = self.size + 1; self.mt.__index[self.size] = e; return self; end
    function l:map(f)
        local m = clue.list()
        for i=1,self.size do
            m:append(f(self[i]))
        end
        return m
    end
    return setmetatable(l, l.mt)
end

function clue.vector(...)
    local v = {type="vector", mt={__index = {...}}, size=select("#", ...)}
    function v:append(e) self.size = self.size + 1; self.mt.__index[self.size] = e; return self; end
    function v:map(f)
        local m = clue.vector()
        for i=1,self.size do
            m:append(f(self[i]))
        end
        return m
    end
    function v:concat(delimiter)
        return table.concat(self.mt.__index, delimiter) 
    end
    return setmetatable(v, v.mt)
end

function clue.to_set(a)
    local s = {}
    for i=1,a.size do
        s[a[i]] = true
    end
    return s
end

function clue.set_union(s1, s2)
    local s = {}
    for k, _ in pairs(s1) do s[k] = true end
    for k, _ in pairs(s2) do s[k] = true end
    return s
end

function clue.get_or_create_ns(name)
    n = clue.namespaces[name]
    if n then return n end
    n = {_name_ = name, _aliases_ = {}}
    clue.namespaces[name] = n
    return n
end

function clue.ns(name, aliases)
    clue._ns_ = clue.get_or_create_ns(name)
    for n, v in pairs(clue.namespaces["clue.core"]) do
        if n ~= "_name_" and n ~= "_aliases_" then
            clue._ns_[n] = v
        end
    end
    for _, ref_ns in pairs(aliases or {}) do
        if not clue.namespaces[ref_ns] then
            loadstring(clue.compiler.compile_file("../research/" .. ref_ns:gsub("[.]", "/") .. ".clu"))()
        end
    end
    clue._ns_._aliases_ = aliases
end

clue.ns("clue.core")

clue.namespaces["clue.core"]["+"] = function(...)
    local s = 0
    for i=1,select("#", ...) do
        s = s + select(i, ...)
    end
    return s
end

clue.namespaces["clue.core"]["-"] = function(...)
    if select("#", ...) == 1 then
        return -select(1, ...)
    end
    local s = select(1, ...)
    for i=2,select("#", ...) do
        s = s - select(i, ...)
    end
    return s
end

clue.namespaces["clue.core"]["*"] = function(...)
    local s = 1
    for i=1,select("#", ...) do
        s = s * select(i, ...)
    end
    return s
end

clue.namespaces["clue.core"]["/"] = function(...)
    local s = select(1, ...)
    for i=2,select("#", ...) do
        s = s / select(i, ...)
    end
    return s
end

clue.namespaces["clue.core"]["%"] = function(...)
    local s = select(1, ...)
    for i=2,select("#", ...) do
        s = s % select(i, ...)
    end
    return s
end

clue.namespaces["clue.core"]["="] = function(...)
    local x = select(1, ...)
    for i=2,select("#", ...) do
        if x ~= select(i, ...) then
            return false
        end
    end
    return true
end

clue.namespaces["clue.core"]["not="] = function(...)
    local x = select(1, ...)
    for i=2,select("#", ...) do
        if x ~= select(i, ...) then
            return true
        end
    end
    return false
end
