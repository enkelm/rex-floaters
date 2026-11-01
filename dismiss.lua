-- Use Rex's layer focus history, so re-showing from another pane returns there, not to a stale origin.
local function checked(value, err)
  if value == nil then error(err or "Cannot restore the Rex view.", 0) end
  return value
end
local view = checked(rex.session.view{})
if view.active_window_id ~= rex.args.window then return end
for _, window in ipairs(view.windows or {}) do
  if window.window_id == rex.args.window then
    if window.focused_block_id ~= rex.block_id then return end
    for _, layer in ipairs(window.layers or {}) do
      if layer.kind == "floating" and layer.state ~= "minimized" then
        for _, block in ipairs(layer.blocks or {}) do
          if block.block_id == rex.block_id then
            -- A user may split this layer. Don't minimize still-running siblings on our exit.
            if #layer.blocks ~= 1 then return end
            checked(rex.call("session.set_layer_state", {
              session_id = rex.session_id, layer_id = layer.layer_id, state = "minimized",
            }))
            -- Restore an initial zoom only when native history actually returned to that pane.
            local after = checked(rex.session.view{})
            for _, current in ipairs(after.windows or {}) do
              if current.window_id == window.window_id and current.focused_block_id == rex.args.focus and
                rex.args.zoom ~= "" and rex.args.zoom == current.focused_block_id then
                checked(rex.session.zoom_block{ block_id = rex.args.zoom, zoom = true })
              end
            end
            return
          end
        end
      end
    end
    return
  end
end
