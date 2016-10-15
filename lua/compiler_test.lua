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
                ["with parameters"] = function()
                    t.assert_equals(clue.compiler.compile("(fn [a] (f 1 2))"), "function(a) return clue._ns_[\"f\"](1, 2) end")
                    t.assert_equals(clue.compiler.compile("(fn [b c d] (f 1 2))"), "function(b, c, d) return clue._ns_[\"f\"](1, 2) end")
                end
            }
        }
    }
})
