-- Dialog box widget. Consumes a dialog table from src/data/dialog/<id>.lua.
-- Enter advances lines; on the last line, Enter closes and fires grants via
-- the progression module. Escape also closes without firing grants (consistent
-- with "skip/cancel" feel in HK-likes — but grants still fire because closing
-- the sign does mean you saw it; flip if we want skip-doesn't-count later).

local M = {}
M.__index = M

local BOX_W = 720
local BOX_H = 140
local BOX_X = (800 - BOX_W) * 0.5
local BOX_Y = 600 - BOX_H - 28
local PAD   = 18

function M.new(dialog, progression)
  assert(dialog and dialog.lines and #dialog.lines > 0, 'dialog_box: empty dialog')
  return setmetatable({
    dialog = dialog,
    progression = progression,
    line_idx = 1,
    closed = false,
  }, M)
end

function M:on_push() end

function M:on_pop()
  local g = self.dialog.grants
  if g and g.flag and self.progression then
    self.progression.set(g.flag)
  end
end

function M:update(_dt)
  -- no animation yet
end

function M:keypressed(key)
  if key == 'return' or key == 'kpenter'
     or key == 'space' or key == 'e' then
    if self.line_idx < #self.dialog.lines then
      self.line_idx = self.line_idx + 1
    else
      self.closed = true
    end
  elseif key == 'escape' then
    self.closed = true
  end
end

function M:draw()
  -- dim world
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle('fill', 0, 0, 800, 600)

  -- box
  love.graphics.setColor(0.07, 0.09, 0.14, 0.97)
  love.graphics.rectangle('fill', BOX_X, BOX_Y, BOX_W, BOX_H)
  love.graphics.setColor(0.78, 0.72, 0.55)
  love.graphics.rectangle('line', BOX_X, BOX_Y, BOX_W, BOX_H)

  -- speaker
  if self.dialog.speaker then
    love.graphics.setColor(0.85, 0.90, 1.0)
    love.graphics.print(self.dialog.speaker, BOX_X + PAD, BOX_Y + 10)
  end

  -- line
  love.graphics.setColor(1, 1, 1)
  local line = self.dialog.lines[self.line_idx] or ''
  love.graphics.printf(line, BOX_X + PAD, BOX_Y + 40, BOX_W - PAD * 2, 'left')

  -- prompt
  love.graphics.setColor(0.75, 0.75, 0.75)
  local prompt
  if self.line_idx < #self.dialog.lines then
    prompt = ('[Enter]  %d/%d'):format(self.line_idx, #self.dialog.lines)
  else
    prompt = '[Enter]  close'
  end
  love.graphics.print(prompt, BOX_X + BOX_W - 140, BOX_Y + BOX_H - 24)

  love.graphics.setColor(1, 1, 1, 1)
end

return M
