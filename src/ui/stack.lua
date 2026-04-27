-- Menu/overlay stack. While non-empty, the world is paused (main.lua checks
-- is_paused). Only the top receives input. Lower entries still draw so
-- dialog boxes layer cleanly over the frozen world.

local M = {}

local stack = {}

function M.push(screen)
  stack[#stack + 1] = screen
  if screen.on_push then screen:on_push() end
end

function M.pop()
  local top = stack[#stack]
  stack[#stack] = nil
  if top and top.on_pop then top:on_pop() end
  return top
end

function M.top()
  return stack[#stack]
end

function M.is_empty()
  return #stack == 0
end

function M.is_paused()
  return #stack > 0
end

function M.clear()
  while #stack > 0 do M.pop() end
end

function M.update(dt)
  local top = stack[#stack]
  if top and top.update then top:update(dt) end
  -- closed-flag convention: widget flips self.closed = true when done.
  if top and top.closed then M.pop() end
end

function M.draw()
  for i = 1, #stack do
    local s = stack[i]
    if s.draw then s:draw() end
  end
end

function M.keypressed(key)
  local top = stack[#stack]
  if top and top.keypressed then
    top:keypressed(key)
    if top.closed then M.pop() end
    return true
  end
  return false
end

return M
