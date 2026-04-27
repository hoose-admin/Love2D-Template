-- Minimal JSON encoder/decoder for save files.
-- Supports: nil, boolean, number, string (with basic escapes), array, object.
-- Not a full RFC 8259 implementation; scoped to what save.lua emits.

local M = {}

local function encode_value(v, buf)
  local t = type(v)
  if t == 'nil' then
    buf[#buf + 1] = 'null'
  elseif t == 'boolean' then
    buf[#buf + 1] = v and 'true' or 'false'
  elseif t == 'number' then
    if v ~= v or v == math.huge or v == -math.huge then
      buf[#buf + 1] = 'null'
    else
      buf[#buf + 1] = tostring(v)
    end
  elseif t == 'string' then
    buf[#buf + 1] = '"'
    buf[#buf + 1] = v
      :gsub('\\', '\\\\')
      :gsub('"', '\\"')
      :gsub('\n', '\\n')
      :gsub('\r', '\\r')
      :gsub('\t', '\\t')
    buf[#buf + 1] = '"'
  elseif t == 'table' then
    local n = 0
    for _ in pairs(v) do n = n + 1 end
    if n == #v and n > 0 then
      buf[#buf + 1] = '['
      for i = 1, #v do
        if i > 1 then buf[#buf + 1] = ',' end
        encode_value(v[i], buf)
      end
      buf[#buf + 1] = ']'
    else
      buf[#buf + 1] = '{'
      local first = true
      for k, val in pairs(v) do
        if not first then buf[#buf + 1] = ',' end
        first = false
        buf[#buf + 1] = '"'
        buf[#buf + 1] = tostring(k):gsub('"', '\\"')
        buf[#buf + 1] = '":'
        encode_value(val, buf)
      end
      buf[#buf + 1] = '}'
    end
  else
    error('json: unsupported type ' .. t)
  end
end

function M.encode(v)
  local buf = {}
  encode_value(v, buf)
  return table.concat(buf)
end

local src, pos

local function skip_ws()
  while pos <= #src do
    local b = src:byte(pos)
    if b == 32 or b == 9 or b == 10 or b == 13 then pos = pos + 1 else return end
  end
end

local decode_value

local function decode_string()
  pos = pos + 1
  local start = pos
  local parts
  while pos <= #src do
    local c = src:sub(pos, pos)
    if c == '"' then
      local chunk = src:sub(start, pos - 1)
      pos = pos + 1
      if parts then parts[#parts + 1] = chunk; return table.concat(parts) end
      return chunk
    elseif c == '\\' then
      parts = parts or {}
      parts[#parts + 1] = src:sub(start, pos - 1)
      local e = src:sub(pos + 1, pos + 1)
      if e == 'n' then parts[#parts + 1] = '\n'
      elseif e == 't' then parts[#parts + 1] = '\t'
      elseif e == 'r' then parts[#parts + 1] = '\r'
      elseif e == '"' then parts[#parts + 1] = '"'
      elseif e == '\\' then parts[#parts + 1] = '\\'
      elseif e == '/' then parts[#parts + 1] = '/'
      end
      pos = pos + 2
      start = pos
    else
      pos = pos + 1
    end
  end
  error('json: unterminated string')
end

local function decode_number()
  local start = pos
  while pos <= #src do
    local c = src:sub(pos, pos)
    if c:match('[%d%.%-eE+]') then pos = pos + 1 else break end
  end
  return tonumber(src:sub(start, pos - 1))
end

local function decode_array()
  pos = pos + 1
  local arr = {}
  skip_ws()
  if src:sub(pos, pos) == ']' then pos = pos + 1; return arr end
  while true do
    skip_ws()
    arr[#arr + 1] = decode_value()
    skip_ws()
    local c = src:sub(pos, pos)
    if c == ',' then pos = pos + 1
    elseif c == ']' then pos = pos + 1; return arr
    else error('json: expected , or ] at ' .. pos) end
  end
end

local function decode_object()
  pos = pos + 1
  local obj = {}
  skip_ws()
  if src:sub(pos, pos) == '}' then pos = pos + 1; return obj end
  while true do
    skip_ws()
    if src:sub(pos, pos) ~= '"' then error('json: expected string key') end
    local key = decode_string()
    skip_ws()
    if src:sub(pos, pos) ~= ':' then error('json: expected : at ' .. pos) end
    pos = pos + 1
    skip_ws()
    obj[key] = decode_value()
    skip_ws()
    local c = src:sub(pos, pos)
    if c == ',' then pos = pos + 1
    elseif c == '}' then pos = pos + 1; return obj
    else error('json: expected , or } at ' .. pos) end
  end
end

decode_value = function()
  skip_ws()
  local c = src:sub(pos, pos)
  if c == '{' then return decode_object()
  elseif c == '[' then return decode_array()
  elseif c == '"' then return decode_string()
  elseif c == 't' then pos = pos + 4; return true
  elseif c == 'f' then pos = pos + 5; return false
  elseif c == 'n' then pos = pos + 4; return nil
  else return decode_number() end
end

function M.decode(s)
  src = s
  pos = 1
  return decode_value()
end

return M
