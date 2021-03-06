require "clue.compiler"

clue.load_ns("clue.core")
clue.load_ns("clue.repl")
clue.ns("user")
clue.namespaces:at("user"):use(clue.namespaces:at("clue.repl"))

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
            compiled = "return " .. clue.compiler.compile(cmd)
            result = loadstring(compiled, "repl")()
        end,
        function(error)
            return {error = error, traceback = debug.traceback()}
        end
    )

    if ok then
        print(clue.pr_str(result))
    else
        print("error: " .. tostring(error.error))
        print(error.traceback)
        if compiled then
            print("compiled:")
            print(compiled)
        end
    end
end
