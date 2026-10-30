local file = arg[1]
local action, next_id = nil, 0
local windows = {
  { window_id = "window:one", focused_block_id = "block:one", layers = {
    { kind = "tiled", blocks = { { block_id = "block:one", label = "Lazygit", flavor = "com.superlogical.terminal.shell" } } },
    { kind = "floating", blocks = { { block_id = "block:unrelated", label = "Other", flavor = "com.superlogical.terminal.shell" } } },
  } },
  { window_id = "window:two", focused_block_id = "block:two", layers = {
    { kind = "tiled", blocks = { { block_id = "block:two" } } },
  } },
}
local function find(id)
  for _, window in ipairs(windows) do
    for _, layer in ipairs(window.layers) do
      for i, block in ipairs(layer.blocks) do
        if block.block_id == id then return window, layer, i end
      end
    end
  end
end
local function popups(window)
  local result = {}
  for _, layer in ipairs(window.layers) do
    if layer.kind == "floating" then
      for _, block in ipairs(layer.blocks) do
        if block.label == "Lazygit" then result[#result + 1] = block.block_id end
      end
    end
  end
  return result
end
local unreadable = false
rex = {
  action = function(value) action = value end, bind = function() end,
  block = { call = function() assert(not unreadable, "Closing must not require a readable terminal process"); return { child = { cwd = "/tmp" } } end },
  call = function(method, args)
    assert(method == "block.close")
    local window, layer, i = find(args.block_id)
    assert(layer.kind == "floating" and layer.blocks[i].label == "Lazygit", "Closed an unrelated pane")
    table.remove(layer.blocks, i)
    return {}
  end,
  layout = { block = function(block) return { block = block } end },
  session = {
    describe_block = function(args) return { block = { window_id = find(args.block_id).window_id } } end,
    view = function() return { active_window_id = "window:two", windows = windows } end,
    new_layer = function(args)
      local window = args.window_id == "window:one" and windows[1] or windows[2]
      next_id = next_id + 1
      local block = args.layout.block
      block.block_id = "block:popup" .. next_id
      window.layers[#window.layers + 1] = { kind = "floating", blocks = { block } }
      return { block_ids = { block.block_id } }
    end,
  },
}
local function press(id) return action.run({ session_id = "session:test", block_id = id }) end
dofile(file)
local first = press("block:one").block_ids[1]
assert(#popups(windows[1]) == 1)
press(first)
assert(#popups(windows[1]) == 0, "Second shortcut must close the popup, not create another")
local reopened = press("block:one").block_ids[1]
press("block:two")
assert(#popups(windows[1]) == 1 and #popups(windows[2]) == 1, "Each window needs an independent popup")
-- An old duplicate and an unrelated sibling must not escape window-scoped cleanup.
windows[1].layers[#windows[1].layers + 1] = { kind = "floating", blocks = {
  { block_id = "block:old-duplicate", label = "Lazygit", flavor = "com.superlogical.terminal.shell" },
} }
local _, shared = find(reopened)
shared.blocks[#shared.blocks + 1] = { block_id = "block:sibling", label = "Shell", flavor = "com.superlogical.terminal.shell" }
dofile(file) -- Discovery must use live placement, not a cache lost on reload.
unreadable = true
press("block:one")
assert(#popups(windows[1]) == 0 and #popups(windows[2]) == 1, "Toggling one window closed another's popup")
press(popups(windows[2])[1])
assert(#popups(windows[2]) == 0)
assert(find("block:one") and find("block:unrelated") and find("block:sibling"), "Tiled and unrelated floating panes must survive")
