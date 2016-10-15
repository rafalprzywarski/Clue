require "compiler"
clue = clue or {}
clue.namespace = {}
clue.namespaces = {}
clue.namespaces["clue.core"] = {}
clue._ns_ = nil

local function read_file(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

function clue.load_namespace(ns)
    clue.compiler.compile(read_file(ns .. ".clu"))
end

function clue.require(ns, alias, into)
    clue.load_namespace(ns)
    into.aliases[alias] = clue.namespaces[ns]
end

function clue.ns(name, required)
    n = setmetatable({name = name, aliases = {}}, clue.namespace)
    for ns, a in pairs(required or {}) do
        clue.require(ns, a, n)
    end
    clue._ns_ = n
end

function clue.def(name, value)
    clue._ns_[name] = value
end

function clue.var(ns, name)
    return (clue._ns_.aliases[ns] or clue.namespaces[ns])[name]
end

clue.ns("user", {test = "test"})

-- (+ 8 (* 3 4))
-- clue._ns_["+"](8, clue._ns_["+"](3, 4))
-- (s/print "hello")
-- clue.var("s", "print")
