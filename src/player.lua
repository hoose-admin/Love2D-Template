local M = {}
M.__index = M

local function aabb_overlap(ax, ay, aw, ah, bx, by, bw, bh)
  return ax + aw > bx and ax < bx + bw
     and ay + ah > by and ay < by + bh
end

M.MOVE_SPEED    = 200
M.GRAVITY       = 1200
M.JUMP_VELOCITY = -500
M.WIDTH         = 24
M.HEIGHT        = 32

function M.new(x, y)
  return setmetatable({
    x = x, y = y,
    vx = 0, vy = 0,
    on_ground = false,
    jumped_this_frame = false,
  }, M)
end

function M:try_jump()
  if self.on_ground then
    self.vy = M.JUMP_VELOCITY
    self.on_ground = false
    self.jumped_this_frame = true
  end
end

function M:update(dt, right, left, level)
  self.jumped_this_frame = false

  local ax = (right and 1 or 0) - (left and 1 or 0)
  self.vx = ax * M.MOVE_SPEED

  self.vy = self.vy + M.GRAVITY * dt

  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt

  local f = level.floor
  local on_ground = false
  if aabb_overlap(self.x, self.y, M.WIDTH, M.HEIGHT,
                  f.x, f.y, f.w, f.h) and self.vy >= 0 then
    self.y = f.y - M.HEIGHT
    self.vy = 0
    on_ground = true
  end
  self.on_ground = on_ground
end

function M:draw()
  love.graphics.setColor(0.9, 0.3, 0.4)
  love.graphics.rectangle('fill', self.x, self.y, M.WIDTH, M.HEIGHT)
end

return M
