function clue.class(name)
    local mcls = {}
    function mcls:__tostring() return self.__clue_name__ end
    local cls = setmetatable({}, mcls)
    cls.__index = cls
    cls.__clue_name__ = name
    function cls.new(...)
        local instance = setmetatable({}, cls)
        if instance.init then
        	instance:init(...)
    	end
        return instance
    end
    clue[name] = cls
end
