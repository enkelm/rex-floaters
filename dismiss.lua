-- Called by the popup's own terminal after Lazygit exits, before Rex removes the layer.
local view, err = rex.session.view{}
if not view then error(err or "Cannot inspect the Rex view.", 0) end
if view.active_window_id ~= rex.args.window then return end
for _, window in ipairs(view.windows or {}) do
  if window.window_id == rex.args.window then
    if window.focused_block_id ~= rex.block_id then return end
    local zoomed = rex.args.zoom and rex.args.zoom ~= ""
    local target = zoomed and rex.args.zoom or rex.args.focus
    for _, layer in ipairs(window.layers or {}) do
      for _, block in ipairs(layer.blocks or {}) do
        if block.block_id == target then
          local result, restore_err
          if zoomed then
            result, restore_err = rex.session.zoom_block{ block_id = target, zoom = true }
          else
            result, restore_err = rex.session.focus_block{ block_id = target }
          end
          if not result then error(restore_err or "Cannot restore the Rex view.", 0) end
          return
        end
      end
    end
    return -- The original pane closed or moved; do not focus an unrelated pane.
  end
end
