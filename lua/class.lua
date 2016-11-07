function clue.class(name)
    local cls = {}
    cls.__index = cls
    function cls.new(...)
        local instance = setmetatable({}, cls)
        if instance.init then
        	instance:init(...)
    	end
        return instance
    end
    clue[name] = cls
end
