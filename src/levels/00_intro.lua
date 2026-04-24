local M = {
  name = 'intro',
  player_start = { x = 100, y = 400 },
  floor = { x = -1000, y = 550, w = 5000, h = 50 },
  geometry = {},
  gates = {},
  transitions = {},
}

function M:draw()
  love.graphics.setColor(0.3, 0.3, 0.35)
  love.graphics.rectangle('fill', self.floor.x, self.floor.y, self.floor.w, self.floor.h)
end

return M
