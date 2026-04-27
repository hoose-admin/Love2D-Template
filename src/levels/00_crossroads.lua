-- Forgotten Crossroads — the intro zone. Wide horizontal layout with a bench
-- near the spawn, a few crawlers, stepping platforms, and a gate on the right
-- leading to Greenpath. Keeps a continuous ground for x=[-1000..1600] so the
-- legacy --test-walk smoke test still passes.

local Enemy     = require('src.enemy')
local abilities = require('src.abilities')

local M = {
  name          = 'crossroads',
  display_name  = 'Forgotten Crossroads',
  bg            = { 0.07, 0.08, 0.11 },
  player_start  = { x = 100, y = 400 },
  camera_bounds = { x = -400, y = -200, w = 3600, h = 900 },
  kill_y        = 900,
}

M.floor = { x = -1000, y = 550, w = 4050, h = 50 }

M.solids = {
  M.floor,
  { x = -1000, y =   0,  w =   20, h = 600 }, -- left wall
  { x =  1700, y = 470,  w =  160, h =  10 }, -- low stepping platform
  { x =  1940, y = 400,  w =  240, h =  10 }, -- mid platform
  { x =  2400, y = 450,  w =  100, h =  10 }, -- stepping stone above
  { x =  2700, y = 380,  w =  200, h =  10 }, -- upper ledge near the gate
  { x =  3050, y =   0,  w =   20, h = 600 }, -- right wall
  { x =  -980, y = 380,  w =  120, h =  10 }, -- little back-ledge near spawn
}

M.enemies_spec = {
  { x =  900, y = 520, patrol = {  820, 1080 } },
  { x = 1340, y = 520, patrol = { 1200, 1500 } },
  { x = 2500, y = 520, patrol = { 2260, 2900 } },
}

M.pickups_spec = {}

M.transitions = {
  { aabb = { x = 3030, y = 430, w = 20, h = 120 },
    to = 'greenpath',
    spawn = { x = 60, y = 500 } },
}

M.bench = { x = 240, y = 528, w = 40, h = 22 }

-- World-space readable objects. lovebuilder places them; lovenarrative
-- supplies the dialog id; loveui renders the resulting dialog box.
M.interactables = {
  { id     = 'crossroads_sign',
    kind   = 'sign',
    dialog = 'crossroads_sign',
    aabb   = { x = 700, y = 504, w = 20, h = 46 } },
}

function M:reset(player)
  self.enemies = {}
  for i = 1, #self.enemies_spec do
    self.enemies[#self.enemies + 1] = Enemy.new(self.enemies_spec[i])
  end
  self.pickups = {}
  for i = 1, #self.pickups_spec do
    local p = self.pickups_spec[i]
    local already_have = abilities.is_known(p.id) and player and abilities.has(player, p.id)
    if not already_have then
      self.pickups[#self.pickups + 1] = { id = p.id, aabb = p.aabb }
    end
  end
end

function M:draw()
  -- solids
  love.graphics.setColor(0.25, 0.26, 0.32)
  for i = 1, #self.solids do
    local s = self.solids[i]
    love.graphics.rectangle('fill', s.x, s.y, s.w, s.h)
  end

  -- bench
  local b = self.bench
  love.graphics.setColor(0.55, 0.40, 0.30)
  love.graphics.rectangle('fill', b.x, b.y, b.w, b.h)
  love.graphics.setColor(0.35, 0.25, 0.18)
  love.graphics.rectangle('fill', b.x, b.y, b.w, 4)
  love.graphics.rectangle('fill', b.x + 2, b.y + b.h, 4, 6)
  love.graphics.rectangle('fill', b.x + b.w - 6, b.y + b.h, 4, 6)

  -- transitions (subtle door glow)
  for i = 1, #self.transitions do
    local t = self.transitions[i]
    love.graphics.setColor(0.3, 0.5, 0.8, 0.35)
    love.graphics.rectangle('fill', t.aabb.x, t.aabb.y, t.aabb.w, t.aabb.h)
  end

  -- readable signs (post + board)
  for i = 1, #self.interactables do
    local it = self.interactables[i]
    if it.kind == 'sign' then
      love.graphics.setColor(0.45, 0.32, 0.22)
      love.graphics.rectangle('fill', it.aabb.x + 7, it.aabb.y + 14, 6, it.aabb.h - 14)
      love.graphics.setColor(0.60, 0.48, 0.30)
      love.graphics.rectangle('fill', it.aabb.x - 4, it.aabb.y, it.aabb.w + 8, 18)
      love.graphics.setColor(0.35, 0.25, 0.18)
      love.graphics.rectangle('line', it.aabb.x - 4, it.aabb.y, it.aabb.w + 8, 18)
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return M
