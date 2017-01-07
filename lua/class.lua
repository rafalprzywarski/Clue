function clue.new_class(name)
    local mcls = {}
    function mcls:__tostring() return self.__clue_name__ end
    local cls = setmetatable({}, mcls)
    cls.__index = cls
    cls.__clue_name__ = "clue." .. name
    function cls.new(...)
        local instance = setmetatable({}, cls)
        if instance.init then
        	instance:init(...)
    	end
        return instance
    end
    return cls
end

function clue.class(name)
    clue[name] = clue.new_class(name)
end
