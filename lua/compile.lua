require "compiler"

local function read_file(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

loadstring(clue.compiler.compile(nil, read_file("clue/core.clu")))()

print(clue.compiler.compile(nil, read_file(arg[1])))
