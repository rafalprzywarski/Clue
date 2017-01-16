require 'class'

clue.class("Protocol")

function clue.Protocol:init(name)
    self.name = name
    self.extended = clue.map()
end

function clue.Protocol:extend(type, methods)
    type = tostring(type)
    methods:each(function(name, f)
        local methods = (self.extended(name.name) or clue.map()):assoc(type, f)
        self.extended = self.extended:assoc(name.name, methods)
    end)
end
