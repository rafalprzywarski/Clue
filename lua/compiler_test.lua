local t = require("ut")
require("compiler")

t.describe("clue.compiler", {
    [".compile"] = {
        ["should translate"] = {
            ["lists into function calls"] = function()
                ns = {name = "user.ns"}
                t.assert_equals(clue.compiler.compile(ns, "(hi)"), "clue.namespaces[\"user.ns\"][\"hi\"]()")
                t.assert_equals(clue.compiler.compile(ns, "(hi 1 2 3)"), "clue.namespaces[\"user.ns\"][\"hi\"](1, 2, 3)")
                t.assert_equals(clue.compiler.compile(ns, "(my.ns/ff)"), "clue.namespaces[\"my.ns\"][\"ff\"]()")
                t.assert_equals(clue.compiler.compile(ns, "(my.ns/ff 1 2 3)"), "clue.namespaces[\"my.ns\"][\"ff\"](1, 2, 3)")
                t.assert_equals(clue.compiler.compile(ns, "(my.ns/ff x s/y)"), "clue.namespaces[\"my.ns\"][\"ff\"](clue.namespaces[\"user.ns\"][\"x\"], clue.namespaces[\"s\"][\"y\"])")
                t.assert_equals(clue.compiler.compile(ns, "((fn [] 10))"), clue.compiler.compile(ns, "(fn [] 10)") .. "()")
            end,
            ["nested list into nested function calls"] = function()
                ns = {name = "user.ns"}
                t.assert_equals(clue.compiler.compile(ns, "(hi (there))"), "clue.namespaces[\"user.ns\"][\"hi\"](clue.namespaces[\"user.ns\"][\"there\"]())")
            end,
            ["strings"] = function()
                t.assert_equals(clue.compiler.compile(nil, "\"Sonia\""), "\"Sonia\"")
            end,
            ["symbols into vars"] = function()
                ns = {name = "user.ns"}
                t.assert_equals(clue.compiler.compile(ns, "an-example"), "clue.namespaces[\"user.ns\"][\"an-example\"]")
                t.assert_equals(clue.compiler.compile(ns, "my.ns.example/an-example"), "clue.namespaces[\"my.ns.example\"][\"an-example\"]")
            end,
            ["keywords"] = function()
                t.assert_equals(clue.compiler.compile(nil, ":an-example"), "clue.keyword(\"an-example\")")
                t.assert_equals(clue.compiler.compile(nil, ":ns/example"), "clue.keyword(\"ns\", \"example\")")
            end,
            ["vectors into clue.vector calls"] = function()
                ns = {name = "user.ns"}
                t.assert_equals(clue.compiler.compile(ns, "[]"), "clue.vector()")
                t.assert_equals(clue.compiler.compile(ns, "[1 2 3 4]"), "clue.vector(1, 2, 3, 4)")
                t.assert_equals(clue.compiler.compile(ns, "[(hello) s/x]"), "clue.vector(clue.namespaces[\"user.ns\"][\"hello\"](), clue.namespaces[\"s\"][\"x\"])")
            end,
            ["maps into clue.map calls"] = function()
                ns = {name = "user.ns"}
                t.assert_equals(clue.compiler.compile(ns, "{}"), "clue.map()")
                t.assert_equals_any(clue.compiler.compile(ns, "{3 4 1 2}"), "clue.map(1, 2, 3, 4)", "clue.map(3, 4, 1, 2)a")
            end,
            ["function definitions"] = {
                ["with no parameters"] = function()
                    ns = {name = "user.ns"}
                    t.assert_equals(clue.compiler.compile(ns, "(fn [] (f 1 2))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 0 then return clue.namespaces[\"user.ns\"][\"f\"](1, 2) end; clue.arg_count_error(arg_count_); end)")
                    t.assert_equals(clue.compiler.compile(ns, "(fn [] (f 1) (g 2) (h 3))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 0 then clue.namespaces[\"user.ns\"][\"f\"](1); clue.namespaces[\"user.ns\"][\"g\"](2); return clue.namespaces[\"user.ns\"][\"h\"](3) end; clue.arg_count_error(arg_count_); end)")
                end,
                ["with declared parameters"] = function()
                    ns = {name = "user.ns"}
                    t.assert_equals(clue.compiler.compile(ns, "(fn [a] (f 1 2))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 1 then return (function(a) return clue.namespaces[\"user.ns\"][\"f\"](1, 2) end)(...) end; clue.arg_count_error(arg_count_); end)")
                    t.assert_equals(clue.compiler.compile(ns, "(fn [b c d] (f 1 2) (g 2) (h 3))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 3 then return (function(b, c, d) clue.namespaces[\"user.ns\"][\"f\"](1, 2); clue.namespaces[\"user.ns\"][\"g\"](2); return clue.namespaces[\"user.ns\"][\"h\"](3) end)(...) end; clue.arg_count_error(arg_count_); end)")
                end,
                ["with variable number of parameters"] = function()
                    ns = {name = "user.ns"}
                    t.assert_equals(clue.compiler.compile(ns, "(fn [& args] args)"), "clue.fn(function(...) local args = clue.list(...); return args end)")
                    t.assert_equals(clue.compiler.compile(ns, "(fn [a b & args] (a b args) (b a))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ >= 2 then return (function(a, b, ...) local args = clue.list(...); a(b, args); return b(a) end)(...) end; clue.arg_count_error(arg_count_); end)")
                end,
                ["with parameters used in the body"] = function()
                    ns = {name = "user.ns"}
                    t.assert_equals(clue.compiler.compile(ns, "(fn [a] (a 1 2))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 1 then return (function(a) return a(1, 2) end)(...) end; clue.arg_count_error(arg_count_); end)")
                    t.assert_equals(clue.compiler.compile(ns, "(fn [f x] (f x y))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 2 then return (function(f, x) return f(x, clue.namespaces[\"user.ns\"][\"y\"]) end)(...) end; clue.arg_count_error(arg_count_); end)")
                    t.assert_equals(clue.compiler.compile(ns, "(fn [a b c] (a b) [a b c])"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 3 then return (function(a, b, c) a(b); return clue.vector(a, b, c) end)(...) end; clue.arg_count_error(arg_count_); end)")
                end,
                ["with parameters used in the body of a nested function"] = function()
                    ns = {name = "user.ns"}
                    t.assert_equals(clue.compiler.compile(ns, "(fn [a b] (fn [c d] (a b c d)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 2 then return (function(a, b) return clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 2 then return (function(c, d) return a(b, c, d) end)(...) end; clue.arg_count_error(arg_count_); end) end)(...) end; clue.arg_count_error(arg_count_); end)")
                end,
                ["overloaded by the number of parameters"] = {
                    ["- no signatures"] = function()
                        ns = {name = "user.ns"}
                        t.assert_equals(clue.compiler.compile(ns, "(fn)"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); clue.arg_count_error(arg_count_); end)")
                    end,
                    ["- one signature"] = function()
                        ns = {name = "user.ns"}
                        t.assert_equals(clue.compiler.compile(ns, "(fn ([a b & args] (a b args) (b a)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ >= 2 then return (function(a, b, ...) local args = clue.list(...); a(b, args); return b(a) end)(...) end; clue.arg_count_error(arg_count_); end)")
                    end,
                    ["- many signatures"] = function()
                        ns = {name = "user.ns"}
                        t.assert_equals(clue.compiler.compile(ns, "(fn ([] 10) ([x] x) ([y z] (y z)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 0 then return 10 end; if arg_count_ == 1 then return (function(x) return x end)(...) end; if arg_count_ == 2 then return (function(y, z) return y(z) end)(...) end; clue.arg_count_error(arg_count_); end)")
                    end,
                    ["- many signatures with variable number of parameters"] = function()
                        ns = {name = "user.ns"}
                        t.assert_equals(clue.compiler.compile(ns, "(fn ([a b & xs] xs) ([x] x) ([y z] (y z)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 1 then return (function(x) return x end)(...) end; if arg_count_ == 2 then return (function(y, z) return y(z) end)(...) end; if arg_count_ >= 2 then return (function(a, b, ...) local xs = clue.list(...); return xs end)(...) end; clue.arg_count_error(arg_count_); end)")
                        t.assert_equals(clue.compiler.compile(ns, "(fn ([x y z & xs] xs) ([x] x) ([y z] (y z)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 1 then return (function(x) return x end)(...) end; if arg_count_ == 2 then return (function(y, z) return y(z) end)(...) end; if arg_count_ >= 3 then return (function(x, y, z, ...) local xs = clue.list(...); return xs end)(...) end; clue.arg_count_error(arg_count_); end)")
                    end
                }
            },
            ["metadata"] = {
                ["in vectors"] = function()
                    t.assert_equals(clue.compiler.compile(nil, "^:yes [1 2 3]"), "clue.vector(1, 2, 3):with_meta(clue.map(clue.keyword(\"yes\"), true))")
                end,
                ["in keywords"] = function()
                    t.assert_equals(clue.compiler.compile(nil, "^:yes :ok"), "clue.keyword(\"ok\"):with_meta(clue.map(clue.keyword(\"yes\"), true))")
                    t.assert_equals(clue.compiler.compile(nil, "^:yes :ss/ok"), "clue.keyword(\"ss\", \"ok\"):with_meta(clue.map(clue.keyword(\"yes\"), true))")
                end,
                ["in maps"] = function()
                    t.assert_equals(clue.compiler.compile(nil, "^:yes {1 2}"), "clue.map(1, 2):with_meta(clue.map(clue.keyword(\"yes\"), true))")
                end,
                ["in fn"] = function()
                    t.assert_equals(clue.compiler.compile(nil, "^:yes (fn [& xs] nil)"), clue.compiler.compile(nil, "(fn [& xs] nil)") .. ":with_meta(clue.map(clue.keyword(\"yes\"), true))")
                end,
                ["but not function calls"] = function()
                    ns = {name = "user.ns"}
                    t.assert_equals(clue.compiler.compile(ns, "^:no (print 1 2)"), clue.compiler.compile(ns, "(print 1 2)"))
                end
            },
            ["variable definitions"] = function()
                ns = {name = "user.ns"}
                t.assert_equals(clue.compiler.compile(ns, "(def a 10)"), "(function() clue.namespaces[\"user.ns\"][\"a\"] = 10 end)()")
                t.assert_equals(clue.compiler.compile(ns, "(def ready? (fn [& args] nil))"), "(function() clue.namespaces[\"user.ns\"][\"ready?\"] = clue.fn(function(...) local args = clue.list(...); return nil end) end)()")
            end,
            ["let definitions"] = {
                ["without constants"] = function()
                    ns = {name = "user.ns"}
                    t.assert_equals(clue.compiler.compile(ns, "(let [])"), "nil")
                    t.assert_equals(clue.compiler.compile(ns, "(let [] (f 1 2))"), "(function() return clue.namespaces[\"user.ns\"][\"f\"](1, 2) end)()")
                    t.assert_equals(clue.compiler.compile(ns, "(let [] (f) (f 1 2))"), "(function() clue.namespaces[\"user.ns\"][\"f\"](); return clue.namespaces[\"user.ns\"][\"f\"](1, 2) end)()")
                end,
                ["with constants"] = function()
                    ns = {name = "user.ns"}
                    t.assert_equals(clue.compiler.compile(ns, "(let [a (f)])"), "(function() local a = clue.namespaces[\"user.ns\"][\"f\"](); return nil end)()")
                    t.assert_equals(clue.compiler.compile(ns, "(let [a f b 2] (a b))"), "(function() local a = clue.namespaces[\"user.ns\"][\"f\"]; local b = 2; return a(b) end)()")
                    t.assert_equals(clue.compiler.compile(ns, "(let [a 1 b 2] (a) (b))"), "(function() local a = 1; local b = 2; a(); return b() end)()")
                    t.assert_equals(clue.compiler.compile(ns, "(fn [a] (let [b a] (b a)))"), "clue.fn(function(...) local arg_count_ = select(\"#\", ...); if arg_count_ == 1 then return (function(a) return (function() local b = a; return b(a) end)() end)(...) end; clue.arg_count_error(arg_count_); end)")
                    t.assert_equals(clue.compiler.compile(ns, "(let [a a a a a b b a] (b a)"), "(function() local a = clue.namespaces[\"user.ns\"][\"a\"]; local a = a; local a = clue.namespaces[\"user.ns\"][\"b\"]; local b = a; return b(a) end)()")
                end
            },
            ["multiple expressions into multiple statements"] = function()
                ns = {name = "some"}
                t.assert_equals(clue.compiler.compile(ns, "(def x 9)(f1)"), "(function() clue.namespaces[\"some\"][\"x\"] = 9 end)();\nclue.namespaces[\"some\"][\"f1\"]()")
                t.assert_equals(clue.compiler.compile(ns, "(def x 9)(f1)(f2)"), "(function() clue.namespaces[\"some\"][\"x\"] = 9 end)();\nclue.namespaces[\"some\"][\"f1\"]();\nclue.namespaces[\"some\"][\"f2\"]()")
            end,
            ["namespace definitions"] = {
                ["without attributes"] = function()
                    ns = {name = "some"}
                    t.assert_equals(clue.compiler.compile(ns, "(ns user.core)"), "clue.ns(\"user.core\")")
                    t.assert_equals(clue.compiler.compile(
                        ns,
                        "(ns user.core)(f1)(f2)"),
                        "clue.ns(\"user.core\");\nclue.namespaces[\"user.core\"][\"f1\"]();\nclue.namespaces[\"user.core\"][\"f2\"]()")
                    t.assert_equals(clue.compiler.compile(
                        ns,
                        "(f1 (ns other))(f2)"),
                        "clue.namespaces[\"some\"][\"f1\"](clue.ns(\"other\"));\nclue.namespaces[\"some\"][\"f2\"]()")
                end,
                ["with require"] = function()
                    t.assert_equals(clue.compiler.compile(nil, "(ns user.core (:require org.some.xyz))"), "clue.ns(\"user.core\", {[\"org.some.xyz\"] = \"org.some.xyz\"})")
                    t.assert_equals(clue.compiler.compile(nil, "(ns user.core (:require [org.some.xyz :as some]))"), "clue.ns(\"user.core\", {[\"some\"] = \"org.some.xyz\"})")
                    t.assert_equals(clue.compiler.compile(nil, "(ns user.core (:require [org.some.xyz :as xyz] [org.some.abc :as other]))"), "clue.ns(\"user.core\", {[\"xyz\"] = \"org.some.xyz\", [\"other\"] = \"org.some.abc\"})")
                    t.assert_equals(clue.compiler.compile(
                        nil, "(ns user.core (:require [org.some.xyz :as some])) (some/f1)"),
                        "clue.ns(\"user.core\", {[\"some\"] = \"org.some.xyz\"});\n" ..
                        "clue.namespaces[\"org.some.xyz\"][\"f1\"]()")
                end
            },
            ["operator"] = {
                ["+"] = function()
                    t.assert_equals(clue.compiler.compile(nil, "(+ 1)"), "(1)")
                    t.assert_equals(clue.compiler.compile(nil, "(+ 1 2)"), "(1 + 2)")
                    t.assert_equals(clue.compiler.compile(nil, "(+ 1 2 3)"), "(1 + 2 + 3)")
                end,
                ["-"] = function()
                    t.assert_equals(clue.compiler.compile(nil, "(- 1)"), "(-1)")
                    t.assert_equals(clue.compiler.compile(nil, "(- 1 2)"), "(1 - 2)")
                    t.assert_equals(clue.compiler.compile(nil, "(- 1 2 3)"), "(1 - 2 - 3)")
                end,
                ["*"] = function()
                    t.assert_equals(clue.compiler.compile(nil, "(* 1)"), "(1)")
                    t.assert_equals(clue.compiler.compile(nil, "(* 1 2)"), "(1 * 2)")
                    t.assert_equals(clue.compiler.compile(nil, "(* 1 2 3)"), "(1 * 2 * 3)")
                end,
                ["/"] = function()
                    t.assert_equals(clue.compiler.compile(nil, "(/ 1)"), "(1)")
                    t.assert_equals(clue.compiler.compile(nil, "(/ 1 2)"), "(1 / 2)")
                    t.assert_equals(clue.compiler.compile(nil, "(/ 1 2 3)"), "(1 / 2 / 3)")
                end,
                ["%"] = function()
                    t.assert_equals(clue.compiler.compile(nil, "(% 1)"), "(1)")
                    t.assert_equals(clue.compiler.compile(nil, "(% 1 2)"), "(1 % 2)")
                    t.assert_equals(clue.compiler.compile(nil, "(% 1 2 3)"), "(1 % 2 % 3)")
                end
            },
            ["dot operator"] = {
                ["for method calls"] = function()
                    t.assert_equals(clue.compiler.compile({name="ns"}, "(. instance (method))"), "clue.namespaces[\"ns\"][\"instance\"]:method()")
                    t.assert_equals(clue.compiler.compile({name="ns"}, "(. instance (method 1))"), "clue.namespaces[\"ns\"][\"instance\"]:method(1)")
                    t.assert_equals(clue.compiler.compile({name="ns"}, "(. instance (method 1 2 3))"), "clue.namespaces[\"ns\"][\"instance\"]:method(1, 2, 3)")
                end,
                ["for member access"] = function()
                    t.assert_equals(clue.compiler.compile({name="ns"}, "(. instance member)"), "clue.namespaces[\"ns\"][\"instance\"].member")
                end
            },
            ["if statement"] = {
                ["with else"] = function()
                    t.assert_equals(clue.compiler.compile({name="ns"}, "(if cond then else)"), "(function() if (clue.namespaces[\"ns\"][\"cond\"]) then return clue.namespaces[\"ns\"][\"then\"]; else return clue.namespaces[\"ns\"][\"else\"]; end end)()")
                end,
                ["without else"] = function()
                    t.assert_equals(clue.compiler.compile({name="ns"}, "(if cond then)"), "(function() if (clue.namespaces[\"ns\"][\"cond\"]) then return clue.namespaces[\"ns\"][\"then\"]; else return nil; end end)()")
                end
            },
            ["do statement"] = function()
                ns = {name = "ns"}
                t.assert_equals(clue.compiler.compile(ns, "(do)"), clue.compiler.compile(ns, "nil"))
                t.assert_equals(clue.compiler.compile(ns, "(do (f1))"), clue.compiler.compile(ns, "(f1)"))
                t.assert_equals(clue.compiler.compile(ns, "(do (f1) (f2) (f3))"), "(function() clue.namespaces[\"ns\"][\"f1\"](); clue.namespaces[\"ns\"][\"f2\"](); return clue.namespaces[\"ns\"][\"f3\"](); end)()")
            end
        },
        ["should inline lua symbols"] = {
            ["used directly"] = function()
                t.assert_equals(clue.compiler.compile({name="ns"}, "lua/some"), "some")
            end,
            ["aliased"] = function()
                t.assert_equals(clue.compiler.compile(nil, "(ns user (:require [lua :as L])) L/some"), "clue.ns(\"user\", {[\"L\"] = \"lua\"});\n" .. "some")
            end,
            ["but not lua aliases"] = function()
                t.assert_equals(clue.compiler.compile(nil, "(ns user (:require [other :as lua])) lua/some"), "clue.ns(\"user\", {[\"lua\"] = \"other\"});\n" .. "clue.namespaces[\"other\"][\"some\"]")
            end
        },
        ["quote should skip evaluation"] = {
            ["of symbols"] = function()
                t.assert_equals(clue.compiler.compile({name="ns"}, "'sym"), "clue.symbol(\"sym\")")
                t.assert_equals(clue.compiler.compile({name="ns"}, "'ns/sym"), "clue.symbol(\"ns\", \"sym\")")
            end,
            ["of lists"] = function()
                t.assert_equals(clue.compiler.compile({name="ns"}, "'()"), "clue.list()")
                t.assert_equals(clue.compiler.compile({name="ns"}, "'(1 2 3)"), "clue.list(1, 2, 3)")
            end,
            ["inside lists"] = function()
                t.assert_equals(clue.compiler.compile({name="ns"}, "'(1 (2 3) (4 (5 6) () 7))"), "clue.list(1, clue.list(2, 3), clue.list(4, clue.list(5, 6), clue.list(), 7))")
            end,
            ["inside vectors"] = function()
                t.assert_equals(clue.compiler.compile({name="ns"}, "'[1 (2 3) [4 (5 6) 7]]"), "clue.vector(1, clue.list(2, 3), clue.vector(4, clue.list(5, 6), 7))")
            end,
            ["inside maps"] = function()
                t.assert_equals_any(clue.compiler.compile({name="ns"}, "'{1 (2 3) (4 5) (6 7)}"), "clue.map(1, clue.list(2, 3), clue.list(4, 5), clue.list(6, 7))", "'{1 (2 3) (4 5) (6 7)}", "clue.map(clue.list(4, 5), clue.list(6, 7), 1, clue.list(2, 3))")
            end
        },
        ["quote should forward simple values"] = function()
            t.assert_equals(clue.compiler.compile({name="ns"}, "'nil"), "nil")
            t.assert_equals(clue.compiler.compile({name="ns"}, "'10"), "10")
            t.assert_equals(clue.compiler.compile({name="ns"}, "'\"abc\""), "\"abc\"")
            t.assert_equals(clue.compiler.compile({name="ns"}, "':kkk"), "clue.keyword(\"kkk\")")
        end
    }
})
