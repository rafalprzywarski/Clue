require 'clue.class'

local M = clue.class("Var")

local MACRO = clue.keyword("macro")

function M:init(ns, name, root)
    self.ns = ns
    self.name = name
    self.root = root
end

function M:get()
    if M.frame then
        local sym = clue.symbol(self.ns, self.name)
        if M.frame.bindings:contains(sym) then
            return M.frame.bindings:at(sym)
        end
    end
    return self.root
end

function M.push_bindings(bindings)
    if M.frame then
        bindings = M.frame.bindings:merge(bindings)
    end
    M.frame = {bindings = bindings, prev = M.frame}
end

function M.pop_bindings()
    if not M.frame then
        error("trying to pop bindings when nothing was pushed")
    end
    M.frame = M.frame.prev
end

function M:reset(new_root)
    self.root = new_root
end

function M:with_meta(m)
    local wm = M.new(self.ns, self.name, self.root)
    wm.meta = m
    return wm
end

function M:is_macro()
    return self.meta and self.meta:at(MACRO)
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
        var = M.new(ns.name, name, value)
        var.meta = meta
        ns:add(var)
    end
    return var
end
