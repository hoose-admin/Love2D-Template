local Player      = require('src.player')
local HUD         = require('src.hud')
local Save        = require('src.save')
local Stack       = require('src.ui.stack')
local DialogBox   = require('src.ui.dialog_box')
local progression = require('src.progression')

local LEVEL_MODULES = {
  crossroads = 'src.levels.00_crossroads',
  greenpath  = 'src.levels.01_greenpath',
}

local function aabb_overlap(ax, ay, aw, ah, bx, by, bw, bh)
  return ax + aw > bx and ax < bx + bw
     and ay + ah > by and ay < by + bh
end

local state = {
  player = nil,
  level = nil,
  zone = nil,
  t = 0,
  frames = 0,
  test_mode = false,
  max_x = 0,
  jumped = false,
  fell_through = false,
  camera_x = 0,
  camera_y = 0,
  respawn = nil,
  save_msg = nil,
  save_msg_t = 0,
  death_fade = 0,
  transition_cooldown = 0,  -- prevents bouncing back through a just-used transition
}

local function load_zone(zone, spawn)
  local mod = assert(LEVEL_MODULES[zone], 'unknown zone ' .. tostring(zone))
  local L = require(mod)
  L:reset(state.player)
  state.level = L
  state.zone = zone
  state.player.x = spawn.x
  state.player.y = spawn.y
  state.player.vx, state.player.vy = 0, 0
  state.player:cancel_focus()
  state.camera_x = state.player.x - 400
  state.camera_y = state.player.y - 300
  state.transition_cooldown = 0.35
end

local function respawn_from_save()
  local r = state.respawn
  state.player.hp = state.player.hp_max
  state.player.soul = 0
  state.player.dead = false
  state.player.iframe_t = 0
  state.player.vx, state.player.vy = 0, 0
  load_zone(r.zone, { x = r.x, y = r.y })
  state.death_fade = 0
end

function love.load(args)
  for _, v in ipairs(args or {}) do
    if v == '--test-walk' then state.test_mode = true end
  end

  local saved = Save.load()
  local respawn = (saved and saved.player and saved.player.respawn)
    or { zone = 'crossroads', x = 100, y = 400 }
  state.respawn = respawn
  state.player = Player.new(respawn.x, respawn.y)
  if saved and saved.player and saved.player.abilities
     and saved.player.abilities.dash == true then
    state.player.abilities.dash = true
  end
  if saved and saved.world and saved.world.flags then
    progression.load_from_save(saved.world.flags)
  end

  load_zone(respawn.zone, { x = respawn.x, y = respawn.y })
end

local function try_interact()
  -- Bench takes precedence over readable signs if they ever overlap.
  local b = state.level.bench
  if b and aabb_overlap(
        state.player.x, state.player.y, state.player.w, state.player.h,
        b.x, b.y, b.w, b.h) then
    state.respawn = {
      zone = state.zone,
      x = b.x + b.w * 0.5 - state.player.w * 0.5,
      y = b.y - state.player.h,
    }
    state.player.hp = state.player.hp_max
    local ok = Save.save({
      schema_version = Save.SCHEMA_VERSION,
      player = {
        respawn = state.respawn,
        abilities = { dash = state.player.abilities.dash },
        hints_seen = {},
      },
      world = {
        flags = progression.snapshot(),
      },
    })
    state.save_msg = ok and 'Saved at bench. Rested.' or 'Save failed.'
    state.save_msg_t = 2.5
    state.level:reset(state.player)
    return true
  end

  local items = state.level.interactables
  if items then
    for i = 1, #items do
      local it = items[i]
      if aabb_overlap(
           state.player.x, state.player.y, state.player.w, state.player.h,
           it.aabb.x, it.aabb.y, it.aabb.w, it.aabb.h) then
        if it.kind == 'sign' and it.dialog then
          local ok, dialog = pcall(require, 'src.data.dialog.' .. it.dialog)
          if ok and dialog then
            Stack.push(DialogBox.new(dialog, progression))
            return true
          end
        end
      end
    end
  end
  return false
end

function love.keypressed(key)
  if state.test_mode then return end

  if Stack.is_paused() then
    Stack.keypressed(key)
    return
  end

  if state.player.dead then return end

  if key == 'escape' then
    love.event.quit(0)
    return
  end
  if key == 'space' or key == 'w' or key == 'up' then
    state.player:press_jump()
  elseif key == 'j' or key == 'x' then
    state.player:try_attack()
  elseif key == 'k' or key == 'c' then
    state.player:try_dash()
  elseif key == 'return' or key == 'kpenter' or key == 'e' then
    try_interact()
  end
end

function love.keyreleased(key)
  if state.test_mode then return end
  if key == 'space' or key == 'w' or key == 'up' then
    state.player:release_jump()
  end
end

local function test_input(t)
  local right = (t >= 0 and t < 5) or (t >= 6 and t < 10) or (t >= 20 and t < 25)
  local left  = (t >= 10 and t < 15)
  return right, left
end

local function test_jump_at(t)
  return (t >= 4.95 and t < 5.05) or (t >= 19.95 and t < 20.05)
end

function love.update(dt)
  state.t = state.t + dt
  state.frames = state.frames + 1

  -- UI stack updates every frame. When it's non-empty, freeze world sim.
  Stack.update(dt)
  if not state.test_mode and Stack.is_paused() then
    if state.save_msg_t > 0 then
      state.save_msg_t = state.save_msg_t - dt
      if state.save_msg_t <= 0 then
        state.save_msg = nil
        state.save_msg_t = 0
      end
    end
    return
  end

  if state.transition_cooldown > 0 then
    state.transition_cooldown = state.transition_cooldown - dt
  end

  local right, left, focus_held
  if state.test_mode then
    right, left = test_input(state.t)
    focus_held = false
    if test_jump_at(state.t) then state.player:press_jump() end
  else
    right = love.keyboard.isDown('right') or love.keyboard.isDown('d')
    left  = love.keyboard.isDown('left')  or love.keyboard.isDown('a')
    focus_held = love.keyboard.isDown('l')
  end

  state.player:update(dt, right, left, focus_held, state.level)

  -- Enemies: update + nail-slash collision + contact damage.
  local hb = state.player:attack_hitbox()
  local enemies = state.level.enemies
  for i = 1, #enemies do
    local e = enemies[i]
    if not e.dead then
      e:update(dt, state.level)
    end
    if not e.dead and hb
       and aabb_overlap(hb.x, hb.y, hb.w, hb.h, e.x, e.y, e.w, e.h) then
      if e:take_hit(state.player.facing) then
        state.player:on_enemy_hit()
      end
    end
    if not e.dead and not state.player.dead
       and aabb_overlap(
           state.player.x, state.player.y, state.player.w, state.player.h,
           e.x, e.y, e.w, e.h) then
      state.player:apply_hit(e.x + e.w * 0.5)
    end
  end

  -- Pickups
  local pickups = state.level.pickups
  for i = #pickups, 1, -1 do
    local p = pickups[i]
    if aabb_overlap(
         state.player.x, state.player.y, state.player.w, state.player.h,
         p.aabb.x, p.aabb.y, p.aabb.w, p.aabb.h) then
      if p.id == 'dash' then
        state.player.abilities.dash = true
        state.save_msg = 'Acquired: Mothwing Cloak — press K to dash.'
        state.save_msg_t = 4
      end
      table.remove(pickups, i)
    end
  end

  -- Transitions
  if state.transition_cooldown <= 0 and not state.player.dead then
    local transitions = state.level.transitions
    for i = 1, #transitions do
      local tr = transitions[i]
      if aabb_overlap(
           state.player.x, state.player.y, state.player.w, state.player.h,
           tr.aabb.x, tr.aabb.y, tr.aabb.w, tr.aabb.h) then
        load_zone(tr.to, tr.spawn)
        break
      end
    end
  end

  -- Death on fall past kill_y
  if not state.player.dead and state.player.y > (state.level.kill_y or 2000) then
    state.player.hp = 0
    state.player.dead = true
  end

  -- Camera follow, clamped to zone bounds
  local tx = state.player.x + state.player.w * 0.5 - 400
  local ty = state.player.y + state.player.h * 0.5 - 300
  state.camera_x = tx
  state.camera_y = ty
  local cb = state.level.camera_bounds
  if cb then
    if state.camera_x < cb.x then state.camera_x = cb.x end
    if state.camera_y < cb.y then state.camera_y = cb.y end
    local max_x = cb.x + cb.w - 800
    local max_y = cb.y + cb.h - 600
    if state.camera_x > max_x then state.camera_x = max_x end
    if state.camera_y > max_y then state.camera_y = max_y end
  end

  -- Death fade & respawn
  if state.player.dead and not state.test_mode then
    state.death_fade = state.death_fade + dt
    if state.death_fade >= 1.2 then respawn_from_save() end
  end

  -- Transient message timer
  if state.save_msg_t > 0 then
    state.save_msg_t = state.save_msg_t - dt
    if state.save_msg_t <= 0 then
      state.save_msg = nil
      state.save_msg_t = 0
    end
  end

  -- Test harness tracking (preserved for CI)
  if state.player.x > state.max_x then state.max_x = state.player.x end
  if state.player.jumped_this_frame then state.jumped = true end
  if state.player.y > state.level.floor.y + 100 then state.fell_through = true end

  if state.test_mode and state.t >= 30 then
    local avg_fps = state.frames / state.t
    local errors = {}
    if avg_fps < 55 then errors[#errors + 1] = ('avg fps %.1f < 55'):format(avg_fps) end
    if not state.jumped then errors[#errors + 1] = 'player never jumped' end
    if state.max_x < 300 then errors[#errors + 1] = ('max_x %.0f < 300'):format(state.max_x) end
    if state.fell_through then errors[#errors + 1] = 'player fell through floor' end
    print(('test-walk: avg_fps=%.1f max_x=%.0f jumped=%s fell_through=%s')
      :format(avg_fps, state.max_x, tostring(state.jumped), tostring(state.fell_through)))
    if #errors == 0 then
      print('test-walk: PASS')
      love.event.quit(0)
    else
      for _, e in ipairs(errors) do print('test-walk: FAIL — ' .. e) end
      love.event.quit(1)
    end
  end
end

function love.draw()
  local bg = state.level.bg or { 0.08, 0.08, 0.10 }
  love.graphics.setColor(bg[1], bg[2], bg[3])
  love.graphics.rectangle('fill', 0, 0, 800, 600)

  love.graphics.push()
  love.graphics.translate(-math.floor(state.camera_x), -math.floor(state.camera_y))
  state.level:draw()
  local enemies = state.level.enemies
  for i = 1, #enemies do enemies[i]:draw() end
  state.player:draw()

  -- Interact prompt when near a bench or readable item and nothing is open.
  if Stack.is_empty() and not state.player.dead then
    local b = state.level.bench
    if b and aabb_overlap(state.player.x, state.player.y, state.player.w, state.player.h,
                          b.x, b.y, b.w, b.h) then
      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.print('[Enter] rest', b.x - 8, b.y - 16)
    end
    local items = state.level.interactables
    if items then
      for i = 1, #items do
        local it = items[i]
        if aabb_overlap(state.player.x, state.player.y, state.player.w, state.player.h,
                        it.aabb.x, it.aabb.y, it.aabb.w, it.aabb.h) then
          love.graphics.setColor(1, 1, 1, 0.9)
          love.graphics.print('[Enter] read', it.aabb.x - 10, it.aabb.y - 18)
        end
      end
    end
  end
  love.graphics.pop()

  local alpha = 1
  if state.save_msg_t < 0.6 then alpha = math.max(0, state.save_msg_t / 0.6) end
  HUD.draw(state.player, state.save_msg, alpha, state.level.display_name or state.zone)

  Stack.draw()

  if state.player.dead and not state.test_mode then
    love.graphics.setColor(0, 0, 0, math.min(0.85, state.death_fade / 1.2))
    love.graphics.rectangle('fill', 0, 0, 800, 600)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('You fell. Respawning at last bench.', 280, 290)
  end

  if state.test_mode then
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(('test-walk t=%.1f fps=%.0f x=%.0f'):format(
      state.t, love.timer.getFPS(), state.player.x), 10, 10)
  end
end
