require 'clue.class'

local M = clue.class('Namespace')

function M:init(name, aliases)
    self.name = name
    self.vars = clue.hash_map()
    self.aliases = aliases or clue.hash_map()
end

function M:get(name)
    return self.vars:at(name)
end

function M:add(var)
    self.vars = self.vars:assoc(var.name, var)
end

function M:use(ns)
    self.vars = self.vars:merge(ns.vars)
end
