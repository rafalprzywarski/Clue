require 'core'

clue = clue or {}
clue.reader = clue.reader or {}
clue.reader.constants = {
    ["nil"] = clue.nil_,
    ["true"] = true,
    ["false"] = false
}

function clue.reader.number(value)
    return {type = "number", value = value}
end

function clue.reader.string(value)
    return {type = "string", value = value}
end

function clue.reader.symbol(value)
    return {type = "symbol", value = value}
end

function clue.reader.is_space(c)
    return c == " " or c == "," or c == "\t" or c == "\r" or c == "\n"
end

function clue.reader.is_delimiter(c)
    return c == "(" or c == ")" or c == "[" or c == "]" or c == "{" or c == "}"
end

function clue.reader.skip_space(s)
    for i = 1, s:len() do
        if not clue.reader.is_space(s:sub(i, i)) then return s:sub(i) end
    end
    return ""
end

function clue.reader.read_string(s)
    for i = 2, s:len() do
        if s:sub(i, i) == "\"" then return clue.reader.string(s:sub(2, i - 1)), s:sub(i + 1) end
    end
    error("missing closing \"")
end

function clue.reader.read_number(s)
    for i = 2, s:len() do
        if not tonumber(s:sub(1, i)) then return clue.reader.number(tonumber(s:sub(1, i - 1))), s:sub(i) end
    end
    return clue.reader.number(tonumber(s)), ""
end

function clue.reader.read_symbol(s)
    for i = 2, s:len() do
        if clue.reader.is_space(s:sub(i, i)) or clue.reader.is_delimiter(s:sub(i, i)) then
            return clue.reader.symbol(s:sub(1, i - 1)), s:sub(i)
        end
    end
    return clue.reader.symbol(s), ""
end

function clue.reader.split_symbol(s)
    if s.value == "/" then
        return clue.symbol(s.value)
    end
    local slash = s.value:find("/")
    if not slash then
        return clue.symbol(s.value)
    end
    return clue.symbol(s.value:sub(1, slash - 1), s.value:sub(slash + 1))
end

function clue.reader.read_token(source)
    local source = clue.reader.skip_space(source)
    local first = source:sub(1, 1)
    if first == "" then
        return nil, source
    end
    if clue.reader.is_delimiter(first) then
        return {type = "delimiter", value = first}, source:sub(2)
    elseif first == "\"" then
        return clue.reader.read_string(source)
    elseif tonumber(first) then
        return clue.reader.read_number(source)
    else
        return clue.reader.read_symbol(source)
    end
end

function clue.reader.read_sequence(source, create)
    local l = {}
    local e, nsource = clue.reader.read_expression(source)
    while e ~= nil do
        table.insert(l, e)
        source = nsource
        e, nsource = clue.reader.read_expression(source)
    end

    local t, source = clue.reader.read_token(source) -- ) or ]
    return create(unpack(l)), source
end

function clue.reader.read_expression(source)
    local t, source = clue.reader.read_token(source)
    if t == nil then
        return nil, source
    end
    if t.type == "number" then
        return t.value, source
    end
    if t.type == "string" then
        return t.value, source
    end
    if t.type == "symbol" then
        if clue.reader.constants[t.value] ~= nil then
            return clue.reader.constants[t.value], source
        end
        return clue.reader.split_symbol(t), source
    end
    if t.type == "delimiter" and t.value == ")" then
        return nil
    end
    if t.type == "delimiter" and t.value == "(" then
        return clue.reader.read_sequence(source, clue.list)
    end
    if t.type == "delimiter" and t.value == "]" then
        return nil
    end
    if t.type == "delimiter" and t.value == "[" then
        return clue.reader.read_sequence(source, clue.vector)
    end
    if t.type == "delimiter" and t.value == "}" then
        return nil
    end
    if t.type == "delimiter" and t.value == "{" then
        return clue.reader.read_sequence(source, clue.map)
    end
    error("unexpected token: " .. t.value)
end

function clue.reader.read(source)
    local es = clue.list()
    local e, source = clue.reader.read_expression(source)
    while e ~= nil do
        es:append(e)
        e, source = clue.reader.read_expression(source)
    end
    return es
end
