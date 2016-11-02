local t = require("ut")
local ct = require("clue_ut")
require("reader")

t.describe("clue.reader", {
    [".read"] = {
        ["should read"] = {
            ["an empty input"] = function()
                ct.assert_equals(clue.reader.read(""), clue.list())
            end,
            ["nil"] = function()
                ct.assert_equals(clue.reader.read("nil"), clue.list(clue.nil_))
                ct.assert_equals(clue.reader.read("1 nil nil"), clue.list(1, clue.nil_, clue.nil_))
            end,
            ["boolean constants"] = function()
                ct.assert_equals(clue.reader.read("true false"), clue.list(true, false))
                ct.assert_equals(clue.reader.read("[true false]"), clue.list(clue.vector(true, false)))
            end,
            ["numbers"] = function()
                ct.assert_equals(clue.reader.read("10"), clue.list(10))
                ct.assert_equals(clue.reader.read(" 1 50 3789 "), clue.list(1, 50, 3789))
            end,
            ["string"] = function()
                ct.assert_equals(clue.reader.read("\"\""), clue.list(""))
                ct.assert_equals(clue.reader.read("\"sonia\""), clue.list("sonia"))
            end,
            ["a symbol"] = function()
                ct.assert_equals(clue.reader.read("hello"), clue.list(clue.symbol("hello")))
            end,
            ["a symbol with a namespace"] = function()
                ct.assert_equals(clue.reader.read("s.ss/hello"), clue.list(clue.symbol("s.ss", "hello")))
            end,
            ["a list"] = {
                ["empty"] = function()
                    ct.assert_equals(clue.reader.read("()"), clue.list(clue.list()))
                end,
                ["of numbers"] = function()
                    ct.assert_equals(clue.reader.read("(1)"), clue.list(clue.list(1)))
                    ct.assert_equals(clue.reader.read("(1 2)"), clue.list(clue.list(1, 2)))
                    ct.assert_equals(clue.reader.read("(1 2 3)"), clue.list(clue.list(1, 2, 3)))
                end,
                ["of vectors"] = function()
                    ct.assert_equals(clue.reader.read("([] [1] [2 3])"), clue.list(clue.list(clue.vector(), clue.vector(1), clue.vector(2, 3))))
                end
            },
            ["a vector"] = {
                ["empty"] = function()
                    ct.assert_equals(clue.reader.read("[]"), clue.list(clue.vector()))
                end,
                ["of numbers"] = function()
                    ct.assert_equals(clue.reader.read("[1]"), clue.list(clue.vector(1)))
                    ct.assert_equals(clue.reader.read("[1 2]"), clue.list(clue.vector(1, 2)))
                    ct.assert_equals(clue.reader.read("[1 2 3]"), clue.list(clue.vector(1, 2, 3)))
                end,
                ["of lists"] = function()
                    ct.assert_equals(clue.reader.read("[() (1) (2 3)]"), clue.list(clue.vector(clue.list(), clue.list(1), clue.list(2, 3))))
                end
            },
            ["a map"] = {
                ["empty"] = function()
                    ct.assert_equals(clue.reader.read("{}"), clue.list(clue.map()))
                end,
                ["of strings and numbers"] = function()
                    ct.assert_equals(clue.reader.read("{1 2}"), clue.list(clue.map(1, 2)))
                    ct.assert_equals(clue.reader.read("{1 2 \"x\" \"y\" 3 [1 2]}"), clue.list(clue.map(1, 2, "x", "y", 3, clue.vector(1, 2))))
                end
            },
            ["lists"] = function()
                ct.assert_equals(clue.reader.read("(1) (2 3) (4)"), clue.list(clue.list(1), clue.list(2, 3), clue.list(4)))
            end,
            ["nested lists"] = function()
                ct.assert_equals(clue.reader.read("(())"), clue.list(clue.list(clue.list())))
                ct.assert_equals(clue.reader.read("(1 (2))"), clue.list(clue.list(1, clue.list(2))))
                ct.assert_equals(clue.reader.read("((1) 2)"), clue.list(clue.list(clue.list(1), 2)))
                ct.assert_equals(clue.reader.read("(((1) 2) 3)"), clue.list(clue.list(clue.list(clue.list(1), 2), 3)))
            end,
            ["operators"] = function()
                ct.assert_equals(clue.reader.read("+"), clue.list(clue.symbol("+")))
                ct.assert_equals(clue.reader.read("-"), clue.list(clue.symbol("-")))
                ct.assert_equals(clue.reader.read("*"), clue.list(clue.symbol("*")))
                ct.assert_equals(clue.reader.read("/"), clue.list(clue.symbol("/")))
                ct.assert_equals(clue.reader.read("%"), clue.list(clue.symbol("%")))
            end
        }
    }
})
