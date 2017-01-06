local t = require("ut")
local ct = require("clue_ut")
require("reader")

local function assert_read_error(source, message, row, column)
    local ok, error = pcall(clue.reader.read, source)
    t.assert_false(ok)
    if clue.type(error) ~= clue.ReadError then
        t.fail(clue.pr_str(error))
    end
    t.assert_equals(error.message, message)
    if row then
        t.assert_equals(error.row, row)
    end
    if column then
        t.assert_equals(error.column, column)
    end
end

t.describe("clue.reader", {
    [".read"] = {
        ["should read"] = {
            ["an empty input"] = function()
                ct.assert_equals(clue.reader.read(""), clue.list())
            end,
            ["nil"] = function()
                ct.assert_equals(clue.reader.read("nil"), clue.list(nil))
                ct.assert_equals(clue.reader.read("1 nil nil"), clue.list(1, nil, nil))
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
            ["a symbol with a # suffix"] = function()
                ct.assert_equals(clue.reader.read("hello#"), clue.list(clue.symbol("hello#")))
            end,
            ["a keyword"] = function()
                ct.assert_equals(clue.reader.read(":hello"), clue.list(clue.keyword("hello")))
            end,
            ["a keyword with a namespace"] = function()
                ct.assert_equals(clue.reader.read(":s.ss/hello"), clue.list(clue.keyword("s.ss", "hello")))
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
                end,
                ["with nil"] = function()
                    ct.assert_equals(clue.reader.read("(nil)"), clue.list(clue.list(nil)))
                    ct.assert_equals(clue.reader.read("(nil 1 nil nil)"), clue.list(clue.list(nil, 1, nil, nil)))
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
                end,
                ["with nil"] = function()
                    ct.assert_equals(clue.reader.read("[nil]"), clue.list(clue.list(nil)))
                    ct.assert_equals(clue.reader.read("[nil 1 nil nil]"), clue.list(clue.list(nil, 1, nil, nil)))
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
        },
        ["should fail"] = {
            ["on missing closing brackets"] = function()
                assert_read_error("(", "expected )")
                assert_read_error("[", "expected ]")
                assert_read_error("{", "expected }")
            end,
            ["on mismatched brackets"] = function()
                assert_read_error("(]", "expected ) got ]")
                assert_read_error("(}", "expected ) got }")
                assert_read_error("[)", "expected ] got )")
                assert_read_error("[}", "expected ] got }")
                assert_read_error("{)", "expected } got )")
                assert_read_error("{]", "expected } got ]")
            end
        },
        ["should provide error location"] = function()
            assert_read_error("(", "expected )", 1, 2)
            assert_read_error("        (", "expected )", 1, 10)
            assert_read_error("\n(", "expected )", 2, 2)
            assert_read_error("\n\n(", "expected )", 3, 2)
            assert_read_error("\n \n(", "expected )", 3, 2)
            assert_read_error("\n \n (", "expected )", 3, 3)
            assert_read_error("\n \n  (", "expected )", 3, 4)
            assert_read_error("\n \n  (\n", "expected )", 4, 1)
            assert_read_error("{]", "expected } got ]", 1, 2)
        end,
        ["should ignore comments"] = function()
            ct.assert_equals(clue.reader.read(";"), clue.list())
            ct.assert_equals(clue.reader.read(";nil"), clue.list())
            ct.assert_equals(clue.reader.read("nil;"), clue.list(nil))
            ct.assert_equals(clue.reader.read("; comment\n1 2"), clue.list(1, 2))
            ct.assert_equals(clue.reader.read("; ; comment\n1 2\n3 ;4"), clue.list(1, 2, 3))
        end,
        ["should attach metadata to values"] = {
            ["- map"] = function()
                local form = clue.reader.read("^{:yes 22} [1 2 3]")
                ct.assert_equals(form, clue.list(clue.vector(1, 2, 3)))
                ct.assert_equals(form:first().meta, clue.map(clue.keyword("yes"), 22))
            end,
            ["- keyword"] = function()
                local form = clue.reader.read("^:some [1 2 3]")
                ct.assert_equals(form, clue.list(clue.vector(1, 2, 3)))
                ct.assert_equals(form:first().meta, clue.map(clue.keyword("some"), true))
            end
        },
        ["should merge a sequence of metadata"] = function()
            local form = clue.reader.read("^{:some 22} ^:more ^:and_more ^{:more false} [1 2 3]")
            ct.assert_equals(form, clue.list(clue.vector(1, 2, 3)))
            ct.assert_equals(form:first().meta, clue.map(clue.keyword("some"), 22, clue.keyword("more"), false, clue.keyword("and_more"), true))
        end,
        ["should convert ' to quote"] = function()
            ct.assert_equals(clue.reader.read("\'a"), clue.list(clue.list(clue.symbol("quote"), clue.symbol("a"))))
            ct.assert_equals(clue.reader.read("\'(x y)"), clue.list(clue.list(clue.symbol("quote"), clue.list(clue.symbol("x"), clue.symbol("y")))))
        end,
        ["should convert ` to syntax-quote"] = function()
            ct.assert_equals(clue.reader.read("`a"), clue.list(clue.list(clue.symbol("syntax-quote"), clue.symbol("a"))))
            ct.assert_equals(clue.reader.read("`(x y)"), clue.list(clue.list(clue.symbol("syntax-quote"), clue.list(clue.symbol("x"), clue.symbol("y")))))
        end,
        ["should convert ~ to unquote"] = function()
            ct.assert_equals(clue.reader.read("~a"), clue.list(clue.list(clue.symbol("unquote"), clue.symbol("a"))))
            ct.assert_equals(clue.reader.read("~(x y)"), clue.list(clue.list(clue.symbol("unquote"), clue.list(clue.symbol("x"), clue.symbol("y")))))
        end,
        ["should convert ~@ to unquote-splicing"] = function()
            ct.assert_equals(clue.reader.read("~@a"), clue.list(clue.list(clue.symbol("unquote-splicing"), clue.symbol("a"))))
            ct.assert_equals(clue.reader.read("~@(x y)"), clue.list(clue.list(clue.symbol("unquote-splicing"), clue.list(clue.symbol("x"), clue.symbol("y")))))
        end,
        ["should convert #' to var"] = function()
            ct.assert_equals(clue.reader.read("#'some"), clue.list(clue.list(clue.symbol("var"), clue.symbol("some"))))
            ct.assert_equals(clue.reader.read("#'ns/some"), clue.list(clue.list(clue.symbol("var"), clue.symbol("ns", "some"))))
        end
    }
})
