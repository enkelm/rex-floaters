local file, convention = arg[1], arg[2]
debug.getinfo = function() return { source = (convention == "lua" and "@" or "") .. file } end
local action, binding, popup
local bindings = {}
local process = { foreground = { cwd = "/tmp/repo's worktree" }, child = { cwd = "/wrong" } }
local placement = { block = { window_id = "window:caller" } }
rex = {
  action = function(value) action = value end,
  bind = function(key, name) binding = { key, name }; bindings[key] = name end,
  unbind = function(key) bindings[key] = nil end,
  block = { call = function(_, _, args)
    assert(args.block_id == "block:caller")
    return process
  end },
  layout = { block = function(block) return { block = block } end },
  session = {
    describe_block = function(args) assert(args.block_id == "block:caller"); return placement end,
    view = function() return { active_window_id = "window:other", windows = {
      { window_id = "window:other", focused_block_id = "block:other" },
      { window_id = "window:caller", focused_block_id = "block:caller", zoomed_block_id = "block:caller" },
    } } end,
    new_layer = function(value) popup = value; return { block_ids = { "block:popup" } } end,
  },
}
package.path = file .. ";" .. package.path
local extension = require("rex-lazygit")
assert(action == nil and binding == nil, "Requiring Lazygit must not register anything before setup")
assert(require("rex-lazygit") == extension, "Require must return the cached module")
assert(extension.setup() == extension, "setup must return the module")
assert(binding[1] == "cmd+shift+g" and binding[2] == action.name)
local ctx = { session_id = "session:test", block_id = "block:caller" }
assert(action.run(ctx).block_ids[1] == "block:popup")
assert(popup.window_id == "window:caller" and popup.focus == true)
local x, y, w, h = unpack(popup.bounds)
assert(x > 0 and y > 0 and w > 0 and h > 0 and x + w < 1 and y + h < 1)
assert(math.abs(2 * x + w - 1) < 0.0001 and math.abs(2 * y + h - 1) < 0.0001)
local options = popup.layout.block.options
assert(options.cwd == "/tmp/repo's worktree")
assert(options.command[1] == "/bin/sh")
assert(io.open(options.command[2], "r"), "Popup has no runnable launcher")
assert(options.command[3] == "window:caller" and options.command[4] == "block:caller" and options.command[5] == "block:caller")
assert(options.exit.on_completion == true and options.exit.quick_exit_threshold_ms == 0)
bindings["ctrl+q"] = "unrelated"
local custom = { bindings = { open = "alt+g" }, bounds = { 0.1, 0.2, 0.7, 0.6 } }
assert(extension.setup(custom) == extension)
assert(bindings["alt+g"] == "lazygit_open" and bindings["cmd+shift+g"] == nil)
custom.bounds[1], custom.bindings.open = 0.9, "alt+x"
action.run(ctx)
for index, value in ipairs({ 0.1, 0.2, 0.7, 0.6 }) do assert(popup.bounds[index] == value, "Popup must use a snapshot of configured bounds") end
for _, invalid in ipairs({ false, { binding = "alt+g" }, { bindings = "alt+g" }, { bindings = { typo = false } },
  { bindings = { open = 42 } }, { bindings = { open = "" } }, { bounds = { -1, 0, 1, 1 } },
  { bounds = { 0, 0, 0/0, 1 } }, { bounds = { 0, 0, 1, 2 } }, { bounds = { 0, 0, 1 } } }) do
  assert(not pcall(extension.setup, invalid), "Invalid config must be rejected")
  assert(bindings["alt+g"] == "lazygit_open", "Rejected config must preserve the previous binding")
end
assert(bindings["alt+x"] == nil)
extension.setup{ bindings = { open = false } }
assert(bindings["alt+g"] == nil and bindings["cmd+shift+g"] == nil and action.name == "lazygit_open")
extension.setup{ bindings = false }
assert(bindings["ctrl+q"] == "unrelated")
extension.setup()
assert(bindings["cmd+shift+g"] == "lazygit_open")
action.run(ctx)
assert(popup.bounds[1] == 0.05 and popup.bounds[3] == 0.9, "Omitted options must restore defaults")
process.foreground = nil
action.run(ctx)
assert(popup.layout.block.options.cwd == "/wrong", "Use child cwd when foreground cannot be read")
process.child = nil
local ok, err = pcall(action.run, ctx)
assert(not ok and tostring(err):find("directory"))
process.child = { cwd = "/tmp" }; placement.block.window_id = nil
ok, err = pcall(action.run, ctx)
assert(not ok and tostring(err):find("not in a window"))
ok, err = pcall(action.run, {})
assert(not ok and tostring(err):find("Focus the intended terminal"))
