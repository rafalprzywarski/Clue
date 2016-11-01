local t = require("ut")
require("compiler")


t.describe("clue.core", {
    ["+ should add numbers"] = function()
        t.assert_equals(clue.namespaces["clue.core"]["+"](), 0)
        t.assert_equals(clue.namespaces["clue.core"]["+"](1), 1)
        t.assert_equals(clue.namespaces["clue.core"]["+"](2, 3), 5)
        t.assert_equals(clue.namespaces["clue.core"]["+"](2, 3, 4), 9)
    end,
    ["- should subtract numbers"] = function()
        t.assert_equals(clue.namespaces["clue.core"]["-"](1), -1)
        t.assert_equals(clue.namespaces["clue.core"]["-"](2, 3), -1)
        t.assert_equals(clue.namespaces["clue.core"]["-"](2, 3, 4), -5)
    end,
    ["* should multiply numbers"] = function()
        t.assert_equals(clue.namespaces["clue.core"]["*"](), 1)
        t.assert_equals(clue.namespaces["clue.core"]["*"](1), 1)
        t.assert_equals(clue.namespaces["clue.core"]["*"](2, 3), 6)
        t.assert_equals(clue.namespaces["clue.core"]["*"](2, 3, 4), 24)
    end,
    ["/ should divide numbers"] = function()
        t.assert_equals(clue.namespaces["clue.core"]["/"](6, 2), 3)
        t.assert_equals(clue.namespaces["clue.core"]["/"](24, 3, 4), 2)
    end,
    ["% should compute the modulo operation"] = function()
        t.assert_equals(clue.namespaces["clue.core"]["%"](5, 3), 2)
        t.assert_equals(clue.namespaces["clue.core"]["%"](20, 7, 4), 2)
    end,
    ["= should check equality"] = function()
        t.assert_equals(clue.namespaces["clue.core"]["="](), true)
        t.assert_equals(clue.namespaces["clue.core"]["="](1), true)
        t.assert_equals(clue.namespaces["clue.core"]["="](1, 2), false)
        t.assert_equals(clue.namespaces["clue.core"]["="](2, 2), true)
        t.assert_equals(clue.namespaces["clue.core"]["="](2, 2, 2), true)
        t.assert_equals(clue.namespaces["clue.core"]["="](2, 2, 3), false)
    end,
    ["not= should check inequality"] = function()
        t.assert_equals(clue.namespaces["clue.core"]["not="](), false)
        t.assert_equals(clue.namespaces["clue.core"]["not="](1), false)
        t.assert_equals(clue.namespaces["clue.core"]["not="](1, 2), true)
        t.assert_equals(clue.namespaces["clue.core"]["not="](2, 2), false)
        t.assert_equals(clue.namespaces["clue.core"]["not="](2, 2, 2), false)
        t.assert_equals(clue.namespaces["clue.core"]["not="](2, 2, 3), true)
    end,
    ["pr-str should print"] = {
        ["numbers"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](19), "19")
        end,
        ["boolean values"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](false), "false")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](true), "true")
        end,
        ["nil"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](nil), "nil")
        end,
        ["symbols"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.symbol("hello")), "hello")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.symbol("some.ns", "hello")), "some.ns/hello")
        end,
        ["strings"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"]("test"), "\"test\"")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"]("some\n\tother\\"), "\"some\\n\\tother\\\\\"")
        end,
        ["vectors"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.vector()), "[]")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.vector(1)), "[1]")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.vector(2, 3, 4)), "[2 3 4]")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.vector(clue.vector(2, 3), 4)), "[[2 3] 4]")
        end,
        ["sequences"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.cons()), "()")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.cons(1)), "(1)")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.cons(2, clue.cons(3, clue.vector(4)))), "(2 3 4)")
        end,
        ["lazy sequences"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.lazy_seq(function() end)), "()")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.lazy_seq(function() return clue.cons(2, clue.cons(3, clue.vector(4))) end)), "(2 3 4)")
        end,
        ["lists"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.list()), "()")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.list(1)), "(1)")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.list(clue.list(2), 3, 4)), "((2) 3 4)")
        end,
        ["maps"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.map()), "{}")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.map(1, 2)), "{1 2}")
            t.assert_equals_any(clue.namespaces["clue.core"]["pr-str"](clue.map(1, 2, 3, 4, 5, 6)),
                "{1 2, 3 4, 5 6}", "{1 2, 5 6, 3 4}",
                "{3 4, 1 2, 5 6}", "{3 4, 5 6, 1 2}",
                "{5 6, 1 2, 3 4}", "{5 6, 3 4, 1 2}")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.map(clue.map(1, 2), clue.map(3, 4))), "{{1 2} {3 4}}")
        end,
        ["mixed structures"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.vector(clue.list(clue.map(1, 2), "x"), nil, clue.symbol("N", "s"))), "[({1 2} \"x\") nil N/s]")
        end
    }
})
