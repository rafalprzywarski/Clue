require 'clue'
require 'core'
require 'class'

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

clue.reader = {}
local M = clue.reader
M.nothing = {"nothing"}
M.constants = {
    ["true"] = true,
    ["false"] = false
}

M.COMMENT = ";"
M.QUOTE = clue.symbol("quote")
M.SYNTAX_QUOTE = clue.symbol("syntax-quote")
M.UNQUOTE = clue.symbol("unquote")
M.UNQUOTE_SPLICING = clue.symbol("unquote-splicing")
M.VAR = clue.symbol("var")

function M.read_error(msg, source)
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

function M.number(value)
    return {type = "number", value = value}
end

function M.string(value)
    return {type = "string", value = value}
end

function M.symbol(value)
    return {type = "symbol", value = value}
end

function M.keyword(value)
    return {type = "keyword", value = value}
end

function M.is_space(c)
    return c == " " or c == "," or c == "\t" or c == "\r" or c == "\n"
end

M.delimiters = clue.set("(", ")", "[", "]", "{", "}", "^", "\'", "`", "~")

function M.is_delimiter(c)
    return M.delimiters:at(c) ~= nil
end

function M.skip_comment(s)
    local text = s("text")
    local pos = s("pos")
    if text:sub(pos, pos) == M.COMMENT then
        for i = pos, text:len() do
            if text:sub(i, i) == "\n" then
                return s:assoc("pos", i + 1)
            end
        end
        return s:assoc("pos", text:len() + 1)
    end
    return s
end

function M.skip_space(s)
    local text = s("text")
    local pos = s("pos")
    for i = pos, text:len() do
        if not M.is_space(text:sub(i, i)) then
            if i == pos then
                return s
            end
            return s:assoc("pos", i)
        end
    end
    return s:assoc("pos", text:len() + 1)
end

function M.skip_space_and_comments(s)
    local skipped = M.skip_space(M.skip_comment(s))
    while skipped ~= s and skipped("pos") <= skipped("text"):len() do
        s = skipped
        skipped = M.skip_space(M.skip_comment(s))
    end
    return skipped
end

function M.read_string(s)
    local text = s("text")
    local pos = s("pos")
    for i = pos + 1, s("text"):len() do
        if text:sub(i, i) == "\"" then
            return M.string(text:sub(pos + 1, i - 1)), s:assoc("pos", i + 1)
        end
    end
    M.read_error("missing closing \"", s:assoc("pos", text:len() + 1))
end

function M.read_number(s)
    local text = s("text")
    local pos = s("pos")
    local i = pos + 1
    while i <= text:len() and tonumber(text:sub(pos, i)) do
        i = i + 1
    end
    return M.number(tonumber(text:sub(pos, i - 1))), s:assoc("pos", i)
end

function M.read_symbol(s)
    local text = s("text")
    local pos = s("pos")
    for i = pos + 1, text:len() do
        if M.is_space(text:sub(i, i)) or M.is_delimiter(text:sub(i, i)) or text:sub(i, i) == M.COMMENT then
            return M.symbol(text:sub(pos, i - 1)), s:assoc("pos", i)
        end
    end
    return M.symbol(text:sub(pos)), s:assoc("pos", text:len() + 1)
end

function M.read_keyword(s)
    local sym
    sym, s = M.read_symbol(s:assoc("pos", s("pos") + 1))
    return M.keyword(sym.value), s
end

function M.split_by_slash(s)
    if s == "/" then
        return s
    end
    local slash = s:find("/")
    if not slash then
        return s
    end
    return s:sub(1, slash - 1), s:sub(slash + 1)
end

function M.split_symbol(s)
    return clue.symbol(M.split_by_slash(s.value))
end

function M.split_keyword(s)
    return clue.keyword(M.split_by_slash(s.value))
end

function M.read_token(source)
    local source = M.skip_space_and_comments(source)
    local text = source("text")
    local pos = source("pos")
    local first = text:sub(pos, pos)
    if first == "" then
        return M.nothing, source
    end
    if M.is_delimiter(first) or first == "#" then
        second = text:sub(pos + 1, pos + 1)
        if first == "~" and second == "@" then
            first = "~@"
        elseif first == "#" and second == "'" then
            first = "#'"
        end
        return {type = "delimiter", value = first}, source:assoc("pos", pos + first:len())
    elseif first == "\"" then
        return M.read_string(source)
    elseif first == ":" then
        return M.read_keyword(source)
    elseif tonumber(first) then
        return M.read_number(source)
    else
        return M.read_symbol(source)
    end
end

function M.read_sequence(source, create, closing)
    local l = clue.vector()
    local e, nsource = M.read_expression(source)
    while e ~= M.nothing do
        l:append(e)
        source = nsource
        e, nsource = M.read_expression(source)
    end

    local t, tsource = M.read_token(source)
    if t == M.nothing then
        M.read_error("expected " .. closing, tsource)
    end
    if t.value ~= closing then
        M.read_error("expected " .. closing .. " got " .. tostring(t.value), source)
    end
    return create(l:unpack()), tsource
end

function M.read_expression(source)
    local t, tsource = M.read_token(source)
    if t == M.nothing then
        return M.nothing, tsource
    end
    if t.type == "number" then
        return t.value, tsource
    end
    if t.type == "string" then
        return t.value, tsource
    end
    if t.type == "symbol" then
        if M.constants[t.value] ~= nil then
            return M.constants[t.value], tsource
        end
        if t.value == "nil" then
            return nil, tsource
        end
        return M.split_symbol(t), tsource
    end
    if t.type == "keyword" then
        return M.split_keyword(t), tsource
    end
    if t.type == "delimiter" and t.value == ")" then
        return M.nothing, tsource
    end
    if t.type == "delimiter" and t.value == "(" then
        return M.read_sequence(tsource, clue.list, ")")
    end
    if t.type == "delimiter" and t.value == "]" then
        return M.nothing, tsource
    end
    if t.type == "delimiter" and t.value == "[" then
        return M.read_sequence(tsource, clue.vector, "]")
    end
    if t.type == "delimiter" and t.value == "}" then
        return M.nothing, tsource
    end
    if t.type == "delimiter" and t.value == "{" then
        return M.read_sequence(tsource, clue.map, "}")
    end
    if t.type == "delimiter" and t.value == "^" then
        local meta, source = M.read_expression(tsource)
        local value, source = M.read_expression(source)
        if clue.type(meta) == clue.Keyword then
            meta = clue.map(meta, true)
        end
        value.meta = meta:merge(value.meta)
        return value, source
    end
    if t.type == "delimiter" and t.value == "\'" then
        local expr, source = M.read_expression(tsource)
        return clue.list(M.QUOTE, expr), source
    end
    if t.type == "delimiter" and t.value == "`" then
        local expr, source = M.read_expression(tsource)
        return clue.list(M.SYNTAX_QUOTE, expr), source
    end
    if t.type == "delimiter" and t.value == "~" then
        local expr, source = M.read_expression(tsource)
        return clue.list(M.UNQUOTE, expr), source
    end
    if t.type == "delimiter" and t.value == "~@" then
        local expr, source = M.read_expression(tsource)
        return clue.list(M.UNQUOTE_SPLICING, expr), source
    end
    if t.type == "delimiter" and t.value == "#'" then
        local expr, source = M.read_expression(tsource)
        return clue.list(M.VAR, expr), source
    end
    M.read_error("unexpected token: " .. t.value, source)
end

function M.read(source)
    source = clue.map("text", source, "pos", 1)
    local es = clue.vector()
    local e, source = M.read_expression(source)
    while e ~= M.nothing do
        es:append(e)
        e, source = M.read_expression(source)
    end
    return es
end
