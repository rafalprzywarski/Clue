local t = require("ut")
require("compiler")

t.describe("clue.compiler", {
    [".compile"] = {
        ["should translate"] = {
            ["lists into function calls"] = function()
                t.assert_equals(clue.compiler.compile("(hi)"), "clue._ns_[\"hi\"]()")
                t.assert_equals(clue.compiler.compile("(hi 1 2 3)"), "clue._ns_[\"hi\"](1, 2, 3)")
                t.assert_equals(clue.compiler.compile("(my.ns/ff)"), "clue.var(\"my.ns\", \"ff\")()")
                t.assert_equals(clue.compiler.compile("(my.ns/ff 1 2 3)"), "clue.var(\"my.ns\", \"ff\")(1, 2, 3)")
                t.assert_equals(clue.compiler.compile("(my.ns/ff x s/y)"), "clue.var(\"my.ns\", \"ff\")(clue._ns_[\"x\"], clue.var(\"s\", \"y\"))")
            end,
            ["nested list into nested function calls"] = function()
                t.assert_equals(clue.compiler.compile("(hi (there))"), "clue._ns_[\"hi\"](clue._ns_[\"there\"]())")
            end,
            ["symbols into vars"] = function()
                t.assert_equals(clue.compiler.compile("an-example"), "clue._ns_[\"an-example\"]")
                t.assert_equals(clue.compiler.compile("my.ns.example/an-example"), "clue.var(\"my.ns.example\", \"an-example\")")
            end,
            ["vectors into arrays"] = function()
                t.assert_equals(clue.compiler.compile("[]"), "{}")
                t.assert_equals(clue.compiler.compile("[1 2 3 4]"), "{1, 2, 3, 4}")
                t.assert_equals(clue.compiler.compile("[(hello) s/x]"), "{clue._ns_[\"hello\"](), clue.var(\"s\", \"x\")}")
            end,
            ["function definitions"] = {
                ["with no parameters"] = function()
                    t.assert_equals(clue.compiler.compile("(fn [] (f 1 2))"), "function() return clue._ns_[\"f\"](1, 2) end")
                    t.assert_equals(clue.compiler.compile("(fn [] (f 1) (g 2) (h 3))"), "function() clue._ns_[\"f\"](1); clue._ns_[\"g\"](2); return clue._ns_[\"h\"](3) end")
                end,
                ["with declared parameters"] = function()
                    t.assert_equals(clue.compiler.compile("(fn [a] (f 1 2))"), "function(a) return clue._ns_[\"f\"](1, 2) end")
                    t.assert_equals(clue.compiler.compile("(fn [b c d] (f 1 2))"), "function(b, c, d) return clue._ns_[\"f\"](1, 2) end")
                end,
                ["with parameters used in the body"] = function()
                    t.assert_equals(clue.compiler.compile("(fn [a] (a 1 2))"), "function(a) return a(1, 2) end")
                    t.assert_equals(clue.compiler.compile("(fn [f x] (f x y))"), "function(f, x) return f(x, clue._ns_[\"y\"]) end")
                    t.assert_equals(clue.compiler.compile("(fn [a b c] (a b) [a b c])"), "function(a, b, c) a(b); return {a, b, c} end")
                end,
                ["with parameters used in the body of a nested function"] = function()
                    t.assert_equals(clue.compiler.compile("(fn [a b] (fn [c d] (a b c d)))"), "function(a, b) return function(c, d) return a(b, c, d) end end")
                end
            },
            ["variable definitions"] = function()
                t.assert_equals(clue.compiler.compile("(def a 10)"), "clue._ns_[\"a\"] = 10")
                t.assert_equals(clue.compiler.compile("(def ready? (fn [x] x))"), "clue._ns_[\"ready?\"] = function(x) return x end")
            end,
            ["let definitions"] = {
                ["without constants"] = function()
                    t.assert_equals(clue.compiler.compile("(let [])"), "clue.nil_")
                    t.assert_equals(clue.compiler.compile("(let [] (f 1 2))"), "(function() return clue._ns_[\"f\"](1, 2) end)()")
                    t.assert_equals(clue.compiler.compile("(let [] (f) (f 1 2))"), "(function() clue._ns_[\"f\"](); return clue._ns_[\"f\"](1, 2) end)()")
                end,
                ["with constants"] = function()
                    t.assert_equals(clue.compiler.compile("(let [a (f)])"), "(function() local a = clue._ns_[\"f\"](); return clue.nil_ end)()")
                    t.assert_equals(clue.compiler.compile("(let [a f b 2] (a b))"), "(function() local a = clue._ns_[\"f\"]; local b = 2; return a(b) end)()")
                    t.assert_equals(clue.compiler.compile("(let [a 1 b 2] (a) (b))"), "(function() local a = 1; local b = 2; a(); return b() end)()")
                    t.assert_equals(clue.compiler.compile("(fn [a] (let [b a] (b a)))"), "function(a) return (function() local b = a; return b(a) end)() end")
                    t.assert_equals(clue.compiler.compile("(let [a a a a a b b a] (b a)"), "(function() local a = clue._ns_[\"a\"]; local a = a; local a = clue._ns_[\"b\"]; local b = a; return b(a) end)()")
                end
            }
        }
    }
})
