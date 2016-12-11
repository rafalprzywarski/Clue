require "compiler"

loadstring(clue.compiler.compile_file("clue/core.clu"))()
print(clue.compiler.compile_file(arg[1]))
