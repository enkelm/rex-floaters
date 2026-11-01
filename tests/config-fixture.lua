-- Registration contracts only; popup/process behavior is exercised against real Rex in run.lua.
local file, convention = arg[1], arg[2]
local getinfo = debug.getinfo
debug.getinfo = function(level, what)
  local info = getinfo(level + 1, what)
  if info.source == "@" .. file then info.source = (convention == "lua" and "@" or "") .. file end
  return info
end
local bindings, actions = {}, {}
rex = {
  action = function(action) actions[action.name] = action end,
  bind = function(key, name) bindings[key] = name end,
  unbind = function(key, target) if bindings[key] == target then bindings[key] = nil end end,
}
package.path = file .. ";" .. package.path
local extension = require("rex-floaters")
assert(next(bindings) == nil and next(actions) == nil, "require must be inert")
assert(require("rex-floaters") == extension)
local options = { entries = {
  { name = "monitor", title = "Monitor", binding = "cmd+b", execute = { "btop" } },
  { name = "shell", binding = "cmd+s", execute = { "sh" } },
} }
assert(extension.setup(options) == extension)
assert(bindings["cmd+b"] == "floaters_monitor_toggle" and bindings["cmd+s"] == "floaters_shell_toggle")
assert(actions.floaters_monitor_close and actions.floaters_shell_toggle)
local root = file:gsub("/init%.lua$", "")
local Config = dofile(root .. "/lib/config.lua")
local rex_picker = Config.resolve{ entries = { { name = "rex", collect = "rex/collect.lua",
  picker = { backend = "tv", preview = "rex/preview.lua" }, execute = "rex/execute.lua" } } }
assert(rex_picker[1].picker.backend == "tv" and rex_picker[1].picker.preview == root .. "/floaters/rex/preview.lua")
local resolved = Config.resolve{ entries = { { name = "shell", execute = { "sh" } } } }
assert(resolved[1].picker.backend == "fzf", "Existing definitions must keep fzf as their default")
rex.call = function() return { api_revision = 7 } end
local supported, version_error = pcall(actions.floaters_monitor_toggle.run, { session_id = "session:test", block_id = "block:test" })
assert(not supported and tostring(version_error):find("API revision 9"), "Old servers need an actionable feature error")
for _, invalid in ipairs({ false, { bindings = false }, { entries = false }, { entries = { [2] = options.entries[1] } },
  { entries = { { name = "Invalid", execute = { "sh" } } } },
  { entries = { { name = "x", collect = "/missing.lua", execute = { "sh" } } } },
  { entries = { { name = "x", execute = {} } } },
  { entries = { { name = "x", execute = { "sh", 42 } } } },
  { entries = { { name = "x", execute = { "sh" }, picker = { multiple = 1 } } } },
  { entries = { { name = "x", execute = { "sh" }, picker = { backend = "missing" } } } },
  { entries = { { name = "x", execute = { "sh" }, picker = { backend = "tv" } } } },
  { entries = { { name = "x", execute = { "sh" }, picker = { backend = "tv", multiple = true,
    preview = "rex/preview.lua" } } } },
  { entries = { { name = "x", execute = { "sh" }, picker = { preview = "rex/preview.lua" } } } },
  { entries = { options.entries[1], options.entries[1] } },
  { entries = { { name = "a", binding = "cmd+shift+g", execute = { "sh" } },
                { name = "b", binding = "shift+cmd+g", execute = { "sh" } } } },
  { bounds = { 0, 0, 0/0, 1 }, entries = {} }, { bounds = { 0, 0, 1, 2 }, entries = {} },
  { bounds = { 0, 0, 1 }, entries = {} }, { bounds = false, entries = {} },
}) do
  assert(not pcall(extension.setup, invalid), "Invalid configuration was accepted")
  assert(bindings["cmd+b"] == "floaters_monitor_toggle" and bindings["cmd+s"] == "floaters_shell_toggle",
    "Invalid configuration changed existing bindings")
end
-- Another owner can replace our former chord without setup erasing its replacement.
bindings["cmd+b"] = "someone_else"
assert(extension.setup{ entries = { { name = "shell", execute = { "sh" } } } } == extension)
assert(bindings["cmd+b"] == "someone_else" and bindings["cmd+s"] == nil)
local ok, err = pcall(actions.floaters_monitor_toggle.run, {})
assert(not ok and tostring(err):find("no longer configured"), "Removed entries must not execute stale actions")
extension.setup{ entries = {} }
assert(bindings["cmd+b"] == "someone_else")
