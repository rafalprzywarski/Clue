local M = {}
local ut = require("ut")

function M.assert_equals(actual, expected)
    if not clue.equals(expected, actual) then
        ut.fail(clue.pr_str(actual) .. " expected to equal " .. clue.pr_str(expected))
    end
end

return M
