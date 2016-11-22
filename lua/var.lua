require 'class'

clue.class("Var")

function clue.Var:init(ns, name, root)
    self.ns = ns
    self.name = name
    self.root = root
end

function clue.Var:get()
    return self.root
end

function clue.Var:with_meta(m)
    local wm = clue.Var.new(ns, name, root)
    wm.meta = m
    return wm
end

function clue.var(ns, name)
    if not clue.namespaces[ns][name] then
        error("Var not found " .. ns .. "/" .. name)
    end
    return clue.namespaces[ns][name]
end

function clue.def(ns, name, value, meta)
    ns = clue.namespaces[ns]
    var = ns[name]
    if var then
        var.root = value
    else
        var = clue.Var.new(ns.name, name, value)
        var.meta = meta
        ns[name] = var
    end
    return var
end
