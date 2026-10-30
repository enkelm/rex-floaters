-- Lazygit runs in its own floating terminal, never inside the invoking shell/agent.
local filename = debug.getinfo(1, "S").source
if filename:sub(1, 1) == "@" then filename = filename:sub(2) end
local directory = assert(filename:match("(.*/)"), "Load Lazygit from its init.lua file.")
local function checked(result, err)
  if result == nil then error(err or "Rex call failed.", 0) end
  return result
end
local M = {}

function M.setup()
  rex.action{
    name = "lazygit_open", title = "Lazygit: Toggle Floating Window", category = "Git",
    keywords = "lg lazygit git repository floating popup",
    description = "Toggle one floating Lazygit per window. Choose a checkout when multiple worktrees are found.",
    args = {},
    run = function(ctx)
      if not ctx.session_id or not ctx.block_id then error("Focus the intended terminal pane first.", 0) end
      local placement = checked(rex.session.describe_block{ block_id = ctx.block_id })
      local window_id = placement.block and placement.block.window_id
      if not window_id then error("The invoking pane is not in a window. Focus a placed terminal first.", 0) end
      local view = checked(rex.session.view{})
      for _, window in ipairs(view.windows or {}) do
        if window.window_id == window_id then
          -- Discover live popups, so toggling still works after a config reload and from any pane.
          -- Only the reserved Lazygit floating terminals belong to this toggle, never tiled panes.
          local popups = {}
          for _, layer in ipairs(window.layers or {}) do
            if layer.kind == "floating" then
              for _, block in ipairs(layer.blocks or {}) do
                if block.label == "Lazygit" and block.flavor == "com.superlogical.terminal.shell" then
                  popups[#popups + 1] = block.block_id
                end
              end
            end
          end
          if #popups > 0 then
            -- Also remove duplicates left by the old opener, without closing unrelated layer siblings.
            for _, block_id in ipairs(popups) do checked(rex.call("block.close", { session_id = ctx.session_id, block_id = block_id })) end
            return { closed_block_ids = popups }
          end
          local process = checked(rex.block.call("com.superlogical.terminal", "process", { block_id = ctx.block_id }))
          local cwd = process.foreground and process.foreground.cwd or process.child and process.child.cwd
          if not cwd then error("Rex cannot determine this terminal's directory. Focus a running local terminal.", 0) end
          return checked(rex.session.new_layer{
            window_id = window_id, bounds = { 0.05, 0.05, 0.9, 0.9 }, focus = true,
            layout = rex.layout.block{
              flavor = "com.superlogical.terminal.shell", label = "Lazygit",
              options = {
                -- Rex's default login shell supplies PATH; lg is an interactive alias for lazygit.
                command = { "/bin/sh", directory .. "launch.sh", window_id, window.focused_block_id or ctx.block_id, window.zoomed_block_id or "" },
                cwd = cwd, exit = { on_completion = true, quick_exit_threshold_ms = 0 },
              },
            },
          })
        end
      end
      error("The invoking window closed before Lazygit opened.", 0)
    end,
  }
  rex.bind("cmd+shift+g", "lazygit_open")
  return M
end

return M
