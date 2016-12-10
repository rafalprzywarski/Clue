local M = {}
local S = {}

local function equals(left, right)
    if left == right then
        return true
    end
    if type(left) ~= type(right) or type(left) ~= "table" then
        return false
    end
    for k, v in pairs(left) do
        if not equals(v, right[k]) then return false end
    end
    for k, v in pairs(right) do
        if not equals(left[k], v) then return false end
    end
    return true
end

local function is_array(t)
  local i = 1
  for _ in pairs(t) do
      if t[i] == nil then return false end
      i = i + 1
  end
  return true
end

local function to_string(value)
    if type(value) == "string" then
        return ("%q"):format(value)
    end
    if type(value) ~= "table" then
        return tostring(value)
    end
    local s = "{";
    if is_array(value) then
        for i, v in ipairs(value) do
            if s ~= "{" then s = s .. ", " end
            s = s .. to_string(v)
        end
    else
        for k,v in pairs(value) do
            if s ~= "{" then s = s .. ", " end
            if type(k) ~= "string" or k:match("%W") then
                s = s .. "[" .. to_string(k) .. "]"
            else
                s = s .. k
            end
            s = s .. " = " .. to_string(v)
        end
    end
    return s .. "}"
end

local function make_failure(message)
    return setmetatable({what = "failure", why = message, stacktrace = debug.traceback()}, {__tostring = function(error)
        return error.why .. "\n  " .. error.stacktrace
    end})
end

function M.fail(message)
    error(make_failure(message))
end

local function is_failure(e)
    return type(e) == "table" and e.what == "failure"
end

function M.assert_equals(actual, expected)
    if not equals(expected, actual) then
        M.fail(to_string(actual) .. " expected to equal " .. to_string(expected))
    end
end

function M.assert_equals_any(actual, ...)
    for i=1,select("#", ...) do
        if equals(actual, select(i, ...)) then
            return
        end
    end
    M.fail(to_string(actual) .. " expected to equal any of " .. to_string({...}))
end

function M.assert_true(actual)
    M.assert_equals(actual, true)
end

function M.assert_false(actual)
    M.assert_equals(actual, false)
end

local function new_globals_store()
    local old_S = S
    S = {}
    S.unbind_globals = function() end
    return old_S
end

local function restore_globals(old_S)
    S.unbind_globals()
    S = old_S
end

function run_spec_func(name, spec)
    local ok, error = xpcall(spec, function(error)
        if not is_failure(error) then
            return make_failure("error: " .. to_string(error))
        end
        return error
    end)
    if not ok then
        return {name .. "\n  failure: " .. tostring(error)}
    end
    return {}
end

function run_spec(name, spec, before_each)
    if type(spec) == "function" then
        local globals = new_globals_store()
        before_each()
        local failures = run_spec_func(name, spec)
        restore_globals(globals)
        return failures
    elseif type(spec) == "table" then
        if spec["before each"] then
            local parent_before_each = before_each
            before_each = function() parent_before_each(); spec["before each"]() end
        end
        local failures = {}
        for ctx,s in pairs(spec) do
            if ctx ~= "before each" then
                for _, failure in ipairs(run_spec(ctx, s, before_each)) do
                    table.insert(failures, name .. (failure:sub(1, 1) ~= "." and " " or "") .. failure)
                end
            end
        end
        return failures
    end
    error("invalid spec type: " .. type(spec))
end

function M.describe(name, spec)
    local failures = run_spec(name, spec, function() end)
    for _, failure in ipairs(failures) do
        print(failure)
    end
    if #failures > 0 then
        print(#failures .. " failure" .. (#failures > 1 and "s" or ""))
        os.exit(1)
    else
        print(name .. " ok")
    end
end

local function get_global_value(name)
    return loadstring("return _G." .. name)()
end

local function set_global_value(name, value)
    return loadstring("return function(val) _G." .. name .. " = val end")()(value)
end

function M.bind_global(name, value)
    local unbind_previous_globals = S.unbind_globals
    local old_value = get_global_value(name)
    S.unbind_globals = function()
        set_global_value(name, old_value)
        unbind_previous_globals()
    end
    set_global_value(name, value)
end

function M.save_global(name)
    M.bind_global(name, get_global_value(name))
end

return M
