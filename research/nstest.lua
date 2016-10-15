NS = {}
setmetatable(NS, { __index = _G})

local s = require("sample")

function NS.my_hello()
    s.hello()
    print("too")
end

return NS
