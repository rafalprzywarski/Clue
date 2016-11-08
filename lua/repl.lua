require "compiler"

local function read_file(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

loadstring(clue.compiler.compile(nil, read_file("clue/core.clu")))()
clue.ns("user")

local cmd
while true do
    io.write("> ")
    cmd = io.read()

    if cmd == "exit" then
        print("Good bye!")
        return
    end

    local compiled, result
    local ok, error = xpcall(
        function()
            compiled = "return " .. clue.compiler.compile(clue._ns_, cmd)
            result = loadstring(compiled, "repl")()
        end,
        function(error)
            return {error = error, traceback = debug.traceback()}
        end
    )

    if ok then
        print(clue.pr_str(result))
    else
        print(error.error)
        print(error.traceback)
        if compiled then
            print("compiled:")
            print(compiled)
        end
    end
end
