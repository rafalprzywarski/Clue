require "clue.compiler"

clue.load_ns("clue.core")
loadstring(clue.compiler.read_file(arg[1]))()
