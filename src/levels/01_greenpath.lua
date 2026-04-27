-- Greenpath — vertical climb with the Mothwing Cloak (dash) pickup and its own
-- bench. Exiting on the left returns to Crossroads.

local Enemy = require('src.enemy')

local M = {
  name          = 'greenpath',
  display_name  = 'Greenpath',
  bg            = { 0.05, 0.13, 0.09 },
  player_start  = { x = 60, y = 500 },
  camera_bounds = { x = -100, y = -200, w = 2500, h = 900 },
  kill_y        = 900,
}

M.floor = { x = 0, y = 550, w = 220, h = 50 }

M.solids = {
  M.floor,
  { x =   0,  y =   0, w =  20, h = 600 }, -- left wall (but transition breaks it)
  { x = 220,  y = 420, w = 140, h =  10 }, -- ledge 1
  { x = 420,  y = 350, w = 140, h =  10 }, -- ledge 2
  { x = 620,  y = 280, w = 200, h =  12 }, -- dash pedestal
  { x = 900,  y = 340, w = 180, h =  10 }, -- ledge 3
  { x = 1180, y = 270, w = 200, h =  10 }, -- ledge 4
  { x = 1460, y = 190, w = 260, h =  14 }, -- bench plateau
  { x = 1500, y = 550, w = 900, h =  50 }, -- lower eastern ground
  { x = 2380, y =   0, w =  20, h = 600 }, -- right wall (dead end for now)
  { x = 1100, y = 550, w = 200, h =  50 }, -- small low platform (fallback pad)
}

M.enemies_spec = {
  { x =  460, y = 330, patrol = {  430,  550 } },
  { x =  940, y = 320, patrol = {  910, 1070 } },
  { x = 1560, y = 170, patrol = { 1470, 1710 } },
  { x = 1800, y = 530, patrol = { 1520, 2360 } },
}

M.pickups_spec = {
  { id = 'dash', aabb = { x = 700, y = 245, w = 36, h = 36 } },
}

M.transitions = {
  { aabb = { x = 0, y = 430, w = 18, h = 120 },
    to = 'crossroads',
    spawn = { x = 2990, y = 510 } },
}

M.bench = { x = 1560, y = 168, w = 40, h = 22 }

function M:reset(player)
  self.enemies = {}
  for i = 1, #self.enemies_spec do
    self.enemies[#self.enemies + 1] = Enemy.new(self.enemies_spec[i])
  end
  self.pickups = {}
  for i = 1, #self.pickups_spec do
    local p = self.pickups_spec[i]
    if not (p.id == 'dash' and player and player.abilities.dash) then
      self.pickups[#self.pickups + 1] = { id = p.id, aabb = p.aabb }
    end
  end
end

function M:draw()
  -- solids
  love.graphics.setColor(0.18, 0.30, 0.18)
  for i = 1, #self.solids do
    local s = self.solids[i]
    love.graphics.rectangle('fill', s.x, s.y, s.w, s.h)
  end
  -- top accent on each solid (leaf highlight)
  love.graphics.setColor(0.35, 0.55, 0.30)
  for i = 1, #self.solids do
    local s = self.solids[i]
    love.graphics.rectangle('fill', s.x, s.y, s.w, 3)
  end

  -- bench
  local b = self.bench
  love.graphics.setColor(0.55, 0.40, 0.30)
  love.graphics.rectangle('fill', b.x, b.y, b.w, b.h)
  love.graphics.setColor(0.35, 0.25, 0.18)
  love.graphics.rectangle('fill', b.x, b.y, b.w, 4)
  love.graphics.rectangle('fill', b.x + 2, b.y + b.h, 4, 6)
  love.graphics.rectangle('fill', b.x + b.w - 6, b.y + b.h, 4, 6)

  -- pickups (floating glow)
  for i = 1, #self.pickups do
    local p = self.pickups[i]
    love.graphics.setColor(0.85, 0.75, 1.0, 0.85)
    love.graphics.rectangle('fill', p.aabb.x, p.aabb.y, p.aabb.w, p.aabb.h)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.rectangle(
      'line',
      p.aabb.x, p.aabb.y, p.aabb.w, p.aabb.h
    )
  end

  -- transition glow
  for i = 1, #self.transitions do
    local t = self.transitions[i]
    love.graphics.setColor(0.3, 0.5, 0.8, 0.35)
    love.graphics.rectangle('fill', t.aabb.x, t.aabb.y, t.aabb.w, t.aabb.h)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return M
