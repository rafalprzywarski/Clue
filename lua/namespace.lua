clue.class('Namespace')

function clue.Namespace:init(name, aliases)
    self.name = name
    self.vars = clue.map()
    self.aliases = aliases or clue.map()
    self.used = clue.map()
end

function clue.Namespace:get(name)
    return self.vars:at(name)
end

function clue.Namespace:add(var)
    self.vars = self.vars:assoc(var.name, var)
end

function clue.Namespace:use(ns)
    self.used = self.used:assoc(ns.name, ns)
end
