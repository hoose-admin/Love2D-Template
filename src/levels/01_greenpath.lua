-- Greenpath — vertical climb with the Mothwing Cloak (dash) pickup and its
-- own bench. Geometry tuned so each upward step is ~70 px (player jump apex
-- is ~104 px, so this is reachable without the dash). Exiting on the left
-- returns to Crossroads.

local Enemy     = require('src.enemy')
local abilities = require('src.abilities')

local M = {
  name          = 'greenpath',
  display_name  = 'Greenpath',
  bg            = { 0.05, 0.13, 0.09 },
  player_start  = { x = 100, y = 500 },
  camera_bounds = { x = -100, y = -200, w = 2600, h = 900 },
  kill_y        = 900,
}

M.floor = { x = 0, y = 550, w = 240, h = 50 }

M.solids = {
  M.floor,
  { x =    0, y =   0, w =  18, h = 420 }, -- top portion of left wall (transition occupies the bottom)
  { x =  200, y = 480, w = 180, h =  10 }, -- ledge 1 (rise ~70 from spawn)
  { x =  380, y = 410, w = 180, h =  10 }, -- ledge 2
  { x =  580, y = 340, w = 240, h =  12 }, -- dash pedestal
  { x =  860, y = 380, w = 220, h =  10 }, -- ledge 3 (slight drop, rest stop)
  { x = 1140, y = 310, w = 240, h =  10 }, -- ledge 4
  { x = 1440, y = 240, w = 260, h =  14 }, -- bench plateau
  { x = 1500, y = 550, w = 900, h =  50 }, -- lower eastern ground
  { x = 2380, y =   0, w =  20, h = 600 }, -- right wall (dead end for now)
  { x = 1100, y = 550, w = 200, h =  50 }, -- low fallback platform under climb
}

M.enemies_spec = {
  { x =  430, y = 390, patrol = {  390,  555 } },
  { x =  920, y = 360, patrol = {  870, 1075 } },
  { x = 1560, y = 220, patrol = { 1450, 1690 } },
  { x = 1800, y = 530, patrol = { 1520, 2360 } },
}

M.pickups_spec = {
  { id = 'dash', aabb = { x = 672, y = 304, w = 36, h = 36 } },
}

M.transitions = {
  { aabb = { x = 0, y = 440, w = 18, h = 110 },
    to = 'crossroads',
    spawn = { x = 2920, y = 500 } },
}

M.bench = { x = 1500, y = 218, w = 40, h = 22 }

function M:reset(player)
  self.enemies = {}
  for i = 1, #self.enemies_spec do
    self.enemies[#self.enemies + 1] = Enemy.new(self.enemies_spec[i])
  end
  self.pickups = {}
  for i = 1, #self.pickups_spec do
    local p = self.pickups_spec[i]
    -- Filter pickups the player already owns. Generic over abilities.lua
    -- registry: any pickup whose id matches an owned ability is suppressed.
    local already_have = abilities.is_known(p.id) and player and abilities.has(player, p.id)
    if not already_have then
      self.pickups[#self.pickups + 1] = { id = p.id, aabb = p.aabb }
    end
  end
end

function M:draw()
  love.graphics.setColor(0.18, 0.30, 0.18)
  for i = 1, #self.solids do
    local s = self.solids[i]
    love.graphics.rectangle('fill', s.x, s.y, s.w, s.h)
  end
  love.graphics.setColor(0.35, 0.55, 0.30)
  for i = 1, #self.solids do
    local s = self.solids[i]
    love.graphics.rectangle('fill', s.x, s.y, s.w, 3)
  end

  local b = self.bench
  love.graphics.setColor(0.55, 0.40, 0.30)
  love.graphics.rectangle('fill', b.x, b.y, b.w, b.h)
  love.graphics.setColor(0.35, 0.25, 0.18)
  love.graphics.rectangle('fill', b.x, b.y, b.w, 4)
  love.graphics.rectangle('fill', b.x + 2, b.y + b.h, 4, 6)
  love.graphics.rectangle('fill', b.x + b.w - 6, b.y + b.h, 4, 6)

  for i = 1, #self.pickups do
    local p = self.pickups[i]
    love.graphics.setColor(0.85, 0.75, 1.0, 0.85)
    love.graphics.rectangle('fill', p.aabb.x, p.aabb.y, p.aabb.w, p.aabb.h)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.rectangle('line', p.aabb.x, p.aabb.y, p.aabb.w, p.aabb.h)
  end

  for i = 1, #self.transitions do
    local t = self.transitions[i]
    love.graphics.setColor(0.3, 0.5, 0.8, 0.35)
    love.graphics.rectangle('fill', t.aabb.x, t.aabb.y, t.aabb.w, t.aabb.h)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return M
