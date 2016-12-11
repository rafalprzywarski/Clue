require "compiler"

loadstring(clue.compiler.compile_file("clue/core.clu"))()
loadstring(clue.compiler.compile_file(arg[1]))()
