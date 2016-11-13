require 'core'

clue = clue or {}
clue.reader = clue.reader or {}
clue.reader.nothing = clue.reader.nothing or {"nothing"}
clue.reader.constants = {
    ["true"] = true,
    ["false"] = false
}

clue.reader.COMMENT = ";"
clue.reader.QUOTE = clue.symbol("quote")
clue.reader.SYNTAX_QUOTE = clue.symbol("syntax-quote")
clue.reader.UNQUOTE = clue.symbol("unquote")
clue.reader.UNQUOTE_SPLICING = clue.symbol("unquote-splicing")

function clue.reader.number(value)
    return {type = "number", value = value}
end

function clue.reader.string(value)
    return {type = "string", value = value}
end

function clue.reader.symbol(value)
    return {type = "symbol", value = value}
end

function clue.reader.keyword(value)
    return {type = "keyword", value = value}
end

function clue.reader.is_space(c)
    return c == " " or c == "," or c == "\t" or c == "\r" or c == "\n"
end

function clue.reader.is_delimiter(c)
    return c == "(" or c == ")" or c == "[" or c == "]" or c == "{" or c == "}" or c == "^" or c == "\'" or c == "`" or c == "~"
end

function clue.reader.skip_comment(s)
    if s:sub(1, 1) == clue.reader.COMMENT then
        for i = 1, s:len() do
            if s:sub(i, i) == "\n" then
                return s:sub(i + 1)
            end
        end
        return ""
    end
    return s
end

function clue.reader.skip_space(s)
    for i = 1, s:len() do
        if not clue.reader.is_space(s:sub(i, i)) then return s:sub(i) end
    end
    return ""
end

function clue.reader.skip_space_and_comments(s)
    local skipped = clue.reader.skip_space(clue.reader.skip_comment(s))
    while skipped ~= s and skipped ~= "" do
        s = skipped
        skipped = clue.reader.skip_space(clue.reader.skip_comment(s))
    end
    return skipped
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
        if clue.reader.is_space(s:sub(i, i)) or clue.reader.is_delimiter(s:sub(i, i)) or s:sub(i, i) == clue.reader.COMMENT then
            return clue.reader.symbol(s:sub(1, i - 1)), s:sub(i)
        end
    end
    return clue.reader.symbol(s), ""
end

function clue.reader.read_keyword(s)
    local sym
    sym, s = clue.reader.read_symbol(s:sub(2))
    return clue.reader.keyword(sym.value), s
end

function clue.reader.split_by_slash(s)
    if s == "/" then
        return s
    end
    local slash = s:find("/")
    if not slash then
        return s
    end
    return s:sub(1, slash - 1), s:sub(slash + 1)
end

function clue.reader.split_symbol(s)
    return clue.symbol(clue.reader.split_by_slash(s.value))
end

function clue.reader.split_keyword(s)
    return clue.keyword(clue.reader.split_by_slash(s.value))
end

function clue.reader.read_token(source)
    local source = clue.reader.skip_space_and_comments(source)
    local first = source:sub(1, 1)
    if first == "" then
        return clue.reader.nothing, source
    end
    if clue.reader.is_delimiter(first) then
        if first == "~" and source:sub(2, 2) == "@" then
            first = "~@"
        end
        return {type = "delimiter", value = first}, source:sub(first:len() + 1)
    elseif first == "\"" then
        return clue.reader.read_string(source)
    elseif first == ":" then
        return clue.reader.read_keyword(source)
    elseif tonumber(first) then
        return clue.reader.read_number(source)
    else
        return clue.reader.read_symbol(source)
    end
end

function clue.reader.read_sequence(source, create)
    local l = clue.vector()
    local e, nsource = clue.reader.read_expression(source)
    while e ~= clue.reader.nothing do
        l:append(e)
        source = nsource
        e, nsource = clue.reader.read_expression(source)
    end

    local t, source = clue.reader.read_token(source) -- ) or ]
    return create(l:unpack()), source
end

function clue.reader.read_expression(source)
    local t, source = clue.reader.read_token(source)
    if t == clue.reader.nothing then
        return clue.reader.nothing, source
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
        if t.value == "nil" then
            return nil, source
        end
        return clue.reader.split_symbol(t), source
    end
    if t.type == "keyword" then
        return clue.reader.split_keyword(t), source
    end
    if t.type == "delimiter" and t.value == ")" then
        return clue.reader.nothing
    end
    if t.type == "delimiter" and t.value == "(" then
        return clue.reader.read_sequence(source, clue.list)
    end
    if t.type == "delimiter" and t.value == "]" then
        return clue.reader.nothing
    end
    if t.type == "delimiter" and t.value == "[" then
        return clue.reader.read_sequence(source, clue.vector)
    end
    if t.type == "delimiter" and t.value == "}" then
        return clue.reader.nothing
    end
    if t.type == "delimiter" and t.value == "{" then
        return clue.reader.read_sequence(source, clue.map)
    end
    if t.type == "delimiter" and t.value == "^" then
        local meta, source = clue.reader.read_expression(source)
        local value, source = clue.reader.read_expression(source)
        if clue.type(meta) == clue.Keyword then
            meta = clue.map(meta, true)
        end
        value.meta = meta:merge(value.meta)
        return value, source
    end
    if t.type == "delimiter" and t.value == "\'" then
        local expr, source = clue.reader.read_expression(source)
        return clue.list(clue.reader.QUOTE, expr), source
    end
    if t.type == "delimiter" and t.value == "`" then
        local expr, source = clue.reader.read_expression(source)
        return clue.list(clue.reader.SYNTAX_QUOTE, expr), source
    end
    if t.type == "delimiter" and t.value == "~" then
        local expr, source = clue.reader.read_expression(source)
        return clue.list(clue.reader.UNQUOTE, expr), source
    end
    if t.type == "delimiter" and t.value == "~@" then
        local expr, source = clue.reader.read_expression(source)
        return clue.list(clue.reader.UNQUOTE_SPLICING, expr), source
    end
    error("unexpected token: " .. t.value)
end

function clue.reader.read(source)
    local es = clue.vector()
    local e, source = clue.reader.read_expression(source)
    while e ~= clue.reader.nothing do
        es:append(e)
        e, source = clue.reader.read_expression(source)
    end
    return es
end
