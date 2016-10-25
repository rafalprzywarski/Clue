local t = require("ut")
require("compiler")

t.describe("clue.compiler", {
    [".compile"] = {
        ["should translate"] = {
            ["lists into function calls"] = function()
                ns = "user.ns"
                t.assert_equals(clue.compiler.compile(ns, "(hi)"), "clue.namespaces[\"user.ns\"][\"hi\"]()")
                t.assert_equals(clue.compiler.compile(ns, "(hi 1 2 3)"), "clue.namespaces[\"user.ns\"][\"hi\"](1, 2, 3)")
                t.assert_equals(clue.compiler.compile(ns, "(my.ns/ff)"), "clue.namespaces[\"my.ns\"][\"ff\"]()")
                t.assert_equals(clue.compiler.compile(ns, "(my.ns/ff 1 2 3)"), "clue.namespaces[\"my.ns\"][\"ff\"](1, 2, 3)")
                t.assert_equals(clue.compiler.compile(ns, "(my.ns/ff x s/y)"), "clue.namespaces[\"my.ns\"][\"ff\"](clue.namespaces[\"user.ns\"][\"x\"], clue.namespaces[\"s\"][\"y\"])")
                t.assert_equals(clue.compiler.compile(ns, "((fn [] 10))"), "(function() return 10 end)()")
            end,
            ["nested list into nested function calls"] = function()
                ns = "user.ns"
                t.assert_equals(clue.compiler.compile(ns, "(hi (there))"), "clue.namespaces[\"user.ns\"][\"hi\"](clue.namespaces[\"user.ns\"][\"there\"]())")
            end,
            ["symbols into vars"] = function()
                ns = "user.ns"
                t.assert_equals(clue.compiler.compile(ns, "an-example"), "clue.namespaces[\"user.ns\"][\"an-example\"]")
                t.assert_equals(clue.compiler.compile(ns, "my.ns.example/an-example"), "clue.namespaces[\"my.ns.example\"][\"an-example\"]")
            end,
            ["vectors into arrays"] = function()
                ns = "user.ns"
                t.assert_equals(clue.compiler.compile(ns, "[]"), "{}")
                t.assert_equals(clue.compiler.compile(ns, "[1 2 3 4]"), "{1, 2, 3, 4}")
                t.assert_equals(clue.compiler.compile(ns, "[(hello) s/x]"), "{clue.namespaces[\"user.ns\"][\"hello\"](), clue.namespaces[\"s\"][\"x\"]}")
            end,
            ["function definitions"] = {
                ["with no parameters"] = function()
                    ns = "user.ns"
                    t.assert_equals(clue.compiler.compile(ns, "(fn [] (f 1 2))"), "(function() return clue.namespaces[\"user.ns\"][\"f\"](1, 2) end)")
                    t.assert_equals(clue.compiler.compile(ns, "(fn [] (f 1) (g 2) (h 3))"), "(function() clue.namespaces[\"user.ns\"][\"f\"](1); clue.namespaces[\"user.ns\"][\"g\"](2); return clue.namespaces[\"user.ns\"][\"h\"](3) end)")
                end,
                ["with declared parameters"] = function()
                    ns = "user.ns"
                    t.assert_equals(clue.compiler.compile(ns, "(fn [a] (f 1 2))"), "(function(a) return clue.namespaces[\"user.ns\"][\"f\"](1, 2) end)")
                    t.assert_equals(clue.compiler.compile(ns, "(fn [b c d] (f 1 2))"), "(function(b, c, d) return clue.namespaces[\"user.ns\"][\"f\"](1, 2) end)")
                end,
                ["with parameters used in the body"] = function()
                    ns = "user.ns"
                    t.assert_equals(clue.compiler.compile(ns, "(fn [a] (a 1 2))"), "(function(a) return a(1, 2) end)")
                    t.assert_equals(clue.compiler.compile(ns, "(fn [f x] (f x y))"), "(function(f, x) return f(x, clue.namespaces[\"user.ns\"][\"y\"]) end)")
                    t.assert_equals(clue.compiler.compile(ns, "(fn [a b c] (a b) [a b c])"), "(function(a, b, c) a(b); return {a, b, c} end)")
                end,
                ["with parameters used in the body of a nested function"] = function()
                    ns = "user.ns"
                    t.assert_equals(clue.compiler.compile(ns, "(fn [a b] (fn [c d] (a b c d)))"), "(function(a, b) return (function(c, d) return a(b, c, d) end) end)")
                end
            },
            ["variable definitions"] = function()
                ns = "user.ns"
                t.assert_equals(clue.compiler.compile(ns, "(def a 10)"), "clue.namespaces[\"user.ns\"][\"a\"] = 10")
                t.assert_equals(clue.compiler.compile(ns, "(def ready? (fn [x] x))"), "clue.namespaces[\"user.ns\"][\"ready?\"] = (function(x) return x end)")
            end,
            ["let definitions"] = {
                ["without constants"] = function()
                    ns = "user.ns"
                    t.assert_equals(clue.compiler.compile(ns, "(let [])"), "clue.nil_")
                    t.assert_equals(clue.compiler.compile(ns, "(let [] (f 1 2))"), "(function() return clue.namespaces[\"user.ns\"][\"f\"](1, 2) end)()")
                    t.assert_equals(clue.compiler.compile(ns, "(let [] (f) (f 1 2))"), "(function() clue.namespaces[\"user.ns\"][\"f\"](); return clue.namespaces[\"user.ns\"][\"f\"](1, 2) end)()")
                end,
                ["with constants"] = function()
                    ns = "user.ns"
                    t.assert_equals(clue.compiler.compile(ns, "(let [a (f)])"), "(function() local a = clue.namespaces[\"user.ns\"][\"f\"](); return clue.nil_ end)()")
                    t.assert_equals(clue.compiler.compile(ns, "(let [a f b 2] (a b))"), "(function() local a = clue.namespaces[\"user.ns\"][\"f\"]; local b = 2; return a(b) end)()")
                    t.assert_equals(clue.compiler.compile(ns, "(let [a 1 b 2] (a) (b))"), "(function() local a = 1; local b = 2; a(); return b() end)()")
                    t.assert_equals(clue.compiler.compile(ns, "(fn [a] (let [b a] (b a)))"), "(function(a) return (function() local b = a; return b(a) end)() end)")
                    t.assert_equals(clue.compiler.compile(ns, "(let [a a a a a b b a] (b a)"), "(function() local a = clue.namespaces[\"user.ns\"][\"a\"]; local a = a; local a = clue.namespaces[\"user.ns\"][\"b\"]; local b = a; return b(a) end)()")
                end
            },
            ["multiple expressions into multiple statements"] = function()
                ns = "some"
                t.assert_equals(clue.compiler.compile(ns, "(def x 9)(f1)"), "clue.namespaces[\"some\"][\"x\"] = 9;\nclue.namespaces[\"some\"][\"f1\"]()")
                t.assert_equals(clue.compiler.compile(ns, "(def x 9)(f1)(f2)"), "clue.namespaces[\"some\"][\"x\"] = 9;\nclue.namespaces[\"some\"][\"f1\"]();\nclue.namespaces[\"some\"][\"f2\"]()")
            end,
            ["namespace definitions"] = function()
                t.assert_equals(clue.compiler.compile("some", "(ns user.core)"), "clue.ns(\"user.core\")")
                t.assert_equals(clue.compiler.compile(
                    "some",
                    "(ns user.core)(f1)(f2)"),
                    "clue.ns(\"user.core\");\nclue.namespaces[\"user.core\"][\"f1\"]();\nclue.namespaces[\"user.core\"][\"f2\"]()")
                t.assert_equals(clue.compiler.compile(
                    "some",
                    "(f1 (ns other))(f2)"),
                    "clue.namespaces[\"some\"][\"f1\"](clue.ns(\"other\"));\nclue.namespaces[\"some\"][\"f2\"]()")
            end
        }
    }
})
