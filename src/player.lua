-- Player: walk, variable-height jump with coyote + buffer, nail slash,
-- unlockable dash, focus heal, i-frames, death.
-- All collision is axis-separated AABB vs level.solids (no allocations in update).

local M = {}
M.__index = M

local function aabb_overlap(ax, ay, aw, ah, bx, by, bw, bh)
  return ax + aw > bx and ax < bx + bw
     and ay + ah > by and ay < by + bh
end

-- Movement
M.MOVE_SPEED       = 200
M.GRAVITY          = 1200
M.JUMP_VELOCITY    = -500
M.JUMP_CUT         = -150
M.COYOTE_TIME      = 0.10
M.JUMP_BUFFER      = 0.12

-- Nail attack
M.ATTACK_DURATION  = 0.10
M.ATTACK_COOLDOWN  = 0.35
M.ATTACK_RANGE     = 44
M.ATTACK_THICKNESS = 28

-- Dash (Mothwing Cloak)
M.DASH_SPEED       = 600
M.DASH_DURATION    = 0.20
M.DASH_COOLDOWN    = 0.60

-- Focus / soul
M.FOCUS_DURATION   = 1.00
M.SOUL_MAX         = 99
M.SOUL_PER_HIT     = 11
M.FOCUS_COST       = 33

-- Damage
M.HP_MAX_DEFAULT   = 5
M.IFRAMES          = 1.2
M.KNOCKBACK_X      = 180
M.KNOCKBACK_Y      = -160

-- Body
M.WIDTH            = 24
M.HEIGHT           = 32

function M.new(x, y)
  return setmetatable({
    x = x, y = y,
    vx = 0, vy = 0,
    w = M.WIDTH, h = M.HEIGHT,
    facing = 1,
    on_ground = false,
    coyote_t = 0,
    jump_buffer_t = 0,
    jump_holding = false,
    attack_t = 0,
    attack_cd = 0,
    dash_t = 0,
    dash_cd = 0,
    dash_dir = 0,
    abilities = { dash = false },
    hp_max = M.HP_MAX_DEFAULT,
    hp = M.HP_MAX_DEFAULT,
    soul = 0,
    is_focusing = false,
    focus_t = 0,
    iframe_t = 0,
    dead = false,
    jumped_this_frame = false,
    _attack_hitbox = { x = 0, y = 0, w = 0, h = 0, active = false },
  }, M)
end

function M:press_jump()
  self.jump_buffer_t = M.JUMP_BUFFER
  self.jump_holding = true
  self:cancel_focus()
end

-- kept for legacy test_mode callers that expected try_jump
function M:try_jump()
  self:press_jump()
end

function M:release_jump()
  self.jump_holding = false
  if self.vy < M.JUMP_CUT then self.vy = M.JUMP_CUT end
end

function M:try_attack()
  if self.attack_cd > 0 or self.dash_t > 0 or self.dead then return end
  self.attack_t = M.ATTACK_DURATION
  self.attack_cd = M.ATTACK_COOLDOWN
  self:cancel_focus()
end

function M:try_dash()
  if not self.abilities.dash then return end
  if self.dash_cd > 0 or self.dead or self.attack_t > 0 then return end
  self.dash_t = M.DASH_DURATION
  self.dash_cd = M.DASH_COOLDOWN
  self.dash_dir = self.facing
  self.vy = 0
  self:cancel_focus()
end

function M:cancel_focus()
  self.is_focusing = false
  self.focus_t = 0
end

function M:add_soul(n)
  self.soul = self.soul + n
  if self.soul > M.SOUL_MAX then self.soul = M.SOUL_MAX end
end

function M:apply_hit(source_x)
  if self.iframe_t > 0 or self.dead then return false end
  self.hp = self.hp - 1
  self.iframe_t = M.IFRAMES
  local dir = ((self.x + self.w * 0.5) >= source_x) and 1 or -1
  self.vx = dir * M.KNOCKBACK_X
  self.vy = M.KNOCKBACK_Y
  self.dash_t = 0
  self:cancel_focus()
  if self.hp <= 0 then
    self.dead = true
    self.hp = 0
  end
  return true
end

function M:on_enemy_hit()
  self:add_soul(M.SOUL_PER_HIT)
  self.vx = -self.facing * 80  -- small nail recoil
end

local function resolve_x(self, solids)
  for i = 1, #solids do
    local s = solids[i]
    if aabb_overlap(self.x, self.y, self.w, self.h, s.x, s.y, s.w, s.h) then
      if self.vx > 0 then self.x = s.x - self.w
      elseif self.vx < 0 then self.x = s.x + s.w end
      self.vx = 0
    end
  end
end

local function resolve_y(self, solids)
  self.on_ground = false
  for i = 1, #solids do
    local s = solids[i]
    if aabb_overlap(self.x, self.y, self.w, self.h, s.x, s.y, s.w, s.h) then
      if self.vy > 0 then
        self.y = s.y - self.h
        self.on_ground = true
      elseif self.vy < 0 then
        self.y = s.y + s.h
      end
      self.vy = 0
    end
  end
end

function M:update(dt, right, left, focus_held, level)
  self.jumped_this_frame = false
  if self.dead then
    -- still fall while dying so the body settles
    self.vy = self.vy + M.GRAVITY * dt
    self.y = self.y + self.vy * dt
    resolve_y(self, level.solids)
    return
  end

  -- Decay timers
  if self.attack_cd > 0 then self.attack_cd = self.attack_cd - dt end
  if self.dash_cd > 0 then self.dash_cd = self.dash_cd - dt end
  if self.attack_t > 0 then self.attack_t = self.attack_t - dt end
  if self.iframe_t > 0 then self.iframe_t = self.iframe_t - dt end
  if self.jump_buffer_t > 0 then self.jump_buffer_t = self.jump_buffer_t - dt end

  -- Facing
  if right and not left then self.facing = 1
  elseif left and not right then self.facing = -1 end

  -- Focus handling
  local moving = (right or left) and not (right and left)
  if self.is_focusing then
    if (not focus_held) or moving or (not self.on_ground)
       or self.soul < M.FOCUS_COST or self.hp >= self.hp_max
       or self.attack_t > 0 or self.dash_t > 0 then
      self:cancel_focus()
    else
      self.focus_t = self.focus_t + dt
      if self.focus_t >= M.FOCUS_DURATION then
        self.hp = math.min(self.hp_max, self.hp + 1)
        self.soul = self.soul - M.FOCUS_COST
        self.focus_t = 0
        if self.hp >= self.hp_max then self:cancel_focus() end
      end
    end
  elseif focus_held and self.on_ground and (not moving)
         and self.soul >= M.FOCUS_COST and self.hp < self.hp_max
         and self.attack_t <= 0 and self.dash_t <= 0 then
    self.is_focusing = true
    self.focus_t = 0
  end

  -- Horizontal velocity
  if self.dash_t > 0 then
    self.vx = self.dash_dir * M.DASH_SPEED
    self.vy = 0
    self.dash_t = self.dash_t - dt
  elseif self.is_focusing then
    self.vx = 0
  else
    local ax = (right and 1 or 0) - (left and 1 or 0)
    self.vx = ax * M.MOVE_SPEED
  end

  -- Gravity (suspended during dash)
  if self.dash_t <= 0 then
    self.vy = self.vy + M.GRAVITY * dt
  end

  -- Coyote
  if self.on_ground then
    self.coyote_t = 0
  else
    self.coyote_t = self.coyote_t + dt
  end

  -- Consume jump buffer
  if self.jump_buffer_t > 0 and self.coyote_t < M.COYOTE_TIME
     and self.dash_t <= 0 and not self.is_focusing then
    self.vy = M.JUMP_VELOCITY
    self.on_ground = false
    self.coyote_t = M.COYOTE_TIME  -- prevent double consumption
    self.jump_buffer_t = 0
    self.jumped_this_frame = true
  end

  -- Integrate + resolve (axis separated)
  self.x = self.x + self.vx * dt
  resolve_x(self, level.solids)
  self.y = self.y + self.vy * dt
  resolve_y(self, level.solids)

  -- Update attack hitbox (reuse same table)
  local hb = self._attack_hitbox
  if self.attack_t > 0 then
    hb.active = true
    hb.w = M.ATTACK_RANGE
    hb.h = M.ATTACK_THICKNESS
    hb.y = self.y + (self.h - M.ATTACK_THICKNESS) * 0.5
    if self.facing == 1 then
      hb.x = self.x + self.w
    else
      hb.x = self.x - M.ATTACK_RANGE
    end
  else
    hb.active = false
  end
end

function M:attack_hitbox()
  if self._attack_hitbox.active then return self._attack_hitbox end
  return nil
end

function M:draw()
  local alpha = 1
  if self.iframe_t > 0 then
    alpha = (math.floor(self.iframe_t * 20) % 2 == 0) and 0.35 or 1
  end

  if self.dash_t > 0 then
    love.graphics.setColor(0.7, 0.6, 1.0, 0.9)
  else
    love.graphics.setColor(0.90, 0.30, 0.40, alpha)
  end
  love.graphics.rectangle('fill', self.x, self.y, self.w, self.h)

  -- face marker
  love.graphics.setColor(1, 1, 1, alpha)
  local ex = self.x + ((self.facing == 1) and (self.w - 6) or 2)
  love.graphics.rectangle('fill', ex, self.y + 8, 4, 4)

  -- attack swipe
  local hb = self._attack_hitbox
  if hb.active then
    love.graphics.setColor(1, 0.95, 0.6, 0.75)
    love.graphics.rectangle('fill', hb.x, hb.y, hb.w, hb.h)
  end

  -- focus charge bar (world-space so it follows the player)
  if self.is_focusing then
    love.graphics.setColor(0.55, 0.9, 1.0, 0.85)
    love.graphics.rectangle(
      'fill',
      self.x, self.y - 8,
      self.w * (self.focus_t / M.FOCUS_DURATION), 4
    )
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return M
