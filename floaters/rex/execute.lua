local ctx, values = ...
local prefix = "rex-floaters:"
local function call(method, args)
  local result, err = rex.call(method, args)
  if result == nil then error(err or ("Rex call failed: " .. method), 0) end
  return result
end
if type(values) ~= "table" or #values ~= 1 then error("Choose one Rex tab.", 0) end
local target = assert(rex.json.decode(values[1]))
if type(target.session_id) ~= "string" or type(target.window_id) ~= "string" or type(target.block_id) ~= "string" then
  error("The selected Rex tab is invalid.", 0)
end

local attached = pcall(function() call("session.attach", { session_id = target.session_id }) end)
if not attached then
  print("The selected pane's session is no longer available.")
  return 0
end
local view_ok, view = pcall(function() return call("session.view", { session_id = target.session_id }) end)
if not view_ok then
  print("The selected pane's session is no longer available.")
  return 0
end

local selected_layer
local exists = false
for _, window in ipairs(view.windows or {}) do
  if window.window_id == target.window_id then
    for _, layer in ipairs(window.layers or {}) do
      for _, block in ipairs(layer.blocks or {}) do
        if block.block_id == target.block_id and (block.label or ""):sub(1, #prefix) ~= prefix then
          exists = true
          if layer.state == "minimized" then selected_layer = layer end
          break
        end
      end
      if exists then break end
    end
    if exists then break end
  end
end
if not exists then
  print("The selected tab or its remembered pane disappeared before it could be focused.")
  return 0
end

local origin = ctx.origin
if not origin or target.session_id ~= origin.session_id or target.window_id ~= origin.window_id then
  local can_select, handoff_issue = false, "No originating Rex app client is available. Focus will change only in server state."
  if origin and origin.client_id then
    local ok, result = pcall(function() return call("client.inspect", { client_id = origin.client_id }) end)
    local client = ok and result.client
    can_select = client and client.info and client.info.kind == "app" or false
    if can_select then
      can_select = false
      for _, action in ipairs(result.actions or {}) do
        if action.name == "session.select" then can_select = true; break end
      end
    end
    if not ok then handoff_issue = "The originating Rex app is unavailable. Focus will change only in server state."
    elseif not can_select then handoff_issue = "The originating Rex app cannot display the selected tab. Focus will change only in server state." end
  end
  -- Use only the app that owns the pane which opened this floater; never guess among connected clients.
  if can_select then
    local performed, perform_error = rex.call("client.perform", { client_id = origin.client_id, action = "session.select",
      args = { session_id = target.session_id, window_id = target.window_id },
      session_id = target.session_id, block_id = target.block_id, origin = "api" })
    if performed == nil then
      local message = tostring(perform_error or "Rex.app refused the navigation request.")
      if message:find("not accepting actions", 1, true) then
        error("Rex.app cannot navigate from the picker while Remote Control is off. Turn it on in Rex Settings under Rex Server, then retry.", 0)
      end
      error(message, 0)
    end
  else
    print(handoff_issue)
  end
end

if selected_layer then
  call("session.set_layer_state", { session_id = target.session_id, layer_id = selected_layer.layer_id,
    state = "normal" })
end
call("session.focus_block", { session_id = target.session_id, block_id = target.block_id })
return 0
