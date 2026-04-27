-- Story flags and progression gates. Flat set of boolean flags; gates declare
-- which flags they require. lovenarrative owns flag names; lovebuilder owns
-- rendering locked geometry that consults progression.unlocked.

local M = {
  flags = {},
  gates = {},  -- gate_id = { requires = {flag1, flag2} }
}

function M.set(flag)
  M.flags[flag] = true
end

function M.clear(flag)
  M.flags[flag] = nil
end

function M.has(flag)
  return M.flags[flag] == true
end

function M.unlocked(gate_id)
  local g = M.gates[gate_id]
  if not g then return false end
  local req = g.requires
  if req then
    for i = 1, #req do
      if not M.has(req[i]) then return false end
    end
  end
  return true
end

function M.reset()
  M.flags = {}
end

function M.load_from_save(saved_flags)
  M.flags = {}
  if type(saved_flags) ~= 'table' then return end
  for k, v in pairs(saved_flags) do
    if v == true then M.flags[k] = true end
  end
end

function M.snapshot()
  local out = {}
  for k, v in pairs(M.flags) do
    if v == true then out[k] = true end
  end
  return out
end

return M
