-- HUD: HP masks, soul orb, ability badges, transient save/pickup message.

local abilities = require('src.abilities')

local M = {}

local MASK_SIZE     = 18
local MASK_SPACING  = 24
local HP_X          = 14
local HP_Y          = 14
local SOUL_CX       = 26
local SOUL_CY       = 56
local SOUL_R        = 16
local BADGE_X       = 14
local BADGE_Y       = 84
local BADGE_STEP    = 22

function M.draw(player, save_msg, save_msg_alpha, zone_name)
  -- HP masks
  for i = 1, player.hp_max do
    if i <= player.hp then
      love.graphics.setColor(0.95, 0.95, 0.95)
    else
      love.graphics.setColor(0.25, 0.25, 0.30)
    end
    love.graphics.rectangle(
      'fill',
      HP_X + (i - 1) * MASK_SPACING, HP_Y,
      MASK_SIZE, MASK_SIZE
    )
  end

  -- Soul orb
  love.graphics.setColor(0.08, 0.12, 0.18)
  love.graphics.circle('fill', SOUL_CX, SOUL_CY, SOUL_R)
  local frac = player.soul / 99
  if frac > 0 then
    love.graphics.setColor(0.45, 0.85, 1.0)
    love.graphics.circle('fill', SOUL_CX, SOUL_CY, SOUL_R * frac)
  end
  love.graphics.setColor(1, 1, 1, 0.8)
  love.graphics.circle('line', SOUL_CX, SOUL_CY, SOUL_R)

  -- Ability badges (driven by src/abilities.lua registry)
  local owned = abilities.iter_owned(player)
  for i = 1, #owned do
    local def = owned[i]
    local y = BADGE_Y + (i - 1) * BADGE_STEP
    love.graphics.setColor(0.75, 0.55, 1.0)
    love.graphics.rectangle('fill', BADGE_X, y, 16, 16)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(def.badge .. ' (' .. def.hotkey .. ')', BADGE_X + 22, y + 1)
  end

  -- Zone label
  if zone_name then
    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.print(zone_name, 800 - 14 - #zone_name * 7, 14)
  end

  -- Transient message
  if save_msg then
    love.graphics.setColor(1, 1, 1, save_msg_alpha or 1)
    love.graphics.print(save_msg, 260, 20)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return M
