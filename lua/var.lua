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

function clue.var(ns, name)
    return clue.namespaces[ns][name]
end

function clue.def(ns, name, value)
    ns = clue.namespaces[ns]
    var = ns[name]
    if var then
        var.root = value
    else
        var = clue.Var.new(ns.name, name, value)
        ns[name] = var
    end
    return var
end
