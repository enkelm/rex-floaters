local Capture = require("pluck.collect.capture")
local Tokens = require("pluck.collect.tokens")
local Window = require("pluck.collect.window")

local function checked(result, err)
  if result == nil then error(err or "Rex call failed.", 0) end
  return result
end
local function valid_id(value, prefix)
  return type(value) == "string" and value:match("^" .. prefix .. ":[%w%-]+$") ~= nil
end

-- Verify the source, capture its visible panes, and find copy targets without terminal interaction.
return function(ctx)
  local origin = ctx.origin or {}
  local source, server_id, window_id, previous_zoom = origin.block_id, origin.server_id,
    origin.window_id, origin.zoomed_block_id or ""
  if not valid_id(source, "block") or source == rex.block_id or type(server_id) ~= "string" or server_id == ""
    or not valid_id(window_id, "window") or previous_zoom ~= "" and not valid_id(previous_zoom, "block") then
    error("Pluck has no verified source tab. Launch it from the intended Rex window.", 0)
  end
  if not rex.session_id or rex.session_id ~= origin.session_id or rex.block_id == nil
    or os.getenv("REX_SESSION") ~= rex.session_id or os.getenv("REX_BLOCK") ~= rex.block_id then
    error("Pluck has no verified picker terminal.", 0)
  end
  local status = checked(rex.call("server.status"))
  if status.instance_id ~= server_id then error("The Rex server or picker changed. Close this picker and launch Pluck again.", 0) end
  local view = checked(rex.session.view{})
  local plan = Window.visible_panes(view, window_id, source, rex.block_id, previous_zoom,
    "rex-floaters:" .. ctx.name)
  local captures, cells = {}, 0
  for index, pane in ipairs(plan) do
    local snapshot = pane.terminal and Capture.pane(rex, pane.block_id) or nil
    cells = cells + (snapshot and snapshot.columns * snapshot.height or 0)
    if cells > 1000000 then error("This tab exceeds Pluck's one-million-cell capture limit. Resize it and try again.", 0) end
    local capture = {}
    for key, value in pairs(pane) do capture[key] = value end
    capture.snapshot = snapshot
    captures[index] = capture
  end
  local snapshot = Window.window_snapshot(captures)
  return snapshot, Tokens.find_tokens(snapshot.lines)
end
