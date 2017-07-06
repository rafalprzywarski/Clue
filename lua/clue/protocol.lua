require 'clue.class'

local M = clue.class("Protocol")

function M:init(name)
    self.name = name
    self.extended = clue.hash_map()
end

function M:extend(type, methods)
    type = tostring(type)
    methods:each(function(name, f)
        local methods = (self.extended(name.name) or clue.hash_map()):assoc(type, f)
        self.extended = self.extended:assoc(name.name, methods)
    end)
end
