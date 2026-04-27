-- Ability registry. The single source of truth for ability metadata.
--
-- Adding a new ability:
--   1. Add an entry below with id, display_name, badge, hotkey, pickup_message,
--      and player_method (the M:try_X method on Player that runs the behavior).
--   2. Implement that try_X method on src/player.lua. It should early-return
--      when `not self.abilities[id]`.
--   3. Wire the input key in main.lua's love.keypressed (one branch per ability).
--   4. Place a pickup spec on a level: `{ id = '<id>', aabb = {...} }` in
--      pickups_spec. Levels filter pickups the player already owns automatically
--      (see level:reset).
-- That is the entire surface area. Save/HUD/level-reset all read from this
-- registry generically.

local M = {}

M.registry = {
  dash = {
    id             = 'dash',
    display_name   = 'Mothwing Cloak',
    badge          = 'DASH',
    hotkey         = 'K',
    pickup_message = 'Acquired: Mothwing Cloak — press K to dash.',
    player_method  = 'try_dash',
  },
}

-- Stable iteration order helps deterministic rendering (HUD badges).
local function ordered_ids()
  local ids = {}
  for id in pairs(M.registry) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

function M.def(id)
  return M.registry[id]
end

function M.is_known(id)
  return M.registry[id] ~= nil
end

-- Mark an ability as owned. Returns the def so callers can do their own
-- on-acquire side effects (e.g. setting a save_msg). Returns nil for
-- unknown ids without modifying the player.
function M.acquire(player, id)
  local def = M.registry[id]
  if not def then return nil end
  player.abilities[id] = true
  return def
end

function M.has(player, id)
  return player.abilities[id] == true
end

-- Iterate ability defs the player owns, in stable order.
function M.iter_owned(player)
  local out = {}
  for _, id in ipairs(ordered_ids()) do
    if player.abilities[id] then out[#out + 1] = M.registry[id] end
  end
  return out
end

function M.snapshot(player)
  local out = {}
  for id in pairs(M.registry) do
    if player.abilities[id] then out[id] = true end
  end
  return out
end

function M.load(player, saved)
  if type(saved) ~= 'table' then return end
  for id in pairs(M.registry) do
    if saved[id] == true then player.abilities[id] = true end
  end
end

return M
