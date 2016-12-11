local t = require("ut")
local ct = require("clue_ut")
require("compiler")

local compile = clue.compiler.compile
local read = function(e) return clue.reader.read(e):at(0) end

loadstring(clue.compiler.compile_file("clue/core.clu"))()
t.describe("clue.compiler", {
    ["before each"] = function()
        t.save_global("clue.namespaces")
        clue.ns("user.ns")
    end,
    [".compile"] = {
        ["should translate"] = {
            ["lists into function calls"] = function()
                compile("(def hi nil) (def x nil) (ns my.ns) (def ff nil) (ns s) (def y nil) (in-ns user.ns)")
                t.assert_equals(compile("(hi)"), "clue.var(\"user.ns\", \"hi\"):get()()")
                t.assert_equals(compile("(hi 1 2 3)"), "clue.var(\"user.ns\", \"hi\"):get()(1, 2, 3)")
                t.assert_equals(compile("(my.ns/ff)"), "clue.var(\"my.ns\", \"ff\"):get()()")
                t.assert_equals(compile("(my.ns/ff 1 2 3)"), "clue.var(\"my.ns\", \"ff\"):get()(1, 2, 3)")
                t.assert_equals(compile("(my.ns/ff x s/y)"), "clue.var(\"my.ns\", \"ff\"):get()(clue.var(\"user.ns\", \"x\"):get(), clue.var(\"s\", \"y\"):get())")
                t.assert_equals(compile("((fn [] 10))"), compile("(fn [] 10)") .. "()")
            end,
            ["nested list into nested function calls"] = function()
                compile("(def hi nil) (def there nil)")
                t.assert_equals(compile("(hi (there))"), "clue.var(\"user.ns\", \"hi\"):get()(clue.var(\"user.ns\", \"there\"):get()())")
            end,
            ["strings"] = function()
                t.assert_equals(compile("\"Sonia\""), "\"Sonia\"")
            end,
            ["symbols into vars"] = function()
                compile("(def an-example nil) (ns my.ns.example) (def an-example nil) (in-ns user.ns)")
                t.assert_equals(compile("an-example"), "clue.var(\"user.ns\", \"an-example\"):get()")
                t.assert_equals(compile("my.ns.example/an-example"), "clue.var(\"my.ns.example\", \"an-example\"):get()")
            end,
            ["keywords"] = function()
                t.assert_equals(compile(":an-example"), "clue.keyword(\"an-example\")")
                t.assert_equals(compile(":ns/example"), "clue.keyword(\"ns\", \"example\")")
            end,
            ["vectors into clue.vector calls"] = function()
                compile("(def hello nil) (def x nil)")
                t.assert_equals(compile("[]"), "clue.vector()")
                t.assert_equals(compile("[1 2 3 4]"), "clue.vector(1, 2, 3, 4)")
                t.assert_equals(compile("[(hello) user.ns/x]"), "clue.vector(clue.var(\"user.ns\", \"hello\"):get()(), clue.var(\"user.ns\", \"x\"):get())")
            end,
            ["maps into clue.map calls"] = function()
                t.assert_equals(compile("{}"), "clue.map()")
                t.assert_equals_any(compile("{3 4 1 2}"), "clue.map(1, 2, 3, 4)", "clue.map(3, 4, 1, 2)")
            end,
            ["function definitions"] = {
                ["with no parameters"] = function()
                    compile("(def f nil) (def g nil) (def h nil)")
                    t.assert_equals(compile("(fn [] (f 1 2))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 0 then return clue.var(\"user.ns\", \"f\"):get()(1, 2) end; clue.arg_count_error(arg_count_); end)")
                    t.assert_equals(compile("(fn [] (f 1) (g 2) (h 3))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 0 then clue.var(\"user.ns\", \"f\"):get()(1); clue.var(\"user.ns\", \"g\"):get()(2); return clue.var(\"user.ns\", \"h\"):get()(3) end; clue.arg_count_error(arg_count_); end)")
                end,
                ["with declared parameters"] = function()
                    compile("(def f nil) (def g nil) (def h nil)")
                    t.assert_equals(compile("(fn [a] (f 1 2))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 1 then return (function(a) return clue.var(\"user.ns\", \"f\"):get()(1, 2) end)(...) end; clue.arg_count_error(arg_count_); end)")
                    t.assert_equals(compile("(fn [b c d] (f 1 2) (g 2) (h 3))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 3 then return (function(b, c, d) clue.var(\"user.ns\", \"f\"):get()(1, 2); clue.var(\"user.ns\", \"g\"):get()(2); return clue.var(\"user.ns\", \"h\"):get()(3) end)(...) end; clue.arg_count_error(arg_count_); end)")
                end,
                ["with variable number of parameters"] = function()
                    t.assert_equals(compile("(fn [& args] args)"), "clue.fn(function(...) local args = clue.list(...); return args end)")
                    t.assert_equals(compile("(fn [a b & args] (a b args) (b a))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ >= 2 then return (function(a, b, ...) local args = clue.list(...); a(b, args); return b(a) end)(...) end; clue.arg_count_error(arg_count_); end)")
                end,
                ["with parameters used in the body"] = function()
                    t.assert_equals(compile("(fn [a] (a 1 2))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 1 then return (function(a) return a(1, 2) end)(...) end; clue.arg_count_error(arg_count_); end)")
                    compile("(def y nil)")
                    t.assert_equals(compile("(fn [f x] (f x y))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 2 then return (function(f, x) return f(x, clue.var(\"user.ns\", \"y\"):get()) end)(...) end; clue.arg_count_error(arg_count_); end)")
                    t.assert_equals(compile("(fn [a b c] (a b) [a b c])"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 3 then return (function(a, b, c) a(b); return clue.vector(a, b, c) end)(...) end; clue.arg_count_error(arg_count_); end)")
                end,
                ["with parameters used in the body of a nested function"] = function()
                    t.assert_equals(compile("(fn [a b] (fn [c d] (a b c d)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 2 then return (function(a, b) return clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 2 then return (function(c, d) return a(b, c, d) end)(...) end; clue.arg_count_error(arg_count_); end) end)(...) end; clue.arg_count_error(arg_count_); end)")
                end,
                ["overloaded by the number of parameters"] = {
                    ["- no signatures"] = function()
                        t.assert_equals(compile("(fn)"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); clue.arg_count_error(arg_count_); end)")
                    end,
                    ["- one signature"] = function()
                        t.assert_equals(compile("(fn ([a b & args] (a b args) (b a)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ >= 2 then return (function(a, b, ...) local args = clue.list(...); a(b, args); return b(a) end)(...) end; clue.arg_count_error(arg_count_); end)")
                    end,
                    ["- many signatures"] = function()
                        t.assert_equals(compile("(fn ([] 10) ([x] x) ([y z] (y z)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 0 then return 10 end; if arg_count_ == 1 then return (function(x) return x end)(...) end; if arg_count_ == 2 then return (function(y, z) return y(z) end)(...) end; clue.arg_count_error(arg_count_); end)")
                    end,
                    ["- many signatures with variable number of parameters"] = function()
                        t.assert_equals(compile("(fn ([a b & xs] xs) ([x] x) ([y z] (y z)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 1 then return (function(x) return x end)(...) end; if arg_count_ == 2 then return (function(y, z) return y(z) end)(...) end; if arg_count_ >= 2 then return (function(a, b, ...) local xs = clue.list(...); return xs end)(...) end; clue.arg_count_error(arg_count_); end)")
                        t.assert_equals(compile("(fn ([x y z & xs] xs) ([x] x) ([y z] (y z)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 1 then return (function(x) return x end)(...) end; if arg_count_ == 2 then return (function(y, z) return y(z) end)(...) end; if arg_count_ >= 3 then return (function(x, y, z, ...) local xs = clue.list(...); return xs end)(...) end; clue.arg_count_error(arg_count_); end)")
                    end
                }
            },
            ["metadata"] = {
                ["in vectors"] = function()
                    t.assert_equals(compile("^:yes [1 2 3]"), "clue.vector(1, 2, 3):with_meta(clue.map(clue.keyword(\"yes\"), true))")
                end,
                ["in keywords"] = function()
                    t.assert_equals(compile("^:yes :ok"), "clue.keyword(\"ok\"):with_meta(clue.map(clue.keyword(\"yes\"), true))")
                    t.assert_equals(compile("^:yes :ss/ok"), "clue.keyword(\"ss\", \"ok\"):with_meta(clue.map(clue.keyword(\"yes\"), true))")
                end,
                ["in maps"] = function()
                    t.assert_equals(compile("^:yes {1 2}"), "clue.map(1, 2):with_meta(clue.map(clue.keyword(\"yes\"), true))")
                end,
                ["in fn"] = function()
                    t.assert_equals(compile("^:yes (fn [& xs] nil)"), compile("(fn [& xs] nil)") .. ":with_meta(clue.map(clue.keyword(\"yes\"), true))")
                end,
                ["but not function calls"] = function()
                    compile("(def print nil)")
                    t.assert_equals(compile("^:no (print 1 2)"), compile("(print 1 2)"))
                end
            },
            ["variable definitions"] = function()
                t.assert_equals(compile("(def a 10)"), "clue.def(\"user.ns\", \"a\", 10, nil)")
                t.assert_equals(compile("(def ready? (fn [& args] nil))"), "clue.def(\"user.ns\", \"ready?\", clue.fn(function(...) local args = clue.list(...); return nil end), nil)")
                t.assert_equals(compile("(def ^:dynamic a 10)"), "clue.def(\"user.ns\", \"a\", 10, clue.map(clue.keyword(\"dynamic\"), true))")
            end,
            ["variable access"] = function()
                compile("(def some nil) (ns other) (def some nil) (in-ns user.ns)")
                t.assert_equals(compile("(var some)"), "clue.var(\"user.ns\", \"some\")")
                t.assert_equals(compile("(var other/some)"), "clue.var(\"other\", \"some\")")
            end,
            ["let definitions"] = {
                ["without constants"] = function()
                    compile("(def f nil)")
                    t.assert_equals(compile("(let [])"), "nil")
                    t.assert_equals(compile("(let [] (f 1 2))"), "(function() return clue.var(\"user.ns\", \"f\"):get()(1, 2) end)()")
                    t.assert_equals(compile("(let [] (f) (f 1 2))"), "(function() clue.var(\"user.ns\", \"f\"):get()(); return clue.var(\"user.ns\", \"f\"):get()(1, 2) end)()")
                end,
                ["with constants"] = function()
                    compile("(def f nil) (def a nil) (def b nil)")
                    t.assert_equals(compile("(let [a (f)])"), "(function() local a = clue.var(\"user.ns\", \"f\"):get()(); return nil end)()")
                    t.assert_equals(compile("(let [a f b 2] (a b))"), "(function() local a = clue.var(\"user.ns\", \"f\"):get(); local b = 2; return a(b) end)()")
                    t.assert_equals(compile("(let [a 1 b 2] (a) (b))"), "(function() local a = 1; local b = 2; a(); return b() end)()")
                    t.assert_equals(compile("(fn [a] (let [b a] (b a)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 1 then return (function(a) return (function() local b = a; return b(a) end)() end)(...) end; clue.arg_count_error(arg_count_); end)")
                    t.assert_equals(compile("(let [a a a a a b b a] (b a)"), "(function() local a = clue.var(\"user.ns\", \"a\"):get(); local a = a; local a = clue.var(\"user.ns\", \"b\"):get(); local b = a; return b(a) end)()")
                end
            },
            ["multiple expressions into multiple statements"] = function()
                compile("(def f1 nil) (def f2 nil)")
                t.assert_equals(compile("(def x 9)(f1)"), "clue.def(\"user.ns\", \"x\", 9, nil);\nclue.var(\"user.ns\", \"f1\"):get()()")
                t.assert_equals(compile("(def x 9)(f1)(f2)"), "clue.def(\"user.ns\", \"x\", 9, nil);\nclue.var(\"user.ns\", \"f1\"):get()();\nclue.var(\"user.ns\", \"f2\"):get()()")
            end,
            ["namespace definitions"] = {
                ["without attributes"] = function()
                    t.assert_equals(compile("(ns user.core)"), "clue.ns(\"user.core\")")
                    t.assert_equals(compile(
                        "(ns user.core)(def f1 nil)(def f2 nil)(f1)(f2)"),
                        "clue.ns(\"user.core\");\nclue.def(\"user.core\", \"f1\", nil, nil);\nclue.def(\"user.core\", \"f2\", nil, nil);\nclue.var(\"user.core\", \"f1\"):get()();\nclue.var(\"user.core\", \"f2\"):get()()")
                end,
                ["with require"] = function()
                    t.save_global("clue.compiler.compile_file")
                    clue.compiler.compile_file = function() return "" end
                    t.assert_equals(compile("(ns user.core (:require org.some.xyz))"), "clue.ns(\"user.core\", clue.map(\"org.some.xyz\", \"org.some.xyz\"))")
                    t.assert_equals(compile("(ns user.core (:require [org.some.xyz :as some]))"), "clue.ns(\"user.core\", clue.map(\"some\", \"org.some.xyz\"))")
                    t.assert_equals(compile("(ns user.core (:require [org.some.xyz :as xyz] [org.some.abc :as other]))"), "clue.ns(\"user.core\", clue.map(\"xyz\", \"org.some.xyz\", \"other\", \"org.some.abc\"))")
                    compile("(ns org.some.xyz) (def f1 nil)")
                    t.assert_equals(compile(
                        "(ns user.core (:require [org.some.xyz :as some])) (some/f1)"),
                        "clue.ns(\"user.core\", clue.map(\"some\", \"org.some.xyz\"));\n" ..
                        "clue.var(\"org.some.xyz\", \"f1\"):get()()")
                end
            },
            ["operator"] = {
                ["+"] = function()
                    t.assert_equals(compile("(+ 1)"), "(1)")
                    t.assert_equals(compile("(+ 1 2)"), "(1 + 2)")
                    t.assert_equals(compile("(+ 1 2 3)"), "(1 + 2 + 3)")
                    t.assert_equals(compile("(apply + 1 2 3)"), compile("(clue.core/apply clue.core/+ 1 2 3)"))
                end,
                ["-"] = function()
                    t.assert_equals(compile("(- 1)"), "(-1)")
                    t.assert_equals(compile("(- 1 2)"), "(1 - 2)")
                    t.assert_equals(compile("(- 1 2 3)"), "(1 - 2 - 3)")
                end,
                ["*"] = function()
                    t.assert_equals(compile("(* 1)"), "(1)")
                    t.assert_equals(compile("(* 1 2)"), "(1 * 2)")
                    t.assert_equals(compile("(* 1 2 3)"), "(1 * 2 * 3)")
                end,
                ["/"] = function()
                    t.assert_equals(compile("(/ 1)"), "(1)")
                    t.assert_equals(compile("(/ 1 2)"), "(1 / 2)")
                    t.assert_equals(compile("(/ 1 2 3)"), "(1 / 2 / 3)")
                end,
                ["%"] = function()
                    t.assert_equals(compile("(% 1)"), "(1)")
                    t.assert_equals(compile("(% 1 2)"), "(1 % 2)")
                    t.assert_equals(compile("(% 1 2 3)"), "(1 % 2 % 3)")
                end
            },
            ["dot operator"] = {
                ["for method calls"] = function()
                    compile("(def instance nil)")
                    t.assert_equals(compile("(. instance (method))"), "clue.var(\"user.ns\", \"instance\"):get():method()")
                    t.assert_equals(compile("(. instance (method 1))"), "clue.var(\"user.ns\", \"instance\"):get():method(1)")
                    t.assert_equals(compile("(. instance (method 1 2 3))"), "clue.var(\"user.ns\", \"instance\"):get():method(1, 2, 3)")
                end,
                ["for member access"] = function()
                    compile("(def instance nil)")
                    t.assert_equals(compile("(. instance member)"), "clue.var(\"user.ns\", \"instance\"):get().member")
                end
            },
            ["if statement"] = {
                ["with else"] = function()
                    compile("(def cond nil) (def then nil) (def else nil)")
                    t.assert_equals(compile("(if cond then else)"), "(function() if (clue.var(\"user.ns\", \"cond\"):get()) then return clue.var(\"user.ns\", \"then\"):get(); else return clue.var(\"user.ns\", \"else\"):get(); end end)()")
                end,
                ["without else"] = function()
                    compile("(def cond nil) (def then nil)")
                    t.assert_equals(compile("(if cond then)"), "(function() if (clue.var(\"user.ns\", \"cond\"):get()) then return clue.var(\"user.ns\", \"then\"):get(); else return nil; end end)()")
                end
            },
            ["do statement"] = function()
                compile("(def f1 nil) (def f2 nil) (def f3 nil)")
                t.assert_equals(compile("(do)"), compile("nil"))
                t.assert_equals(compile("(do (f1))"), compile("(f1)"))
                t.assert_equals(compile("(do (f1) (f2) (f3))"), "(function() clue.var(\"user.ns\", \"f1\"):get()(); clue.var(\"user.ns\", \"f2\"):get()(); return clue.var(\"user.ns\", \"f3\"):get()(); end)()")
            end,
            ["try/finally"] = function()
                compile("(def f1 nil) (def f2 nil) (def f3 nil) (def f4 nil)")
                t.assert_equals(compile("(try (f1) (f2) (finally (f3) (f4)))"), "(function() local ok, val = pcall(function() clue.var(\"user.ns\", \"f1\"):get()(); return clue.var(\"user.ns\", \"f2\"):get()(); end); clue.var(\"user.ns\", \"f3\"):get()(); clue.var(\"user.ns\", \"f4\"):get()(); if ok then return val else error(val) end end)()")
            end
        },
        ["should inline lua symbols"] = {
            ["used directly"] = function()
                t.assert_equals(compile("lua/some"), "some")
            end,
            ["aliased"] = function()
                t.assert_equals(compile("(ns user (:require [lua :as L])) L/some"), "clue.ns(\"user\", clue.map(\"L\", \"lua\"));\n" .. "some")
            end,
            ["but not lua aliases"] = function()
                compile("(ns other) (def some nil)")
                t.assert_equals(compile("(ns user (:require [other :as lua])) lua/some"), "clue.ns(\"user\", clue.map(\"lua\", \"other\"));\n" .. "clue.var(\"other\", \"some\"):get()")
            end
        },
        ["quote should"] = {
            ["skip evaluation"] = {
                ["of symbols"] = function()
                    t.assert_equals(compile("'sym"), "clue.symbol(\"sym\")")
                    t.assert_equals(compile("'ns/sym"), "clue.symbol(\"ns\", \"sym\")")
                end,
                ["of lists"] = function()
                    t.assert_equals(compile("'()"), "clue.list()")
                    t.assert_equals(compile("'(1 2 3)"), "clue.list(1, 2, 3)")
                end,
                ["inside lists"] = function()
                    t.assert_equals(compile("'(1 (2 3) (4 (5 6) () 7))"), "clue.list(1, clue.list(2, 3), clue.list(4, clue.list(5, 6), clue.list(), 7))")
                end,
                ["inside vectors"] = function()
                    t.assert_equals(compile("'[1 (2 3) [4 (5 6) 7]]"), "clue.vector(1, clue.list(2, 3), clue.vector(4, clue.list(5, 6), 7))")
                end,
                ["inside maps"] = function()
                    t.assert_equals_any(compile("'{1 (2 3) (4 5) (6 7)}"), "clue.map(1, clue.list(2, 3), clue.list(4, 5), clue.list(6, 7))", "'{1 (2 3) (4 5) (6 7)}", "clue.map(clue.list(4, 5), clue.list(6, 7), 1, clue.list(2, 3))")
                end
            },
            ["forward simple values"] = function()
                t.assert_equals(compile("'nil"), "nil")
                t.assert_equals(compile("'10"), "10")
                t.assert_equals(compile("'\"abc\""), "\"abc\"")
                t.assert_equals(compile("':kkk"), "clue.keyword(\"kkk\")")
            end,
        },
        ["syntax-quote should"] = {
            ["skip evaluation"] = {
                ["of lists"] = function()
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("()")), read("(lua/clue.list)"))
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("(1)")), read("(clue.core/seq (clue.core/concat (lua/clue.list 1)))"))
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("(1 2 3)")), read("(clue.core/seq (clue.core/concat (lua/clue.list 1) (lua/clue.list 2) (lua/clue.list 3)))"))

                    t.assert_equals(compile("`()"), "clue.list()")
                    t.assert_equals(compile("`(1 2 3)"), "clue.var(\"clue.core\", \"seq\"):get()(clue.var(\"clue.core\", \"concat\"):get()(clue.list(1), clue.list(2), clue.list(3)))")
                end,
                ["of vectors"] = function()
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("[]")), read("[]"))
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("[1]")), read("(clue.core/vec (clue.core/concat (lua/clue.list 1)))"))
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("[1 2 3]")), read("(clue.core/vec (clue.core/concat (lua/clue.list 1) (lua/clue.list 2) (lua/clue.list 3)))"))
                end,
                ["inside lists"] = function()
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("(1 (2 (3)))")), read("(clue.core/seq (clue.core/concat (lua/clue.list 1) (lua/clue.list (clue.core/seq (clue.core/concat (lua/clue.list 2) (lua/clue.list (clue.core/seq (clue.core/concat (lua/clue.list 3)))))))))"))
                end,
                ["inside vectors"] = function()
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("[1 (2 [3]) [4]]")), read("(clue.core/vec (clue.core/concat (lua/clue.list 1) (lua/clue.list (clue.core/seq (clue.core/concat (lua/clue.list 2) (lua/clue.list (clue.core/vec (clue.core/concat (lua/clue.list 3))))))) (lua/clue.list (clue.core/vec (clue.core/concat (lua/clue.list 4))))))"))
                end,
                ["inside maps"] = function()
                    t.assert_equals_any(
                        compile("`{1 (2 3) (4 5) (6 7)}"),
                        "clue.map(1, clue.var(\"clue.core\", \"seq\"):get()(clue.var(\"clue.core\", \"concat\"):get()(clue.list(2), clue.list(3))), clue.var(\"clue.core\", \"seq\"):get()(clue.var(\"clue.core\", \"concat\"):get()(clue.list(4), clue.list(5))), clue.var(\"clue.core\", \"seq\"):get()(clue.var(\"clue.core\", \"concat\"):get()(clue.list(6), clue.list(7))))",
                        "clue.map(clue.var(\"clue.core\", \"seq\"):get()(clue.var(\"clue.core\", \"concat\"):get()(clue.list(4), clue.list(5))), clue.var(\"clue.core\", \"seq\"):get()(clue.var(\"clue.core\", \"concat\"):get()(clue.list(6), clue.list(7))), 1, clue.var(\"clue.core\", \"seq\"):get()(clue.var(\"clue.core\", \"concat\"):get()(clue.list(2), clue.list(3))))")
                end
            },
            ["forward simple values"] = function()
                ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("nil")), read("nil"))
                ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("10")), read("10"))
                ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("\"abc\"")), read("\"abc\""))
                ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read(":kkk")), read(":kkk"))
            end,
            ["resolve"] = {
                ["defined symbols"] = function()
                    compile("(def sym nil)")
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("sym")), read("(quote user.ns/sym)"))
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("user.ns/sym")), read("(quote user.ns/sym)"))
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("+")), read("(quote clue.core/+)"))
                end,
                ["not defined symbols"] = function()
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("sym")), read("(quote user.ns/sym)"))
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("ns/sym")), read("(quote ns/sym)"))
                end,
                ["symbols but not special forms"] = function()
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("if")), read("(quote if)"))
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("def")), read("(quote def)"))
                end,
                ["generated symbols"] = function()
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("xyz#")), read("(quote xyz__1__auto__)"))
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("[xyz# xyz#]")), read("(clue.core/vec (clue.core/concat (lua/clue.list (quote xyz__2__auto__)) (lua/clue.list (quote xyz__2__auto__))))"))
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("[xyz# abc#]")), read("(clue.core/vec (clue.core/concat (lua/clue.list (quote xyz__3__auto__)) (lua/clue.list (quote abc__4__auto__))))"))
                end,
                ["symbols inside lists"] = function()
                    compile("(def a nil) (def b nil) (def c nil)")
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("(a (b (c)))")), read("(clue.core/seq (clue.core/concat (lua/clue.list (quote user.ns/a)) (lua/clue.list (clue.core/seq (clue.core/concat (lua/clue.list (quote user.ns/b)) (lua/clue.list (clue.core/seq (clue.core/concat (lua/clue.list (quote user.ns/c))))))))))"))
                end,
                ["symbols inside vectors"] = function()
                    compile("(def a nil) (def b nil) (def c nil)")
                    ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("[a [b [c]]]")), read("(clue.core/vec (clue.core/concat (lua/clue.list (quote user.ns/a)) (lua/clue.list (clue.core/vec (clue.core/concat (lua/clue.list (quote user.ns/b)) (lua/clue.list (clue.core/vec (clue.core/concat (lua/clue.list (quote user.ns/c))))))))))"))
                end,
                ["symbols inside maps"] = function()
                    compile("(def a nil) (def b nil)")
                    t.assert_equals_any(compile("`{a (b)}"), "clue.map(clue.symbol(\"user.ns\", \"a\"), clue.var(\"clue.core\", \"seq\"):get()(clue.var(\"clue.core\", \"concat\"):get()(clue.list(clue.symbol(\"user.ns\", \"b\")))))")
                end
            }
        },
        ["unquote should"] = {
            ["evaluate expressions inside syntax-quote"] = function()
                compile("(def f nil)")
                ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("~sym")), read("sym"))
                ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("~(f 1 2)")), read("(f 1 2)"))
                ct.assert_equals(clue.compiler.syntax_quote(clue._ns_, read("(f ~f f)")), read("(clue.core/seq (clue.core/concat (lua/clue.list (quote user.ns/f)) (lua/clue.list f) (lua/clue.list (quote user.ns/f))))"))
            end
        },
        ["unquote-splicing should"] = {
            ["evaluate expressions inside syntax-quote"] = function()
                compile("(def a nil) (def b nil) (def g nil)")
                ct.assert_equals(
                    clue.compiler.syntax_quote(clue._ns_, read("(a b ~@[c d] ~@'(e f) g)")),
                    read("(clue.core/seq (clue.core/concat (lua/clue.list (quote user.ns/a)) (lua/clue.list (quote user.ns/b)) [c d] (quote (e f)) (lua/clue.list (quote user.ns/g))))"))
                ct.assert_equals(
                    clue.compiler.syntax_quote(clue._ns_, read("[a b ~@[c d] ~@'(e f) g]")),
                    read("(clue.core/vec (clue.core/concat (lua/clue.list (quote user.ns/a)) (lua/clue.list (quote user.ns/b)) [c d] (quote (e f)) (lua/clue.list (quote user.ns/g))))"))
            end
        },
        ["macro"] = {
            ["should be evaluated at during compilation"] = function()
                t.assert_equals(
                    compile("(def ^:macro reverse (fn [a b] [b a])) (reverse (+ 1 2) (+ 3 4))"),
                    compile("(def ^:macro reverse (fn [a b] [b a])) [(+ 3 4) (+ 1 2)]"))
            end,
            ["should expand namespace qualified macros"] = function()
                compile("(def ^:macro add (fn ([a] a) ([a & rest] `(+ ~a (add ~@rest)))))")
                ct.assert_equals(
                    clue.compiler.expand_macro(clue._ns_, {}, nil, read("(user.ns/add 1 2 3)")),
                    read("(clue.core/+ 1 (user.ns/add 2 3))"))
            end
        }
    }
})
