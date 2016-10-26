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
    end
})
