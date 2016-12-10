local t = require("ut")

before_seq = ""

t.describe("ut before each", {
    ["before each"] = function()
        t.save_global("before_seq")
        before_seq = before_seq .. "1"
    end,
    ["one"] = function()
        t.assert_equals(before_seq, "1")
    end,
    ["next"] = {
        ["before each"] = function()
            before_seq = before_seq .. "2"
        end,
        ["two"] = function()
            t.assert_equals(before_seq, "12")
        end,
        ["next"] = {
            ["before each"] = function()
                before_seq = before_seq .. "3"
            end,
            ["three"] = function()
                t.assert_equals(before_seq, "123")
            end,
        }
    }
})
