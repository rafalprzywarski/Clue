clue = clue or {}

require 'keyword'
require 'symbol'
require 'vector'
require 'list'
require 'cons'
require 'lazy_seq'
require 'map'
require 'set'
require 'fn'
require 'var'
require 'namespace'

clue.namespaces = clue.namespaces or clue.map("lua", {})

function clue.arg_count_error(n)
    error("Wrong number of args (" .. n .. ")")
end

function clue.type(s)
    local stype = type(s)
    if stype ~= "table" then
        return stype
    end
    return getmetatable(s) or stype
end

function clue.seq(coll)
    if not coll or coll:empty() then
        return nil
    end
    if clue.type(coll) == clue.Vector then
        return coll:subvec(1)
    end
    return coll
end

function clue.is_seq(coll)
    local t = clue.type(coll)
    return t == clue.List or t == clue.Cons or t == clue.UnrealizedLazySeq or t == clue.RealizedLazySeq
end

function clue.first(s)
    s = clue.seq(s)
    if not s then
        return nil
    end
    return s:first()
end

function clue.next(s)
    s = clue.seq(s)
    if not s then
        return nil
    end
    return s:next()
end

function clue.nnext(s)
    return clue.next(clue.next(s))
end

function clue.second(s)
    return clue.first(clue.next(s))
end

function clue.nth(coll, index, not_found)
    if not coll or coll:empty() or index < 0 then
        return not_found
    end
    if clue.type(coll) == clue.Vector then
        if coll.size <= index then
            return not_found
        end
        return coll:at(index)
    end
    local s = clue.seq(coll)
    while index > 0 and s do
        index = index - 1
        s = s:next()
    end
    if not s then
        return not_found
    end
    return s:first()
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

function clue.to_self_map(a)
    local s = clue.map()
    for i=1,a.size do
        s = s:assoc(a[i], a[i])
    end
    return s
end

function clue.get_or_create_ns(name)
    n = clue.namespaces:at(name)
    if n then return n end
    n = clue.Namespace.new(name)
    clue.namespaces = clue.namespaces:assoc(name, n)
    return n
end

function clue.in_ns(name)
    clue._ns_ = clue.get_or_create_ns(name)
end

function clue.locate_file(localpath)
    local function dir(path)
        return path:match(".*/") or ""
    end
    local projpath = dir(clue._file_ or "") .. localpath
    local file = io.open(projpath, "rb")
    if file then
        file.close()
        return projpath
    end
    for path in package.path:gmatch("([^;]+)") do
        if path:match("%?%.lua") then
            local filename = string.gsub(path, "%?%.lua", localpath)
            local file = io.open(filename, "rb")
            if file then
                file.close()
                return filename
            end
        end
    end
    error("Cannot find " .. localpath)
end

function clue.compile(path)
    return clue.compiler.compile_file(clue.locate_file(path))
end

function clue.compile_ns(ns_name)
    return clue.compile(ns_name:gsub("%.", "/") .. ".clu")
end

function clue.load(path)
    loadstring(clue.compile(path))()
end

function clue.load_ns(ns_name)
    loadstring(clue.compile_ns(ns_name))()
end

function clue.ns(name, aliases)
    local ns = clue.get_or_create_ns(name)
    if name ~= "clue.core" then
        ns:use(clue.namespaces:at("clue.core"))
    end
    aliases = aliases or clue.map()
    aliases:each(function(_, ref_ns)
        if not clue.namespaces:at(ref_ns) then
            clue.load_ns(ref_ns)
            clue.in_ns(name)
        end
    end)
    ns.aliases = aliases
    clue.in_ns(name)
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
        if clue.type(value) == clue.Var then
            return "#'" .. value.ns .. "/" .. value.name
        end
        local function pr_str_seq(op, s, cp)
            local t = {}
            while s do
                table.insert(t, clue.pr_str(s:first()))
                s = s:next()
            end
            return op .. table.concat(t, " ") .. cp
        end
        if clue.type(value) == clue.Map then
            local t = {}
            value:each(function(k,v) table.insert(t, clue.pr_str(k) .. " " .. clue.pr_str(v)) end)
            return "{" .. table.concat(t, ", ") .. "}"
        end
        if clue.type(value) == clue.Vector then
            return pr_str_seq("[", clue.seq(value), "]")
        end
        if clue.is_seq(value) then
            return pr_str_seq("(", clue.seq(value), ")")
        end
        local t = { "lua-table" }
        for k,v in pairs(value) do
            table.insert(t, clue.pr_str(k))
            table.insert(t, clue.pr_str(v))
        end
        local tag = ""
        if clue.type(value) ~= "table" then
            tag = "^" .. tostring(clue.type(value)) .. " "
        end
        return "(" .. tag .. table.concat(t, " ").. ")"
    end
    return tostring(value)
end

function clue.str(...)
    local s = ""
    for i=1,select("#", ...) do
        local e = select(i, ...)
        if clue.type(e) ~= "string" then
            e = clue.pr_str(e)
        end
        s = s .. e
    end
    return s
end

function clue.identical(l, r)
    return l == r
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
            if clue.type(x) == clue.Fn or clue.type(y) == clue.Fn then
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
            elseif clue.type(x) ~= clue.Map then
                if clue.type(y) == clue.Map or not seq_equals(x, y) then
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

function clue.conj(coll, x)
    if coll and coll.cons then
        return coll:cons(x)
    end
    return clue.cons(x, coll)
end

function clue.op_add(...)
    local s = 0
    for i=1,select("#", ...) do
        s = s + select(i, ...)
    end
    return s
end

function clue.op_sub(...)
    if select("#", ...) == 1 then
        return -select(1, ...)
    end
    local s = select(1, ...)
    for i=2,select("#", ...) do
        s = s - select(i, ...)
    end
    return s
end

function clue.op_mul(...)
    local s = 1
    for i=1,select("#", ...) do
        s = s * select(i, ...)
    end
    return s
end

function clue.op_div(...)
    local s = select(1, ...)
    for i=2,select("#", ...) do
        s = s / select(i, ...)
    end
    return s
end

function clue.op_mod(...)
    local s = select(1, ...)
    for i=2,select("#", ...) do
        s = s % select(i, ...)
    end
    return s
end

function clue.new(type, ...)
    return type.new(...)
end

function clue.def_type(name, init, ...)
    local cls = clue.new_class(name)
    cls.init = init
    for i=1,select("#", ...),2 do
        cls[select(i, ...)] = select(i + 1, ...)
    end
    clue._ns_:add(clue.Var.new(clue._ns_.name, name, cls))
end
