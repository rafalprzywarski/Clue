clue = clue or {}
clue.namespaces = clue.namespaces or {}
clue.namespaces["lua"] = setmetatable({}, {__index = _G})

clue.nil_ = { type = "nil" }

function clue.symbol(ns, name)
    if name == nil then
        name = ns
        ns = nil
    end
    return {clue_type__ = "symbol", ns = ns, name = name}
end

function clue.type(s)
    local stype = type(s)
    if stype ~= "table" then
        return stype
    end
    return s.clue_type__ or stype
end

function clue.is_symbol(s)
    return clue.type(s) == "symbol"
end

function clue.list(...)
    local l = {clue_type__="list", mt={__index = {...}}, size=select("#", ...)}
    function l:unpack() return unpack(self.mt.__index) end
    function l:append(e) self.size = self.size + 1; self.mt.__index[self.size] = e; return self; end
    function l:map(f)
        local m = clue.list()
        for i=1,self.size do
            m:append(f(self[i]))
        end
        return m
    end
    function l:concat(delimiter)
        return table.concat(self.mt.__index, delimiter)
    end
    function l:first()
        return self.mt.__index[1]
    end
    function l:next()
        return self:sublist(2)
    end
    function l:rest()
        local n = self:next()
        if n == nil then
            return clue.cons()
        end
        return n
    end
    function l:sublist(index)
        if index > self.size then
            return nil
        end
        if index == self.size then
            return clue.cons(self.mt.__index[index])
        end
        return clue.cons(self.mt.__index[index], clue.lazy_seq(function() return self:sublist(index + 1) end))
    end
    return setmetatable(l, l.mt)
end

function clue.vector(...)
    local v = {clue_type__="vector", mt={__index = {...}}, size=select("#", ...)}
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
    function v:first()
        return self.mt.__index[1]
    end
    function v:next()
        return self:subvec(2)
    end
    function v:rest()
        local n = self:next()
        if n == nil then
            return clue.vector()
        end
        return n
    end
    function v:subvec(index)
        if index > self.size then
            return nil
        end
        if index == self.size then
            return clue.cons(self.mt.__index[index])
        end
        return clue.cons(self.mt.__index[index], clue.lazy_seq(function() return self:subvec(index + 1) end))
    end
    return setmetatable(v, v.mt)
end

function clue.cons(x, coll)
    local c = {clue_type__="cons"}
    function c:first()
        return x
    end
    function c:rest()
        return coll
    end
    function c:next()
        return clue.seq(coll)
    end
    return c
end

function clue.seq(coll)
    if coll and coll:first() then
        return coll
    end
    return nil
end

function clue.lazy_seq(f)
    local s = {clue_type__="lazy_seq"}
    function s:first()
        return (f() or clue.vector()):first()
    end
    function s:rest()
        return (f() or clue.vector()):rest()
    end
    function s:next()
        return (f() or clue.vector()):next()
    end
    return s
end

function clue.map(...)
    local values = {}
    for i=1,select("#", ...),2 do
        values[select(i, ...)] = select(i + 1, ...)
    end
    local m = {clue_type__="map", mt={__index = values}}
    function m.mt.__call(t, k)
        return t[k]
    end
    function m:each(f)
        for k,v in pairs(self.mt.__index) do
            f(k, v)
        end
    end
    function m:assoc(k,v)
        local n = clue.map()
        for k,v in pairs(self.mt.__index) do
            n[k] = v
        end
        n[k] = v
        return n
    end
    function m:equals(other)
        if type(other) ~= "table" or clue.type(other) ~= "map" then
            return false
        end
        for k,v in pairs(self.mt.__index) do
            if not clue.equals(other.mt.__index[k], v) then
                return false
            end
        end
        for k,v in pairs(other.mt.__index) do
            if not clue.equals(self.mt.__index[k], v) then
                return false
            end
        end
        return true
    end
    return setmetatable(m, m.mt)
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

function clue.pr_str(value)
    local vtype = type(value)
    if vtype == "string" then
        return "\"" .. value:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\t", "\\t") .. "\""
    end
    if vtype == "table" then
        local function pr_str_seq(op, s, cp)
            local t = {}
            while s do
                table.insert(t, clue.pr_str(s:first()))
                s = s:next()
            end
            return op .. table.concat(t, " ") .. cp
        end
        if clue.type(value) == "table" then
            local t = { "lua-table" }
            for k,v in pairs(value) do
                table.insert(t, clue.pr_str(k))
                table.insert(t, clue.pr_str(v))
            end
            return "(" .. table.concat(t, " ").. ")"
        end
        if clue.type(value) == "symbol" then
            if value.ns then
                return value.ns .. "/" .. value.name
            end
            return value.name
        end
        if clue.type(value) == "map" then
            local t = {}
            value:each(function(k,v) table.insert(t, clue.pr_str(k) .. " " .. clue.pr_str(v)) end)
            return "{" .. table.concat(t, ", ") .. "}"
        end
        if clue.type(value) == "vector" then
            return pr_str_seq("[", clue.seq(value), "]")
        end
        return pr_str_seq("(", clue.seq(value), ")")
    end
    return tostring(value)
end

function clue.equals(...)
    local function seq_equals(s1, s2)
        s1 = clue.seq(s1)
        s2 = clue.seq(s2)
        while s1 and s2 do
            if not clue.equals(s1:first(), s2:first()) then
                return false
            end
            s1 = s1:next()
            s2 = s2:next()
        end
        return s1 == s2
    end
    local function table_equals(t1, t2)
        for k,v in pairs(t1) do
            if not clue.equals(t2[k], v) then
                return false
            end
        end
        for k,v in pairs(t2) do
            if not clue.equals(t1[k], v) then
                return false
            end
        end
        return true
    end
    local x = select(1, ...)
    for i=2,select("#", ...) do
        local y = select(i, ...)
        if x ~= y then
            if type(x) ~= "table" or type(y) ~= "table" then
                return false
            end
            if clue.type(x) == "symbol" or clue.type(y) == "symbol" then
                if clue.type(x) ~= clue.type(y) then
                    return false
                end
                if x.name ~= y.name or x.ns ~= y.ns then
                    return false
                end
            elseif clue.type(x) == "table" or clue.type(y) == "table" then
                if clue.type(x) ~= clue.type(y) then
                    return false
                end
                if not table_equals(x, y) then
                    return false
                end
            elseif clue.type(x) ~= "map" then
                if clue.type(y) == "map" or not seq_equals(x, y) then
                    return false
                end
            else
                if not x:equals(y) then
                    return false
                end
            end
        end
    end
    return true
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

clue.namespaces["clue.core"]["="] = clue.equals

clue.namespaces["clue.core"]["not="] = function(...)
    return not clue.namespaces["clue.core"]["="](...)
end

clue.namespaces["clue.core"]["assoc"] = function(map, k, v)
    return map:assoc(k, v)
end

clue.namespaces["clue.core"]["cons"] = clue.cons
clue.namespaces["clue.core"]["seq"] = clue.seq
clue.namespaces["clue.core"]["first"] = function(seq) return seq:first() end
clue.namespaces["clue.core"]["rest"] = function(seq) return seq:rest() end
clue.namespaces["clue.core"]["next"] = function(seq) return seq:next() end
clue.namespaces["clue.core"]["pr-str"] = clue.pr_str
