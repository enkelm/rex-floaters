-- Importing is inert. setup registers terminal-backed floaters, never code in the invoking pane.
local filename = debug.getinfo(1, "S").source:gsub("^@", "")
local directory = assert(filename:match("(.*/)"), "Load rex-floaters from its init.lua file.")
local Config = dofile(directory .. "lib/config.lua")
local M, entries = {}, {}
local function checked(result, err)
  if result == nil then error(err or "Rex call failed.", 0) end
  return result
end
-- Rex refuses to minimize a window's last visible panes, e.g. after its layout's last pane exits.
local function shows_other(window, layer)
  for _, other in ipairs(window.layers or {}) do
    if other ~= layer and other.state ~= "minimized" and #(other.blocks or {}) > 0 then return true end
  end
end
local function run(name, ctx, close)
  local entry = entries[name]
  if not entry then error("rex-floaters: entry no longer configured: " .. name .. ". Reload Rex's config to remove its palette actions.", 0) end
  if not ctx.session_id or not ctx.block_id then error("Focus the intended terminal pane first.", 0) end
  local version = checked(rex.call("server.version"))
  if (version.api_revision or 0) < 9 then
    error("rex-floaters requires a Rex server with API revision 9 (session.set_layer_state). Upgrade/restart the server; updating the app alone is not enough.", 0)
  end
  local placement = checked(rex.session.describe_block{ block_id = ctx.block_id })
  local window_id = placement.block and placement.block.window_id
  if not window_id then error("The invoking pane is not in a window. Focus a placed terminal first.", 0) end
  local view = checked(rex.session.view{})
  for _, window in ipairs(view.windows or {}) do
    if window.window_id == window_id then
      for _, layer in ipairs(window.layers or {}) do
        if layer.kind == "floating" then
          for _, block in ipairs(layer.blocks or {}) do
            if block.label == "rex-floaters:" .. name and block.flavor == "com.superlogical.terminal.shell" then
              if close or (layer.state ~= "minimized" and not shows_other(window, layer)) then
                return checked(rex.call("block.close", { session_id = ctx.session_id, block_id = block.block_id }))
              end
              local state = layer.state == "minimized" and "normal" or "minimized"
              local result = checked(rex.call("session.set_layer_state", {
                session_id = ctx.session_id, layer_id = layer.layer_id, state = state, focus = state == "normal",
              }))
              if state == "normal" and entry.zoom then
                checked(rex.session.zoom_block{ block_id = block.block_id, zoom = true })
              end
              return result
            end
          end
        end
      end
      if close then return { closed = false } end
      local process = checked(rex.block.call("com.superlogical.terminal", "process", { block_id = ctx.block_id }))
      local cwd = process.foreground and process.foreground.cwd or process.child and process.child.cwd
      if not cwd then error("Rex cannot determine this terminal's directory. Focus a running local terminal.", 0) end
      local launch_entry = {}
      for key, value in pairs(entry) do launch_entry[key] = value end
      launch_entry.origin = { session_id = ctx.session_id, window_id = window_id, block_id = ctx.block_id,
        client_id = placement.block.owner or ctx.client_id, zoomed_block_id = window.zoomed_block_id or "",
        server_id = checked(rex.call("server.status")).instance_id }
      local args = checked(rex.json.encode({ entry = launch_entry, window = window_id,
        focus = window.focused_block_id or ctx.block_id, zoom = window.zoomed_block_id or "" }))
      local created = checked(rex.session.new_layer{
        window_id = window_id, bounds = entry.bounds, focus = not entry.zoom,
        layout = rex.layout.block{
          flavor = "com.superlogical.terminal.shell", label = "rex-floaters:" .. name,
          options = { command = { "/bin/sh", directory .. "launch.sh", args }, cwd = cwd,
            exit = { on_completion = true, quick_exit_threshold_ms = 0 } },
        },
      })
      if entry.zoom then
        local zoomed, err = rex.session.zoom_block{ block_id = created.block_ids[1], zoom = true }
        if not zoomed then
          rex.session.close_layer{ layer_id = created.layer_id }
          error(err or "Cannot zoom the floater.", 0)
        end
      end
      return created
    end
  end
  error("The invoking window closed before the floater opened.", 0)
end
local function register(resolved)
  entries = {}
  for _, entry in ipairs(resolved) do entries[entry.name] = entry end
  for _, entry in ipairs(resolved) do
    local name = entry.name
    for _, operation in ipairs({ "toggle", "close" }) do
      local close = operation == "close"
      rex.action{
        name = "floaters_" .. name .. "_" .. operation,
        title = entry.title .. (close and ": Close Floater" or ": Toggle Floater"),
        category = entry.category or "Floaters", keywords = entry.keywords or (name .. " floating popup"),
        description = close and "Terminate and close this tab's floater." or entry.description or
          "Show or hide this tab's floater without restarting its process.", args = {},
        run = function(ctx) return run(name, ctx, close) end,
      }
    end
  end
end
function M.setup(options)
  Config.apply(options, register)
  return M
end
return M
