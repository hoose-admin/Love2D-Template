-- Crawler enemy: patrols a horizontal range, contact-damages, dies in 2 hits.

local M = {}
M.__index = M

local function aabb_overlap(ax, ay, aw, ah, bx, by, bw, bh)
  return ax + aw > bx and ax < bx + bw
     and ay + ah > by and ay < by + bh
end

M.WIDTH          = 24
M.HEIGHT         = 20
M.SPEED          = 50
M.HP_DEFAULT     = 2
M.GRAVITY        = 900
M.HIT_FLASH      = 0.12
M.HIT_NUDGE      = 6

function M.new(def)
  local patrol_min = (def.patrol and def.patrol[1]) or (def.x - 80)
  local patrol_max = (def.patrol and def.patrol[2]) or (def.x + 80)
  return setmetatable({
    x = def.x, y = def.y,
    w = M.WIDTH, h = M.HEIGHT,
    vx = M.SPEED, vy = 0,
    hp = def.hp or M.HP_DEFAULT,
    patrol_min = patrol_min,
    patrol_max = patrol_max,
    dead = false,
    hit_flash = 0,
  }, M)
end

local function resolve_y(self, solids)
  for i = 1, #solids do
    local s = solids[i]
    if aabb_overlap(self.x, self.y, self.w, self.h, s.x, s.y, s.w, s.h) then
      if self.vy > 0 then
        self.y = s.y - self.h
      elseif self.vy < 0 then
        self.y = s.y + s.h
      end
      self.vy = 0
    end
  end
end

function M:update(dt, level)
  if self.dead then return end

  self.vy = self.vy + M.GRAVITY * dt
  self.y = self.y + self.vy * dt
  resolve_y(self, level.solids)

  self.x = self.x + self.vx * dt
  if self.x < self.patrol_min then
    self.x = self.patrol_min
    self.vx = math.abs(self.vx)
  end
  if self.x + self.w > self.patrol_max then
    self.x = self.patrol_max - self.w
    self.vx = -math.abs(self.vx)
  end

  if self.hit_flash > 0 then self.hit_flash = self.hit_flash - dt end
end

function M:take_hit(dir)
  if self.dead then return false end
  self.hp = self.hp - 1
  self.hit_flash = M.HIT_FLASH
  self.x = self.x + dir * M.HIT_NUDGE
  if self.hp <= 0 then self.dead = true end
  return true
end

function M:draw()
  if self.dead then return end
  if self.hit_flash > 0 then
    love.graphics.setColor(1, 1, 1)
  else
    love.graphics.setColor(0.45, 0.75, 0.40)
  end
  love.graphics.rectangle('fill', self.x, self.y, self.w, self.h)
  love.graphics.setColor(0.15, 0.25, 0.15)
  love.graphics.rectangle('fill', self.x + 4, self.y + 5, 4, 4)
  love.graphics.rectangle('fill', self.x + self.w - 8, self.y + 5, 4, 4)
  love.graphics.setColor(1, 1, 1, 1)
end

return M
