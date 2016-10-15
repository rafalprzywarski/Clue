local t = require("ut")
require("reader")

t.describe("clue.reader", {
    [".read"] = {
        ["should read"] = {
            ["an empty string"] = function()
                t.assert_equals(clue.reader.read(""), {})
            end,
            ["nil"] = function()
                t.assert_equals(clue.reader.read("nil"), {clue.nil_})
                t.assert_equals(clue.reader.read("1 nil nil"), {1, clue.nil_, clue.nil_})
            end,
            ["numbers"] = function()
                t.assert_equals(clue.reader.read("10"), {10})
                t.assert_equals(clue.reader.read(" 1 50 3789 "), {1, 50, 3789})
            end,
            ["a symbol"] = function()
                t.assert_equals(clue.reader.read("hello"), {clue.symbol("hello")})
            end,
            ["a symbol with a namespace"] = function()
                t.assert_equals(clue.reader.read("s.ss/hello"), {clue.symbol("s.ss", "hello")})
            end,
            ["a list"] = {
                ["empty"] = function()
                    t.assert_equals(clue.reader.read("()"), {clue.list()})
                end,
                ["of numbers"] = function()
                    t.assert_equals(clue.reader.read("(1)"), {clue.list(1)})
                    t.assert_equals(clue.reader.read("(1 2)"), {clue.list(1, 2)})
                    t.assert_equals(clue.reader.read("(1 2 3)"), {clue.list(1, 2, 3)})
                end,
                ["of vectors"] = function()
                    t.assert_equals(clue.reader.read("([] [1] [2 3])"), {clue.list(clue.vector(), clue.vector(1), clue.vector(2, 3))})
                end
            },
            ["a vector"] = {
                ["empty"] = function()
                    t.assert_equals(clue.reader.read("[]"), {clue.vector()})
                end,
                ["of numbers"] = function()
                    t.assert_equals(clue.reader.read("[1]"), {clue.vector(1)})
                    t.assert_equals(clue.reader.read("[1 2]"), {clue.vector(1, 2)})
                    t.assert_equals(clue.reader.read("[1 2 3]"), {clue.vector(1, 2, 3)})
                end,
                ["of lists"] = function()
                    t.assert_equals(clue.reader.read("[() (1) (2 3)]"), {clue.vector(clue.list(), clue.list(1), clue.list(2, 3))})
                end
            },
            ["lists"] = function()
                t.assert_equals(clue.reader.read("(1) (2 3) (4)"), {clue.list(1), clue.list(2, 3), clue.list(4)})
            end,
            ["nested lists"] = function()
                t.assert_equals(clue.reader.read("(())"), {clue.list(clue.list())})
                t.assert_equals(clue.reader.read("(1 (2))"), {clue.list(1, clue.list(2))})
                t.assert_equals(clue.reader.read("((1) 2)"), {clue.list(clue.list(1), 2)})
                t.assert_equals(clue.reader.read("(((1) 2) 3)"), {clue.list(clue.list(clue.list(1), 2), 3)})
            end
        }
    }
})
