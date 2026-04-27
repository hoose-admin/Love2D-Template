-- Title / start menu. Pushed onto the UI stack at boot; the existing
-- Stack.is_paused gate already freezes the world, so picking an item is the
-- only way into a running game. New Game wipes any save before starting fresh.

local M = {}
M.__index = M

local TITLE_TEXT  = 'PLATFORMER'
local SUB_TEXT    = 'a Hollow-Knight-shaped vertical slice'
local HINT_TEXT   = 'arrows / w-s to move   enter to select   esc to quit'

function M.new(opts)
  local items = {}
  if opts.has_save and opts.on_continue then
    items[#items + 1] = { label = 'Continue', action = opts.on_continue }
  end
  items[#items + 1] = { label = 'New Game', action = opts.on_new_game }
  items[#items + 1] = { label = 'Quit',     action = opts.on_quit }

  return setmetatable({
    items = items,
    selected = 1,
    closed = false,
    pulse_t = 0,
  }, M)
end

function M:on_push() end
function M:on_pop() end

function M:update(dt)
  self.pulse_t = self.pulse_t + dt
end

function M:keypressed(key)
  if key == 'up' or key == 'w' then
    self.selected = self.selected - 1
    if self.selected < 1 then self.selected = #self.items end
  elseif key == 'down' or key == 's' then
    self.selected = self.selected + 1
    if self.selected > #self.items then self.selected = 1 end
  elseif key == 'return' or key == 'kpenter' or key == 'space' then
    local item = self.items[self.selected]
    self.closed = true
    if item and item.action then item.action() end
  elseif key == 'escape' then
    -- Esc on the root menu quits.
    self.closed = true
    local quit_item
    for i = 1, #self.items do
      if self.items[i].label == 'Quit' then quit_item = self.items[i]; break end
    end
    if quit_item then quit_item.action() end
  end
end

function M:draw()
  love.graphics.setColor(0.04, 0.05, 0.08)
  love.graphics.rectangle('fill', 0, 0, 800, 600)

  -- decorative band
  love.graphics.setColor(0.08, 0.10, 0.15)
  love.graphics.rectangle('fill', 0, 130, 800, 110)

  love.graphics.setColor(0.90, 0.92, 1.00)
  love.graphics.printf(TITLE_TEXT, 0, 156, 800, 'center')

  love.graphics.setColor(0.55, 0.62, 0.78)
  love.graphics.printf(SUB_TEXT, 0, 196, 800, 'center')

  for i = 1, #self.items do
    local item = self.items[i]
    local y = 320 + (i - 1) * 36
    if i == self.selected then
      local pulse = 0.5 + 0.5 * math.sin(self.pulse_t * 4)
      love.graphics.setColor(1.00, 0.85 + pulse * 0.15, 0.40)
      love.graphics.printf('> ' .. item.label .. ' <', 0, y, 800, 'center')
    else
      love.graphics.setColor(0.65, 0.65, 0.75)
      love.graphics.printf(item.label, 0, y, 800, 'center')
    end
  end

  love.graphics.setColor(0.45, 0.45, 0.50)
  love.graphics.printf(HINT_TEXT, 0, 560, 800, 'center')

  love.graphics.setColor(1, 1, 1, 1)
end

return M
