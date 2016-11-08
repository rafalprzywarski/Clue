clue = clue or {}
clue.namespaces = clue.namespaces or {}
clue.namespaces["lua"] = setmetatable({}, {__index = _G})

require 'keyword'
require 'symbol'
require 'vector'
require 'list'

function clue.type(s)
    local stype = type(s)
    if stype ~= "table" then
        return stype
    end
    return s.clue_type__ or getmetatable(s) or stype
end

function clue.cons(x, coll)
    local c = {clue_type__="cons"}
    function c:empty()
        return false
    end
    function c:first()
        return x
    end
    function c:next()
        return clue.seq(coll)
    end
    return c
end

function clue.seq(coll)
    if not coll or coll:empty() then
        return nil
    end
    return coll
end

function clue.vec(coll)
    local s = clue.seq(coll)
    local v = clue.vector()
    while s do
        v:append(s:first())
        s = s:next()
    end
    return v
end

function clue.lazy_seq(f)
    local s = {clue_type__="lazy_seq"}
    function s:eval()
        self.seq = f() or clue.list()
        self.eval = nil
        function self:first()
            return self.seq:first()
        end
        function self:next()
            return self.seq:next()
        end
        function self:empty()
            return self.seq:empty()
        end
    end
    function s:first()
        self:eval()
        return self.seq:first()
    end
    function s:next()
        self:eval()
        return self.seq:next()
    end
    function s:empty()
        self:eval()
        return self.seq:empty()
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
            n.mt.__index[k] = v
        end
        n.mt.__index[k] = v
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

function clue.has_tostring(value)
    local mt = getmetatable(value)
    return mt and mt.__tostring
end

function clue.pr_str(value)
    local vtype = type(value)
    if vtype == "string" then
        return "\"" .. value:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\t", "\\t") .. "\""
    end
    if vtype == "table" then
        if clue.has_tostring(value) then
            return tostring(value)
        end
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
        if clue.type(value) == "map" then
            local t = {}
            value:each(function(k,v) table.insert(t, clue.pr_str(k) .. " " .. clue.pr_str(v)) end)
            return "{" .. table.concat(t, ", ") .. "}"
        end
        if clue.type(value) == clue.Vector then
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
            if clue.type(x) == clue.Keyword or clue.type(y) == clue.Keyword then
                return false
            end
            if clue.type(x) == clue.Symbol or clue.type(y) == clue.Symbol then
                return false
            elseif clue.type(x) == clue.Keyword then
                return false
            elseif clue.type(y) == clue.Keyword then
                return false
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

function clue.rest(s)
    s = clue.seq(s)
    if s then
        local n = s:next()
        if n then
            return n
        end
    end
    return clue.list()
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
clue.namespaces["clue.core"]["vec"] = clue.vec
clue.namespaces["clue.core"]["first"] = function(seq) return seq:first() end
clue.namespaces["clue.core"]["rest"] = clue.rest
clue.namespaces["clue.core"]["next"] = function(seq) return seq:next() end
clue.namespaces["clue.core"]["pr-str"] = clue.pr_str
