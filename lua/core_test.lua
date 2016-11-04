local t = require("ut")
local ct = require("clue_ut")
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
    ["= should check equality of"] = {
        ["numbers"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["="](), true)
            t.assert_equals(clue.namespaces["clue.core"]["="](1), true)
            t.assert_equals(clue.namespaces["clue.core"]["="](1, 2), false)
            t.assert_equals(clue.namespaces["clue.core"]["="](2, 2), true)
            t.assert_equals(clue.namespaces["clue.core"]["="](2, 2, 2), true)
            t.assert_equals(clue.namespaces["clue.core"]["="](2, 2, 3), false)
        end,
        ["strings"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["="]("abc", "bce"), false)
            t.assert_equals(clue.namespaces["clue.core"]["="]("abc", "abc"), true)
        end,
        ["symbols"] = function()
            t.assert_true(clue.namespaces["clue.core"]["="](clue.symbol("sym"), clue.symbol("sym")))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.symbol("sym"), clue.symbol("X")))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.symbol("sym"), clue.symbol("sym"), clue.symbol("X")))
            t.assert_true(clue.namespaces["clue.core"]["="](clue.symbol("ns", "sym"), clue.symbol("ns", "sym")))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.symbol("ns", "sym"), clue.symbol("X", "sym")))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.symbol("ns", "sym"), clue.symbol("sym")))
        end,
        ["symbols against other types (false)"] = function()
            t.assert_false(clue.namespaces["clue.core"]["="](clue.symbol("sym"), clue.list()))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.list(), clue.symbol("sym")))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.symbol("sym"), "sym"))
            t.assert_false(clue.namespaces["clue.core"]["="]("sym", clue.symbol("sym")))
        end,
        ["keywords"] = function()
            t.assert_true(clue.namespaces["clue.core"]["="](clue.keyword("sym"), clue.keyword("sym")))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.keyword("sym"), clue.keyword("X")))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.keyword("sym"), clue.keyword("sym"), clue.keyword("X")))
            t.assert_true(clue.namespaces["clue.core"]["="](clue.keyword("ns", "sym"), clue.keyword("ns", "sym")))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.keyword("ns", "sym"), clue.keyword("X", "sym")))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.keyword("ns", "sym"), clue.keyword("sym")))
        end,
        ["keywords against other types (false)"] = function()
            t.assert_false(clue.namespaces["clue.core"]["="](clue.keyword("sym"), clue.list()))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.keyword("sym"), clue.symbol("sym")))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.list(), clue.keyword("sym")))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.keyword("sym"), "sym"))
            t.assert_false(clue.namespaces["clue.core"]["="]("sym", clue.keyword("sym")))
        end,
        ["sequences"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.list(), clue.list()), true)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.list(1), clue.list(1)), true)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.list(1), clue.list()), false)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.list(), clue.list(2)), false)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.list("a", "b", "c"), clue.list("a", "b", "c")), true)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.list("a", "b", "c"), clue.list("a", "b", "X")), false)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.list("a", "b", "c"), clue.list("a", "X", "c")), false)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.list("a", "b", "c"), clue.list("X", "b", "c")), false)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.list("a", "b", "c"), clue.list("a", "b")), false)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.list("a", "b", "c"), clue.vector("a", "b", "c")), true)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.cons("a", clue.cons("b", clue.list("c"))), clue.vector("a", "b", "c")), true)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.list(clue.list("a", "b"), "c"), clue.list(clue.list("a", "b"), "c")), true)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.list(clue.list("a", "X"), "c"), clue.list(clue.list("a", "b"), "c")), false)
        end,
        ["sequences against other types (false)"] = function()
            t.assert_false(clue.namespaces["clue.core"]["="](clue.list(), nil))
            t.assert_false(clue.namespaces["clue.core"]["="](nil, clue.list()))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.list(1), "x"))
            t.assert_false(clue.namespaces["clue.core"]["="](1, clue.list(1)))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.list(1), 1))
            t.assert_false(clue.namespaces["clue.core"]["="](1, clue.list(1)))
        end,
        ["maps"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.map(), clue.map()), true)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.map("a", 1), clue.map("a", 1)), true)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.map("a", 1), clue.map("b", 1)), false)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.map("a", 1), clue.map("a", 2)), false)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.map("a", 1, "b", 2), clue.map("a", 1, "b", 2)), true)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.map("a", 1, "b", 2), clue.map("a", "X", "b", 2)), false)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.map("a", 1, "b", 2), clue.map("a", 1, "b", "X")), false)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.map("a", 1, "b", 2), clue.map("a", 1, "X", 2)), false)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.map("a", clue.vector(1, 2), "b", 2), clue.map("a", clue.vector(1, 2), "b", 2)), true)
            t.assert_equals(clue.namespaces["clue.core"]["="](clue.map("a", clue.vector(1, 2), "b", 2), clue.map("a", clue.vector(1, "X"), "b", 2)), false)
        end,
        ["maps against other types (false)"] = function()
            t.assert_false(clue.namespaces["clue.core"]["="](clue.map(), nil))
            t.assert_false(clue.namespaces["clue.core"]["="](nil, clue.map()))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.map(), "xxx"))
            t.assert_false(clue.namespaces["clue.core"]["="]("xxx", clue.map()))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.map(), 10))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.map(), clue.list()))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.list(), clue.map()))
        end,
        ["tables"] = function()
            t.assert_true(clue.namespaces["clue.core"]["="]({}, {}))
            t.assert_true(clue.namespaces["clue.core"]["="]({a = 1, b = 2}, {a = 1, b = 2}))
            t.assert_false(clue.namespaces["clue.core"]["="]({a = 1, b = 1}, {a = 1, b = 2}))
            t.assert_false(clue.namespaces["clue.core"]["="]({a = 1}, {a = 1, b = 2}))
            t.assert_false(clue.namespaces["clue.core"]["="]({a = 1}, {a = 1, b = 2}))
            t.assert_false(clue.namespaces["clue.core"]["="]({a = 1, b = 2}, {a = 1}))
            t.assert_false(clue.namespaces["clue.core"]["="]({a = 1, b = 2}, {a = 1, b = 2}, {a = 1}))
            t.assert_true(clue.namespaces["clue.core"]["="]({a = clue.list(1, 2)}, {a = clue.list(1, 2)}))
            t.assert_false(clue.namespaces["clue.core"]["="]({a = clue.list(1, 2)}, {a = clue.list(1, 1)}))
        end,
        ["tables against other type (false)"] = function()
            t.assert_false(clue.namespaces["clue.core"]["="]({}, clue.list()))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.list(), {}))
            t.assert_false(clue.namespaces["clue.core"]["="]({}, clue.list(1, 2)))
            t.assert_false(clue.namespaces["clue.core"]["="](clue.list(1, 2), {}))
            t.assert_false(clue.namespaces["clue.core"]["="]("x", {}))
            t.assert_false(clue.namespaces["clue.core"]["="]({}, "x"))
            t.assert_false(clue.namespaces["clue.core"]["="]({}, nil))
            t.assert_false(clue.namespaces["clue.core"]["="](nil, {}))
        end
    },
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
        ["keywords"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.keyword("hello")), ":hello")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.keyword("some.ns", "hello")), ":some.ns/hello")
        end,
        ["strings"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"]("test"), "\"test\"")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"]("some\n\tother\\"), "\"some\\n\\tother\\\\\"")
        end,
        ["vectors"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.vector()), "[]")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.vector(nil)), "[nil]")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.vector(1)), "[1]")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.vector(2, 3, 4)), "[2 3 4]")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.vector(2, 3, nil, 4, nil)), "[2 3 nil 4 nil]")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.vector(clue.vector(2, 3), 4)), "[[2 3] 4]")
        end,
        ["sequences"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"](clue.cons()), "(nil)")
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
        end,
        ["tables"] = function()
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"]({}), "(lua-table)")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"]({x = 9}), "(lua-table \"x\" 9)")
            t.assert_equals_any(clue.namespaces["clue.core"]["pr-str"]({[1] = 2, [3] = 4, [5] = 6}),
                "(lua-table 1 2 3 4 5 6)", "(lua-table 1 2 5 6 3 4)",
                "(lua-table 3 4 1 2 5 6)", "(lua-table 3 4 5 6 1 2)",
                "(lua-table 5 6 1 2 3 4)", "(lua-table 5 6 3 4 1 2)")
            t.assert_equals(clue.namespaces["clue.core"]["pr-str"]({x = clue.vector(1, 2)}), "(lua-table \"x\" [1 2])")
        end
    },
    ["lazy-seq should"] = {
        ["be an empty sequence when a given function returns nil"] = function()
            local seq = clue.lazy_seq(function() return nil end)
            ct.assert_equals(seq:first(), nil)
            ct.assert_equals(seq:next(), nil)
            t.assert_true(seq:empty())
        end,
        ["forward the methods to the sequence returned by a given function"] = function()
            local seq = function() return clue.lazy_seq(function() return {
                first = function() return 1 end,
                next = function() return 2 end,
                empty = function() return 3 end
            } end) end
            ct.assert_equals(seq():first(), 1)
            ct.assert_equals(seq():next(), 2)
            ct.assert_equals(seq():empty(), 3)
        end,
        ["not evaluate a given function before it is needed"] = function()
            local called = false
            clue.lazy_seq(function() called = true; return nil end)
            t.assert_false(called)
        end,
        ["evaluate a given function once"] = function()
            local called = false
            local n = 1
            local call = function() called = true; n = n + 1; print("called " .. n) end
            local seq = function() return clue.lazy_seq(function() called = true; return nil end) end
            local s = seq()
            s:first()
            called = false

            s:first()
            s:next()
            s:empty()
            t.assert_false(called)

            local s = seq()
            s:next()
            called = false

            s:first()
            s:next()
            s:empty()
            t.assert_false(called)

            local s = seq()
            s:empty()
            called = false

            s:first()
            s:next()
            s:empty()
            t.assert_false(called)
        end
    },
    ["keywords should be interned"] = function()
        local ns_k1a = clue.keyword("ns", "k1")
        local ns_k1b = clue.keyword("ns", "k1")
        local ns_k2 = clue.keyword("ns", "k2")
        local k1a = clue.keyword("k1")
        local k1b = clue.keyword("k1")
        local k2 = clue.keyword("k2")

        t.assert_true(ns_k1a == ns_k1b)
        t.assert_false(ns_k1a == ns_k2)
        t.assert_true(k1a == k1b)
        t.assert_false(k1a == k2)
    end
})
