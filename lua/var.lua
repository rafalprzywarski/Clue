require 'class'

clue.class("Var")

clue.Var.MACRO = clue.keyword("macro")

function clue.Var:init(ns, name, root)
    self.ns = ns
    self.name = name
    self.root = root
end

function clue.Var:get()
    if clue.Var.frame then
        local sym = clue.symbol(self.ns, self.name)
        if clue.Var.frame.bindings:contains(sym) then
            return clue.Var.frame.bindings:at(sym)
        end
    end
    return self.root
end

function clue.Var.push_bindings(bindings)
    if clue.Var.frame then
        bindings = clue.Var.frame.bindings:merge(bindings)
    end
    clue.Var.frame = {bindings = bindings, prev = clue.Var.frame}
end

function clue.Var.pop_bindings()
    if not clue.Var.frame then
        error("trying to pop bindings when nothing was pushed")
    end
    clue.Var.frame = clue.Var.frame.prev
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
