require 'class'

clue.class("Var")

clue.Var.MACRO = clue.keyword("macro")

function clue.Var:init(ns, name, root)
    self.ns = ns
    self.name = name
    self.root = root
end

function clue.Var:get()
    return self.root
end

function clue.Var:reset(new_root)
    self.root = new_root
end

function clue.Var:with_meta(m)
    local wm = clue.Var.new(self.ns, self.name, self.root)
    wm.meta = m
    return wm
end

function clue.Var:is_macro()
    return self.meta and self.meta:at(clue.Var.MACRO)
end

function clue.var(ns, name)
    local n = clue.namespaces:at(ns)
    if not n or not n:get(name) then
        error("Var not found " .. ns .. "/" .. name)
    end
    return n:get(name)
end

function clue.def(ns, name, value, meta)
    ns = clue.namespaces:at(ns)
    var = ns:get(name)
    if var then
        var.root = value
    else
        var = clue.Var.new(ns.name, name, value)
        var.meta = meta
        ns:add(var)
    end
    return var
end
