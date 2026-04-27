-- Save/load via love.filesystem with schema_version.
-- Readers ignore unknown fields; unknown schema_version returns nil (fresh start).

local json = require('src.json')

local M = {}

M.SAVE_FILE = 'save.json'
M.SCHEMA_VERSION = 2
-- Accepted schema versions on read. v1 = pre-story-flags; v2 adds world.flags
-- and player.hints_seen. Readers ignore unknown fields in either direction.
M.READ_MIN = 1
M.READ_MAX = 2

function M.load()
  if not love.filesystem.getInfo(M.SAVE_FILE) then return nil end
  local data = love.filesystem.read(M.SAVE_FILE)
  if not data then return nil end
  local ok, decoded = pcall(json.decode, data)
  if not ok or type(decoded) ~= 'table' then return nil end
  local v = decoded.schema_version
  if type(v) ~= 'number' or v < M.READ_MIN or v > M.READ_MAX then return nil end
  return decoded
end

function M.save(t)
  t.schema_version = t.schema_version or M.SCHEMA_VERSION
  local ok, data = pcall(json.encode, t)
  if not ok then return false, data end
  return love.filesystem.write(M.SAVE_FILE, data)
end

return M
