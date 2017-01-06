require 'core'

clue = clue or {}

clue.class("ReadError")

function clue.ReadError:init(message, file, row, column)
    self.message = message
    self.row = row
    self.column = column
    self.file = file
end

function clue.ReadError:__tostring()
    local prefix = ""
    if self.file then
        prefix = self.file .. ":"
    end
    if self.row then
        prefix = prefix .. self.row .. ":"
        if self.column then
            prefix = prefix .. self.column .. ":"
        end
    end
    if prefix ~= "" then
        prefix = prefix .. " "
    end
    return prefix .. self.message
end

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
clue.reader.VAR = clue.symbol("var")

function clue.reader.read_error(msg, source)
    local text = source("text")
    local pos = source("pos")
    local column, row
    if text then
        local part = text:sub(1, pos)
        local _
        _, row = part:gsub("\n", "\n")
        column = part:reverse():find("\n") or pos
        row = row + 1
    end
    error(clue.ReadError.new(msg, clue._file_, row, column))
 end

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

clue.reader.delimiters = clue.set("(", ")", "[", "]", "{", "}", "^", "\'", "`", "~")

function clue.reader.is_delimiter(c)
    return clue.reader.delimiters:at(c) ~= nil
end

function clue.reader.skip_comment(s)
    local text = s("text")
    local pos = s("pos")
    if text:sub(pos, pos) == clue.reader.COMMENT then
        for i = pos, text:len() do
            if text:sub(i, i) == "\n" then
                return s:assoc("pos", i + 1)
            end
        end
        return s:assoc("pos", text:len() + 1)
    end
    return s
end

function clue.reader.skip_space(s)
    local text = s("text")
    local pos = s("pos")
    for i = pos, text:len() do
        if not clue.reader.is_space(text:sub(i, i)) then
            if i == pos then
                return s
            end
            return s:assoc("pos", i)
        end
    end
    return s:assoc("pos", text:len() + 1)
end

function clue.reader.skip_space_and_comments(s)
    local skipped = clue.reader.skip_space(clue.reader.skip_comment(s))
    while skipped ~= s and skipped("pos") <= skipped("text"):len() do
        s = skipped
        skipped = clue.reader.skip_space(clue.reader.skip_comment(s))
    end
    return skipped
end

function clue.reader.read_string(s)
    local text = s("text")
    local pos = s("pos")
    for i = pos + 1, s("text"):len() do
        if text:sub(i, i) == "\"" then
            return clue.reader.string(text:sub(pos + 1, i - 1)), s:assoc("pos", i + 1)
        end
    end
    clue.reader.read_error("missing closing \"", s:assoc("pos", text:len() + 1))
end

function clue.reader.read_number(s)
    local text = s("text")
    local pos = s("pos")
    local i = pos + 1
    while i <= text:len() and tonumber(text:sub(pos, i)) do
        i = i + 1
    end
    return clue.reader.number(tonumber(text:sub(pos, i - 1))), s:assoc("pos", i)
end

function clue.reader.read_symbol(s)
    local text = s("text")
    local pos = s("pos")
    for i = pos + 1, text:len() do
        if clue.reader.is_space(text:sub(i, i)) or clue.reader.is_delimiter(text:sub(i, i)) or text:sub(i, i) == clue.reader.COMMENT then
            return clue.reader.symbol(text:sub(pos, i - 1)), s:assoc("pos", i)
        end
    end
    return clue.reader.symbol(text:sub(pos)), s:assoc("pos", text:len() + 1)
end

function clue.reader.read_keyword(s)
    local sym
    sym, s = clue.reader.read_symbol(s:assoc("pos", s("pos") + 1))
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
    local text = source("text")
    local pos = source("pos")
    local first = text:sub(pos, pos)
    if first == "" then
        return clue.reader.nothing, source
    end
    if clue.reader.is_delimiter(first) or first == "#" then
        second = text:sub(pos + 1, pos + 1)
        if first == "~" and second == "@" then
            first = "~@"
        elseif first == "#" and second == "'" then
            first = "#'"
        end
        return {type = "delimiter", value = first}, source:assoc("pos", pos + first:len())
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

function clue.reader.read_sequence(source, create, closing)
    local l = clue.vector()
    local e, nsource = clue.reader.read_expression(source)
    while e ~= clue.reader.nothing do
        l:append(e)
        source = nsource
        e, nsource = clue.reader.read_expression(source)
    end

    local t, tsource = clue.reader.read_token(source)
    if t == clue.reader.nothing then
        clue.reader.read_error("expected " .. closing, tsource)
    end
    if t.value ~= closing then
        clue.reader.read_error("expected " .. closing .. " got " .. tostring(t.value), source)
    end
    return create(l:unpack()), tsource
end

function clue.reader.read_expression(source)
    local t, tsource = clue.reader.read_token(source)
    if t == clue.reader.nothing then
        return clue.reader.nothing, tsource
    end
    if t.type == "number" then
        return t.value, tsource
    end
    if t.type == "string" then
        return t.value, tsource
    end
    if t.type == "symbol" then
        if clue.reader.constants[t.value] ~= nil then
            return clue.reader.constants[t.value], tsource
        end
        if t.value == "nil" then
            return nil, tsource
        end
        return clue.reader.split_symbol(t), tsource
    end
    if t.type == "keyword" then
        return clue.reader.split_keyword(t), tsource
    end
    if t.type == "delimiter" and t.value == ")" then
        return clue.reader.nothing, tsource
    end
    if t.type == "delimiter" and t.value == "(" then
        return clue.reader.read_sequence(tsource, clue.list, ")")
    end
    if t.type == "delimiter" and t.value == "]" then
        return clue.reader.nothing, tsource
    end
    if t.type == "delimiter" and t.value == "[" then
        return clue.reader.read_sequence(tsource, clue.vector, "]")
    end
    if t.type == "delimiter" and t.value == "}" then
        return clue.reader.nothing, tsource
    end
    if t.type == "delimiter" and t.value == "{" then
        return clue.reader.read_sequence(tsource, clue.map, "}")
    end
    if t.type == "delimiter" and t.value == "^" then
        local meta, source = clue.reader.read_expression(tsource)
        local value, source = clue.reader.read_expression(source)
        if clue.type(meta) == clue.Keyword then
            meta = clue.map(meta, true)
        end
        value.meta = meta:merge(value.meta)
        return value, source
    end
    if t.type == "delimiter" and t.value == "\'" then
        local expr, source = clue.reader.read_expression(tsource)
        return clue.list(clue.reader.QUOTE, expr), source
    end
    if t.type == "delimiter" and t.value == "`" then
        local expr, source = clue.reader.read_expression(tsource)
        return clue.list(clue.reader.SYNTAX_QUOTE, expr), source
    end
    if t.type == "delimiter" and t.value == "~" then
        local expr, source = clue.reader.read_expression(tsource)
        return clue.list(clue.reader.UNQUOTE, expr), source
    end
    if t.type == "delimiter" and t.value == "~@" then
        local expr, source = clue.reader.read_expression(tsource)
        return clue.list(clue.reader.UNQUOTE_SPLICING, expr), source
    end
    if t.type == "delimiter" and t.value == "#'" then
        local expr, source = clue.reader.read_expression(tsource)
        return clue.list(clue.reader.VAR, expr), source
    end
    clue.reader.read_error("unexpected token: " .. t.value, source)
end

function clue.reader.read(source)
    source = clue.map("text", source, "pos", 1)
    local es = clue.vector()
    local e, source = clue.reader.read_expression(source)
    while e ~= clue.reader.nothing do
        es:append(e)
        e, source = clue.reader.read_expression(source)
    end
    return es
end
