t={a=1}
function t:add(n)
	self.a = self.a + n
end
mt={}
setmetatable(t, mt)
mt.__index = function(t, k) return function() return "default " .. k end end
print(t)
print(t.help(2))
print(t.a)
t.add(t, 8)
print(t.a)
f = function() end
print(getmetatable(nil))
print("Sonia\ntest")
print(("%q"):format("Sonia\ntest"))
