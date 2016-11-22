local t = require("ut")
require("compiler")

local compile = clue.compiler.compile

t.describe("clue.compiler", {
    [".compile"] = {
        ["should translate"] = {
            ["lists into function calls"] = function()
                ns = {name = "user.ns"}
                t.assert_equals(compile(ns, "(hi)"), "clue.var(\"user.ns\", \"hi\"):get()()")
                t.assert_equals(compile(ns, "(hi 1 2 3)"), "clue.var(\"user.ns\", \"hi\"):get()(1, 2, 3)")
                t.assert_equals(compile(ns, "(my.ns/ff)"), "clue.var(\"my.ns\", \"ff\"):get()()")
                t.assert_equals(compile(ns, "(my.ns/ff 1 2 3)"), "clue.var(\"my.ns\", \"ff\"):get()(1, 2, 3)")
                t.assert_equals(compile(ns, "(my.ns/ff x s/y)"), "clue.var(\"my.ns\", \"ff\"):get()(clue.var(\"user.ns\", \"x\"):get(), clue.var(\"s\", \"y\"):get())")
                t.assert_equals(compile(ns, "((fn [] 10))"), compile(ns, "(fn [] 10)") .. "()")
            end,
            ["nested list into nested function calls"] = function()
                ns = {name = "user.ns"}
                t.assert_equals(compile(ns, "(hi (there))"), "clue.var(\"user.ns\", \"hi\"):get()(clue.var(\"user.ns\", \"there\"):get()())")
            end,
            ["strings"] = function()
                t.assert_equals(compile(nil, "\"Sonia\""), "\"Sonia\"")
            end,
            ["symbols into vars"] = function()
                ns = {name = "user.ns"}
                t.assert_equals(compile(ns, "an-example"), "clue.var(\"user.ns\", \"an-example\"):get()")
                t.assert_equals(compile(ns, "my.ns.example/an-example"), "clue.var(\"my.ns.example\", \"an-example\"):get()")
            end,
            ["keywords"] = function()
                t.assert_equals(compile(nil, ":an-example"), "clue.keyword(\"an-example\")")
                t.assert_equals(compile(nil, ":ns/example"), "clue.keyword(\"ns\", \"example\")")
            end,
            ["vectors into clue.vector calls"] = function()
                ns = {name = "user.ns"}
                t.assert_equals(compile(ns, "[]"), "clue.vector()")
                t.assert_equals(compile(ns, "[1 2 3 4]"), "clue.vector(1, 2, 3, 4)")
                t.assert_equals(compile(ns, "[(hello) s/x]"), "clue.vector(clue.var(\"user.ns\", \"hello\"):get()(), clue.var(\"s\", \"x\"):get())")
            end,
            ["maps into clue.map calls"] = function()
                ns = {name = "user.ns"}
                t.assert_equals(compile(ns, "{}"), "clue.map()")
                t.assert_equals_any(compile(ns, "{3 4 1 2}"), "clue.map(1, 2, 3, 4)", "clue.map(3, 4, 1, 2)a")
            end,
            ["function definitions"] = {
                ["with no parameters"] = function()
                    ns = {name = "user.ns"}
                    t.assert_equals(compile(ns, "(fn [] (f 1 2))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 0 then return clue.var(\"user.ns\", \"f\"):get()(1, 2) end; clue.arg_count_error(arg_count_); end)")
                    t.assert_equals(compile(ns, "(fn [] (f 1) (g 2) (h 3))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 0 then clue.var(\"user.ns\", \"f\"):get()(1); clue.var(\"user.ns\", \"g\"):get()(2); return clue.var(\"user.ns\", \"h\"):get()(3) end; clue.arg_count_error(arg_count_); end)")
                end,
                ["with declared parameters"] = function()
                    ns = {name = "user.ns"}
                    t.assert_equals(compile(ns, "(fn [a] (f 1 2))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 1 then return (function(a) return clue.var(\"user.ns\", \"f\"):get()(1, 2) end)(...) end; clue.arg_count_error(arg_count_); end)")
                    t.assert_equals(compile(ns, "(fn [b c d] (f 1 2) (g 2) (h 3))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 3 then return (function(b, c, d) clue.var(\"user.ns\", \"f\"):get()(1, 2); clue.var(\"user.ns\", \"g\"):get()(2); return clue.var(\"user.ns\", \"h\"):get()(3) end)(...) end; clue.arg_count_error(arg_count_); end)")
                end,
                ["with variable number of parameters"] = function()
                    ns = {name = "user.ns"}
                    t.assert_equals(compile(ns, "(fn [& args] args)"), "clue.fn(function(...) local args = clue.list(...); return args end)")
                    t.assert_equals(compile(ns, "(fn [a b & args] (a b args) (b a))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ >= 2 then return (function(a, b, ...) local args = clue.list(...); a(b, args); return b(a) end)(...) end; clue.arg_count_error(arg_count_); end)")
                end,
                ["with parameters used in the body"] = function()
                    ns = {name = "user.ns"}
                    t.assert_equals(compile(ns, "(fn [a] (a 1 2))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 1 then return (function(a) return a(1, 2) end)(...) end; clue.arg_count_error(arg_count_); end)")
                    t.assert_equals(compile(ns, "(fn [f x] (f x y))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 2 then return (function(f, x) return f(x, clue.var(\"user.ns\", \"y\"):get()) end)(...) end; clue.arg_count_error(arg_count_); end)")
                    t.assert_equals(compile(ns, "(fn [a b c] (a b) [a b c])"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 3 then return (function(a, b, c) a(b); return clue.vector(a, b, c) end)(...) end; clue.arg_count_error(arg_count_); end)")
                end,
                ["with parameters used in the body of a nested function"] = function()
                    ns = {name = "user.ns"}
                    t.assert_equals(compile(ns, "(fn [a b] (fn [c d] (a b c d)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 2 then return (function(a, b) return clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 2 then return (function(c, d) return a(b, c, d) end)(...) end; clue.arg_count_error(arg_count_); end) end)(...) end; clue.arg_count_error(arg_count_); end)")
                end,
                ["overloaded by the number of parameters"] = {
                    ["- no signatures"] = function()
                        ns = {name = "user.ns"}
                        t.assert_equals(compile(ns, "(fn)"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); clue.arg_count_error(arg_count_); end)")
                    end,
                    ["- one signature"] = function()
                        ns = {name = "user.ns"}
                        t.assert_equals(compile(ns, "(fn ([a b & args] (a b args) (b a)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ >= 2 then return (function(a, b, ...) local args = clue.list(...); a(b, args); return b(a) end)(...) end; clue.arg_count_error(arg_count_); end)")
                    end,
                    ["- many signatures"] = function()
                        ns = {name = "user.ns"}
                        t.assert_equals(compile(ns, "(fn ([] 10) ([x] x) ([y z] (y z)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 0 then return 10 end; if arg_count_ == 1 then return (function(x) return x end)(...) end; if arg_count_ == 2 then return (function(y, z) return y(z) end)(...) end; clue.arg_count_error(arg_count_); end)")
                    end,
                    ["- many signatures with variable number of parameters"] = function()
                        ns = {name = "user.ns"}
                        t.assert_equals(compile(ns, "(fn ([a b & xs] xs) ([x] x) ([y z] (y z)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 1 then return (function(x) return x end)(...) end; if arg_count_ == 2 then return (function(y, z) return y(z) end)(...) end; if arg_count_ >= 2 then return (function(a, b, ...) local xs = clue.list(...); return xs end)(...) end; clue.arg_count_error(arg_count_); end)")
                        t.assert_equals(compile(ns, "(fn ([x y z & xs] xs) ([x] x) ([y z] (y z)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 1 then return (function(x) return x end)(...) end; if arg_count_ == 2 then return (function(y, z) return y(z) end)(...) end; if arg_count_ >= 3 then return (function(x, y, z, ...) local xs = clue.list(...); return xs end)(...) end; clue.arg_count_error(arg_count_); end)")
                    end
                }
            },
            ["metadata"] = {
                ["in vectors"] = function()
                    t.assert_equals(compile(nil, "^:yes [1 2 3]"), "clue.vector(1, 2, 3):with_meta(clue.map(clue.keyword(\"yes\"), true))")
                end,
                ["in keywords"] = function()
                    t.assert_equals(compile(nil, "^:yes :ok"), "clue.keyword(\"ok\"):with_meta(clue.map(clue.keyword(\"yes\"), true))")
                    t.assert_equals(compile(nil, "^:yes :ss/ok"), "clue.keyword(\"ss\", \"ok\"):with_meta(clue.map(clue.keyword(\"yes\"), true))")
                end,
                ["in maps"] = function()
                    t.assert_equals(compile(nil, "^:yes {1 2}"), "clue.map(1, 2):with_meta(clue.map(clue.keyword(\"yes\"), true))")
                end,
                ["in fn"] = function()
                    t.assert_equals(compile(nil, "^:yes (fn [& xs] nil)"), compile(nil, "(fn [& xs] nil)") .. ":with_meta(clue.map(clue.keyword(\"yes\"), true))")
                end,
                ["but not function calls"] = function()
                    ns = {name = "user.ns"}
                    t.assert_equals(compile(ns, "^:no (print 1 2)"), compile(ns, "(print 1 2)"))
                end
            },
            ["variable definitions"] = function()
                ns = {name = "user.ns"}
                t.assert_equals(compile(ns, "(def a 10)"), "clue.def(\"user.ns\", \"a\", 10, nil)")
                t.assert_equals(compile(ns, "(def ready? (fn [& args] nil))"), "clue.def(\"user.ns\", \"ready?\", clue.fn(function(...) local args = clue.list(...); return nil end), nil)")
                t.assert_equals(compile(ns, "(def ^:dynamic a 10)"), "clue.def(\"user.ns\", \"a\", 10, clue.map(clue.keyword(\"dynamic\"), true))")
            end,
            ["variable access"] = function()
                ns = {name = "user.ns"}
                t.assert_equals(compile(ns, "(var some)"), "clue.var(\"user.ns\", \"some\")")
                t.assert_equals(compile(ns, "(var other/some)"), "clue.var(\"other\", \"some\")")
            end,
            ["let definitions"] = {
                ["without constants"] = function()
                    ns = {name = "user.ns"}
                    t.assert_equals(compile(ns, "(let [])"), "nil")
                    t.assert_equals(compile(ns, "(let [] (f 1 2))"), "(function() return clue.var(\"user.ns\", \"f\"):get()(1, 2) end)()")
                    t.assert_equals(compile(ns, "(let [] (f) (f 1 2))"), "(function() clue.var(\"user.ns\", \"f\"):get()(); return clue.var(\"user.ns\", \"f\"):get()(1, 2) end)()")
                end,
                ["with constants"] = function()
                    ns = {name = "user.ns"}
                    t.assert_equals(compile(ns, "(let [a (f)])"), "(function() local a = clue.var(\"user.ns\", \"f\"):get()(); return nil end)()")
                    t.assert_equals(compile(ns, "(let [a f b 2] (a b))"), "(function() local a = clue.var(\"user.ns\", \"f\"):get(); local b = 2; return a(b) end)()")
                    t.assert_equals(compile(ns, "(let [a 1 b 2] (a) (b))"), "(function() local a = 1; local b = 2; a(); return b() end)()")
                    t.assert_equals(compile(ns, "(fn [a] (let [b a] (b a)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 1 then return (function(a) return (function() local b = a; return b(a) end)() end)(...) end; clue.arg_count_error(arg_count_); end)")
                    t.assert_equals(compile(ns, "(let [a a a a a b b a] (b a)"), "(function() local a = clue.var(\"user.ns\", \"a\"):get(); local a = a; local a = clue.var(\"user.ns\", \"b\"):get(); local b = a; return b(a) end)()")
                end
            },
            ["multiple expressions into multiple statements"] = function()
                ns = {name = "some"}
                t.assert_equals(compile(ns, "(def x 9)(f1)"), "clue.def(\"some\", \"x\", 9, nil);\nclue.var(\"some\", \"f1\"):get()()")
                t.assert_equals(compile(ns, "(def x 9)(f1)(f2)"), "clue.def(\"some\", \"x\", 9, nil);\nclue.var(\"some\", \"f1\"):get()();\nclue.var(\"some\", \"f2\"):get()()")
            end,
            ["namespace definitions"] = {
                ["without attributes"] = function()
                    ns = {name = "some"}
                    t.assert_equals(compile(ns, "(ns user.core)"), "clue.ns(\"user.core\")")
                    t.assert_equals(compile(
                        ns,
                        "(ns user.core)(f1)(f2)"),
                        "clue.ns(\"user.core\");\nclue.var(\"user.core\", \"f1\"):get()();\nclue.var(\"user.core\", \"f2\"):get()()")
                    t.assert_equals(compile(
                        ns,
                        "(f1 (ns other))(f2)"),
                        "clue.var(\"some\", \"f1\"):get()(clue.ns(\"other\"));\nclue.var(\"some\", \"f2\"):get()()")
                end,
                ["with require"] = function()
                    t.assert_equals(compile(nil, "(ns user.core (:require org.some.xyz))"), "clue.ns(\"user.core\", {[\"org.some.xyz\"] = \"org.some.xyz\"})")
                    t.assert_equals(compile(nil, "(ns user.core (:require [org.some.xyz :as some]))"), "clue.ns(\"user.core\", {[\"some\"] = \"org.some.xyz\"})")
                    t.assert_equals(compile(nil, "(ns user.core (:require [org.some.xyz :as xyz] [org.some.abc :as other]))"), "clue.ns(\"user.core\", {[\"xyz\"] = \"org.some.xyz\", [\"other\"] = \"org.some.abc\"})")
                    t.assert_equals(compile(
                        nil, "(ns user.core (:require [org.some.xyz :as some])) (some/f1)"),
                        "clue.ns(\"user.core\", {[\"some\"] = \"org.some.xyz\"});\n" ..
                        "clue.var(\"org.some.xyz\", \"f1\"):get()()")
                end
            },
            ["operator"] = {
                ["+"] = function()
                    t.assert_equals(compile(nil, "(+ 1)"), "(1)")
                    t.assert_equals(compile(nil, "(+ 1 2)"), "(1 + 2)")
                    t.assert_equals(compile(nil, "(+ 1 2 3)"), "(1 + 2 + 3)")
                end,
                ["-"] = function()
                    t.assert_equals(compile(nil, "(- 1)"), "(-1)")
                    t.assert_equals(compile(nil, "(- 1 2)"), "(1 - 2)")
                    t.assert_equals(compile(nil, "(- 1 2 3)"), "(1 - 2 - 3)")
                end,
                ["*"] = function()
                    t.assert_equals(compile(nil, "(* 1)"), "(1)")
                    t.assert_equals(compile(nil, "(* 1 2)"), "(1 * 2)")
                    t.assert_equals(compile(nil, "(* 1 2 3)"), "(1 * 2 * 3)")
                end,
                ["/"] = function()
                    t.assert_equals(compile(nil, "(/ 1)"), "(1)")
                    t.assert_equals(compile(nil, "(/ 1 2)"), "(1 / 2)")
                    t.assert_equals(compile(nil, "(/ 1 2 3)"), "(1 / 2 / 3)")
                end,
                ["%"] = function()
                    t.assert_equals(compile(nil, "(% 1)"), "(1)")
                    t.assert_equals(compile(nil, "(% 1 2)"), "(1 % 2)")
                    t.assert_equals(compile(nil, "(% 1 2 3)"), "(1 % 2 % 3)")
                end
            },
            ["dot operator"] = {
                ["for method calls"] = function()
                    t.assert_equals(compile({name="ns"}, "(. instance (method))"), "clue.var(\"ns\", \"instance\"):get():method()")
                    t.assert_equals(compile({name="ns"}, "(. instance (method 1))"), "clue.var(\"ns\", \"instance\"):get():method(1)")
                    t.assert_equals(compile({name="ns"}, "(. instance (method 1 2 3))"), "clue.var(\"ns\", \"instance\"):get():method(1, 2, 3)")
                end,
                ["for member access"] = function()
                    t.assert_equals(compile({name="ns"}, "(. instance member)"), "clue.var(\"ns\", \"instance\"):get().member")
                end
            },
            ["if statement"] = {
                ["with else"] = function()
                    t.assert_equals(compile({name="ns"}, "(if cond then else)"), "(function() if (clue.var(\"ns\", \"cond\"):get()) then return clue.var(\"ns\", \"then\"):get(); else return clue.var(\"ns\", \"else\"):get(); end end)()")
                end,
                ["without else"] = function()
                    t.assert_equals(compile({name="ns"}, "(if cond then)"), "(function() if (clue.var(\"ns\", \"cond\"):get()) then return clue.var(\"ns\", \"then\"):get(); else return nil; end end)()")
                end
            },
            ["do statement"] = function()
                ns = {name = "ns"}
                t.assert_equals(compile(ns, "(do)"), compile(ns, "nil"))
                t.assert_equals(compile(ns, "(do (f1))"), compile(ns, "(f1)"))
                t.assert_equals(compile(ns, "(do (f1) (f2) (f3))"), "(function() clue.var(\"ns\", \"f1\"):get()(); clue.var(\"ns\", \"f2\"):get()(); return clue.var(\"ns\", \"f3\"):get()(); end)()")
            end,
            ["try/finally"] = function()
                t.assert_equals(compile({name="ns"}, "(try (f1) (f2) (finally (f3) (f4)))"), "(function() local ok, val = pcall(function() clue.var(\"ns\", \"f1\"):get()(); return clue.var(\"ns\", \"f2\"):get()(); end); clue.var(\"ns\", \"f3\"):get()(); clue.var(\"ns\", \"f4\"):get()(); if ok then return val else error(val) end end)()")
            end
        },
        ["should inline lua symbols"] = {
            ["used directly"] = function()
                t.assert_equals(compile({name="ns"}, "lua/some"), "some")
            end,
            ["aliased"] = function()
                t.assert_equals(compile(nil, "(ns user (:require [lua :as L])) L/some"), "clue.ns(\"user\", {[\"L\"] = \"lua\"});\n" .. "some")
            end,
            ["but not lua aliases"] = function()
                t.assert_equals(compile(nil, "(ns user (:require [other :as lua])) lua/some"), "clue.ns(\"user\", {[\"lua\"] = \"other\"});\n" .. "clue.var(\"other\", \"some\"):get()")
            end
        },
        ["quote should"] = {
            ["skip evaluation"] = {
                ["of symbols"] = function()
                    t.assert_equals(compile({name="ns"}, "'sym"), "clue.symbol(\"sym\")")
                    t.assert_equals(compile({name="ns"}, "'ns/sym"), "clue.symbol(\"ns\", \"sym\")")
                end,
                ["of lists"] = function()
                    t.assert_equals(compile({name="ns"}, "'()"), "clue.list()")
                    t.assert_equals(compile({name="ns"}, "'(1 2 3)"), "clue.list(1, 2, 3)")
                end,
                ["inside lists"] = function()
                    t.assert_equals(compile({name="ns"}, "'(1 (2 3) (4 (5 6) () 7))"), "clue.list(1, clue.list(2, 3), clue.list(4, clue.list(5, 6), clue.list(), 7))")
                end,
                ["inside vectors"] = function()
                    t.assert_equals(compile({name="ns"}, "'[1 (2 3) [4 (5 6) 7]]"), "clue.vector(1, clue.list(2, 3), clue.vector(4, clue.list(5, 6), 7))")
                end,
                ["inside maps"] = function()
                    t.assert_equals_any(compile({name="ns"}, "'{1 (2 3) (4 5) (6 7)}"), "clue.map(1, clue.list(2, 3), clue.list(4, 5), clue.list(6, 7))", "'{1 (2 3) (4 5) (6 7)}", "clue.map(clue.list(4, 5), clue.list(6, 7), 1, clue.list(2, 3))")
                end
            },
            ["forward simple values"] = function()
                t.assert_equals(compile({name="ns"}, "'nil"), "nil")
                t.assert_equals(compile({name="ns"}, "'10"), "10")
                t.assert_equals(compile({name="ns"}, "'\"abc\""), "\"abc\"")
                t.assert_equals(compile({name="ns"}, "':kkk"), "clue.keyword(\"kkk\")")
            end,
        },
        ["syntax-quote should"] = {
            ["skip evaluation"] = {
                ["of lists"] = function()
                    t.assert_equals(compile({name="ns"}, "`()"), "clue.list()")
                    t.assert_equals(compile({name="ns"}, "`(1 2 3)"), "clue.list(1, 2, 3)")
                end,
                ["inside lists"] = function()
                    t.assert_equals(compile({name="ns"}, "`(1 (2 3) (4 (5 6) () 7))"), "clue.list(1, clue.list(2, 3), clue.list(4, clue.list(5, 6), clue.list(), 7))")
                end,
                ["inside vectors"] = function()
                    t.assert_equals(compile({name="ns"}, "`[1 (2 3) [4 (5 6) 7]]"), "clue.vector(1, clue.list(2, 3), clue.vector(4, clue.list(5, 6), 7))")
                end,
                ["inside maps"] = function()
                    t.assert_equals_any(compile({name="ns"}, "`{1 (2 3) (4 5) (6 7)}"), "clue.map(1, clue.list(2, 3), clue.list(4, 5), clue.list(6, 7))", "'{1 (2 3) (4 5) (6 7)}", "clue.map(clue.list(4, 5), clue.list(6, 7), 1, clue.list(2, 3))")
                end
            },
            ["forward simple values"] = function()
                t.assert_equals(compile({name="ns"}, "`nil"), "nil")
                t.assert_equals(compile({name="ns"}, "`10"), "10")
                t.assert_equals(compile({name="ns"}, "`\"abc\""), "\"abc\"")
                t.assert_equals(compile({name="ns"}, "`:kkk"), "clue.keyword(\"kkk\")")
            end,
            ["resolve"] = {
                ["symbols"] = function()
                    t.assert_equals(compile({name="ns"}, "`sym"), "clue.symbol(\"ns\", \"sym\")")
                    t.assert_equals(compile({name="ns"}, "`ns/sym"), "clue.symbol(\"ns\", \"sym\")")
                end,
                ["symbols inside lists"] = function()
                    t.assert_equals(compile({name="ns"}, "`(a (b (c)))"), "clue.list(clue.symbol(\"ns\", \"a\"), clue.list(clue.symbol(\"ns\", \"b\"), clue.list(clue.symbol(\"ns\", \"c\"))))")
                end,
                ["symbols inside vectors"] = function()
                    t.assert_equals(compile({name="ns"}, "`[a [b [c]]]"), "clue.vector(clue.symbol(\"ns\", \"a\"), clue.vector(clue.symbol(\"ns\", \"b\"), clue.vector(clue.symbol(\"ns\", \"c\"))))")
                end,
                ["symbols inside maps"] = function()
                    t.assert_equals_any(compile({name="ns"}, "`{a (b)}"), "clue.map(clue.symbol(\"ns\", \"a\"), clue.list(clue.symbol(\"ns\", \"b\")))")
                end
            }
        }
    }
})
