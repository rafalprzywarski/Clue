require 'clue.class'

local M = clue.class("Protocol")

function M:init(name)
    self.name = name
    self.extended = clue.map()
end

function M:extend(type, methods)
    type = tostring(type)
    methods:each(function(name, f)
        local methods = (self.extended(name.name) or clue.map()):assoc(type, f)
        self.extended = self.extended:assoc(name.name, methods)
    end)
end
