local Player = require('src.player')
local Level = require('src.levels.00_intro')

local state = {
  player = nil,
  level = nil,
  t = 0,
  frames = 0,
  test_mode = false,
  max_x = 0,
  jumped = false,
  fell_through = false,
}

function love.load(args)
  for _, v in ipairs(args or {}) do
    if v == '--test-walk' then state.test_mode = true end
  end
  state.level = Level
  state.player = Player.new(state.level.player_start.x, state.level.player_start.y)
end

function love.keypressed(key)
  if state.test_mode then return end
  if key == 'space' or key == 'w' or key == 'up' then
    state.player:try_jump()
  elseif key == 'escape' then
    love.event.quit(0)
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

  local right, left
  if state.test_mode then
    right, left = test_input(state.t)
    if test_jump_at(state.t) then state.player:try_jump() end
  else
    right = love.keyboard.isDown('right') or love.keyboard.isDown('d')
    left  = love.keyboard.isDown('left')  or love.keyboard.isDown('a')
  end

  state.player:update(dt, right, left, state.level)

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
  love.graphics.setColor(0.1, 0.1, 0.15)
  love.graphics.rectangle('fill', 0, 0, 800, 600)
  state.level:draw()
  state.player:draw()
  if state.test_mode then
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(('test-walk t=%.1f fps=%.0f x=%.0f'):format(
      state.t, love.timer.getFPS(), state.player.x), 10, 10)
  end
end
