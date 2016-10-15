require 'core'

clue = clue or {}
clue.reader = clue.reader or {}

function clue.reader.is_space(c)
    return c == " " or c == "," or c == "\t" or c == "\r" or c == "\n"
end

function clue.reader.is_delimiter(c)
    return c == "(" or c == ")" or c == "[" or c == "]"
end

function clue.reader.skip_space(s)
    for i = 1, s:len() do
        if not clue.reader.is_space(s:sub(i, i)) then return s:sub(i) end
    end
    return ""
end

function clue.reader.read_number(s)
    for i = 2, s:len() do
        if not tonumber(s:sub(1, i)) then return clue.number(tonumber(s:sub(1, i - 1))), s:sub(i) end
    end
    return clue.number(tonumber(s)), ""
end

function clue.reader.read_symbol(s)
    for i = 2, s:len() do
        if clue.reader.is_space(s:sub(i, i)) or clue.reader.is_delimiter(s:sub(i, i)) then
            return clue.symbol(s:sub(1, i - 1)), s:sub(i)
        end
    end
    return clue.symbol(s), ""
end

function clue.reader.split_symbol(s)
    local slash = s.name:find("/")
    if not slash then
        return s
    end
    return clue.symbol(s.name:sub(1, slash - 1), s.name:sub(slash + 1))
end

function clue.reader.read_token(source)
    local source = clue.reader.skip_space(source)
    local first = source:sub(1, 1)
    if first == "" then
        return nil, source
    end
    if clue.reader.is_delimiter(first) then
        return {type = "delimiter", value = first}, source:sub(2)
    elseif tonumber(first) then
        return clue.reader.read_number(source)
    else
        symbol, source = clue.reader.read_symbol(source)
        return clue.reader.split_symbol(symbol), source
    end
end

function clue.reader.read_sequence(source, create)
    local l = {}
    local e, nsource = clue.reader.read_expression(source)
    while e do
        table.insert(l, e)
        source = nsource
        e, nsource = clue.reader.read_expression(source)
    end

    local t, source = clue.reader.read_token(source) -- ) or ]
    return create(unpack(l)), source
end

function clue.reader.read_expression(source)
    t, source = clue.reader.read_token(source)
    if t == nil then
        return nil, source
    end
    if t.type == "symbol" or t.type == "number" then
        return t, source
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
    error("unexpected token: " .. t.value)
end

function clue.reader.read(source)
    es = {}
    e, source = clue.reader.read_expression(source)
    while e do
        table.insert(es, e)
        e, source = clue.reader.read_expression(source)
    end
    return es
end
