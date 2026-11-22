local directory = debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*/)")
local H = dofile(directory .. "harness.lua")
H.test("setup registration, validation, and binding ownership", function()
  for _, convention in ipairs({ "rex", "lua" }) do
    H.command({ "luajit", directory .. "config-fixture.lua", H.root .. "/init.lua", convention })
  end
end)
local function resolve(f, options, name)
  return f:json({ "do", "-e", "local C=dofile(" .. H.json(H.root .. "/lib/config.lua") .. "); " ..
    "for _,entry in ipairs(C.resolve(rex.args.options)) do if not rex.args.name or entry.name==rex.args.name then return entry end end; error('No entry')",
    "--args", H.json({ options = options, name = name }) })
end
local function launch(t, f, entry, cwd)
  local before = f:view()
  return H.terminal(t, f, { "/bin/sh", H.root .. "/launch.sh", H.json({ entry = entry,
    window = before.windows[1].window_id, focus = f.env.REX_BLOCK, zoom = "" }) }, cwd)
end
local function configure(f, options)
  H.write(f.env.REX_CONFIG, "package.path = " .. H.json(f.directory .. "/?/init.lua;") .. " .. package.path\n" ..
    "require('rex-floaters').setup(assert(rex.json.decode(" .. H.json(H.json(options)) .. ")))\n")
  f:call({ "config", "reload" })
end
local function action(f, name, block, operation)
  return f:json({ "do", "floaters_" .. name .. "_" .. (operation or "toggle"), "-s", f.env.REX_SESSION, "-b", block or f.env.REX_BLOCK })
end
local function popup(f, name)
  for _, window in ipairs(f:view().windows) do
    for _, layer in ipairs(window.layers or {}) do
      if layer.kind == "floating" then
        for _, block in ipairs(layer.blocks or {}) do
          if block.label == "rex-floaters:" .. name then return block.block_id, layer, window end
        end
      end
    end
  end
end
local function absent(f, name)
  H.wait(function() return not popup(f, name) end, "Popup did not close: " .. name)
end
local function fixture(t, location)
  local f, cwd = H.fixture(t, "lazygit"), nil
  if location == "umbrella" or location == "one-repository" then
    cwd = f.workspace
    if location == "one-repository" then H.command({ "mv", f.web, f.directory .. "/other-web" }) end
  elseif location == "worktrees" then
    cwd = f.directory .. "/worktrees"; H.command({ "mkdir", cwd })
    local linked = cwd .. "/feature's worktree"
    f:git(f.core, { "worktree", "move", f.linked, linked }); f.linked = linked
    f:git(f.core, { "worktree", "add", "-b", "second-feature", cwd .. "/second-feature" })
  elseif location == "main" then cwd = f.core
  elseif location == "linked" then cwd = f.linked .. "/src"; H.command({ "mkdir", "-p", cwd })
  else
    cwd = (location == "nested" and f.core or f.web) .. "/src"
    if location == "nested" then
      local nested = f.core .. "/embedded"; H.command({ "mkdir", nested }); f:git(nested, { "init", "-b", "main" })
    end
  end
  local before = f:view()
  local ui = launch(t, f, resolve(f, nil, "lazygit"), cwd)
  local function dismissed()
    H.equal(f:view().windows[1].layers, before.windows[1].layers)
    H.equal(f:view().windows[1].focused_block_id, f.env.REX_BLOCK); f:no_node()
  end
  return f, ui, cwd, dismissed
end
H.test("Lazygit collector selection opens the exact linked checkout", function(t)
  local f, ui, _, dismissed = fixture(t, "umbrella")
  for _, text in ipairs({ "Lazygit · Choose a worktree", "core / main", "core / feature/test", "web / main", "modified", "clean" }) do ui:expect(text) end
  ui:press("feature/test"); ui:press(" ")
  assert(not ui:output():find("LG_STARTED:", 1, true), "Selection launched without Enter")
  ui:press("\r", "LG_STARTED:"); ui:done(); H.equal(H.read(f.lazygitLog), f.linked); dismissed()
end)
H.test("cancelling collection never starts the executor", function(t)
  local f, ui, _, dismissed = fixture(t, "umbrella")
  ui:expect("Lazygit · Choose a worktree"); ui:press("\27"); ui:done()
  assert(not H.read(f.lazygitLog)); dismissed()
end)
for _, location in ipairs({ "main", "linked", "nested", "single", "one-repository", "worktrees" }) do
  H.test("Lazygit skips the picker: " .. location, function(t)
    local f, ui, cwd, dismissed = fixture(t, location)
    ui:expect("LG_STARTED:"); ui:done()
    assert(not ui:output():find("Choose a worktree", 1, true), "Single repository opened a picker")
    H.equal(H.read(f.lazygitLog), location == "one-repository" and f.core or location == "worktrees" and f.linked or cwd)
    dismissed()
  end)
end
H.test("inline definitions resolve the bundled collector relative to directory", function(t)
  local f = H.fixture(t, "lazygit")
  local entry = resolve(f, { entries = { { name = "git", collect = "lazygit/collect.lua", execute = "lazygit/execute.lua" } } })
  launch(t, f, entry, f.core):done()
  H.equal(H.read(f.lazygitLog), f.core)
end)
H.test("bundled btop runs without arguments, Git, or fzf", function(t)
  local f = H.fixture(t, "lazygit")
  local log, git_log = f.directory .. "/btop-result", f.directory .. "/git-called"
  H.write(f.bin .. "/btop", "#!/bin/sh\nprintf '%s\\n%s' \"$#\" \"$PWD\" > " .. H.quote(log) .. "\n")
  H.write(f.bin .. "/git", "#!/bin/sh\nprintf 'called' > " .. H.quote(git_log) .. "; exit 86\n")
  H.command({ "chmod", "700", f.bin .. "/btop", f.bin .. "/git" })
  f.env.REX_FLOATERS_FZF = "/missing-fzf"
  launch(t, f, resolve(f, nil, "btop"), f.web):done()
  H.equal(H.read(log), "0\n" .. f.web)
  assert(not H.read(git_log), "The generic runner invoked Git for btop")
end)
H.test("directory definitions and native hide/show retain processes across reload, names, and tabs", function(t)
  local f = H.fixture(t, "lazygit")
  local definitions = f.directory .. "/definitions with spaces"
  H.command({ "mkdir", "-p", definitions .. "/alpha", definitions .. "/beta" })
  local starts = f.directory .. "/starts"
  local command = { "/bin/sh", "-c", "printf 'started\\n' >> " .. H.quote(starts) .. "; read -r answer" }
  for _, name in ipairs({ "alpha", "beta" }) do
    H.write(definitions .. "/" .. name .. "/init.lua", "return assert(rex.json.decode(" .. H.json(H.json({
      title = "Same display title", binding = "alt+" .. name:sub(1, 1), execute = command,
    })) .. "))\n")
  end
  configure(f, { directory = definitions, bounds = { 0.1, 0.2, 0.7, 0.6 } })
  local keymap = f:json({ "api", "call", "client.keymap", "{}" })
  local keys = {}
  for _, binding in ipairs(keymap.bindings) do
    if binding.action:match("^floaters_") then keys[binding.action] = binding.keys end
  end
  H.equal(keys, { floaters_alpha_toggle = { "alt+a" }, floaters_beta_toggle = { "alt+b" } })
  local original_window = f:view().windows[1].window_id
  local other = f:json({ "split", "-s", f.env.REX_SESSION, "-b", f.env.REX_BLOCK, "--shell=none", "--json", "--", "/bin/sh", "-c", "while :; do sleep 60; done" }).block_ids[1]
  action(f, "alpha", other)
  H.wait(function() return H.read(starts) end, "Executor did not start")
  local alpha, layer = popup(f, "alpha"); assert(alpha)
  H.equal(layer.bounds, { 0.1, 0.2, 0.7, 0.6 })
  local process = f:json({ "block", "call", "-s", f.env.REX_SESSION, "-b", alpha, "process" })
  action(f, "alpha", alpha)
  H.equal(select(2, popup(f, "alpha")).state, "minimized")
  H.equal(f:view().windows[1].focused_block_id, other)
  f:call({ "config", "reload" })
  action(f, "alpha", other)
  H.equal(popup(f, "alpha"), alpha)
  assert(select(2, popup(f, "alpha")).state ~= "minimized")
  local after = f:json({ "block", "call", "-s", f.env.REX_SESSION, "-b", alpha, "process" })
  H.equal(after.child.pid, process.child.pid); H.equal(H.read(starts), "started\n")
  action(f, "beta", alpha)
  local beta = popup(f, "beta"); assert(beta and beta ~= alpha)
  action(f, "alpha", beta) -- Hiding alpha must neither hide nor terminate beta.
  assert(select(2, popup(f, "beta")).state ~= "minimized")
  action(f, "beta", other, "close"); absent(f, "beta")
  local second = f:json({ "window", "new", "-s", f.env.REX_SESSION, "Second", "--shell=none", "--json", "--", "/bin/sh", "-c", "while :; do sleep 60; done" })
  local second_origin = second.block_ids[1]
  action(f, "alpha", second_origin)
  local windows = f:view().windows
  H.equal(#windows, 2)
  local count = 0
  for _, window in ipairs(windows) do
    for _, candidate in ipairs(window.layers) do for _, block in ipairs(candidate.blocks or {}) do
      if block.label == "rex-floaters:alpha" then count = count + 1 end
    end end
  end
  H.equal(count, 2)
  action(f, "alpha", second_origin, "close")
  -- Exiting while hidden must remove that popup without stealing focus from the other tab.
  f:call({ "send-key", "-s", f.env.REX_SESSION, "-b", alpha, "enter" })
  absent(f, "alpha")
  H.equal(f:view().active_window_id, second.window_id)
  assert(original_window ~= second.window_id)
  f:no_node()
end)
H.test("executor exit restores the latest invoking pane; initial zoom is preserved", function(t)
  local f = H.fixture(t, "lazygit")
  configure(f, { entries = { { name = "wait", execute = { "/bin/sh", "-c", "read -r answer" } } } })
  f:call({ "zoom", "-s", f.env.REX_SESSION, f.env.REX_BLOCK, "--on" })
  action(f, "wait")
  local id = H.wait(function() return popup(f, "wait") end, "No popup")
  f:call({ "send-key", "-s", f.env.REX_SESSION, "-b", id, "enter" }); absent(f, "wait")
  H.equal(f:view().windows[1].zoomed_block_id, f.env.REX_BLOCK)
  f:call({ "zoom", "-s", f.env.REX_SESSION, f.env.REX_BLOCK, "--off" })
  action(f, "wait")
  id = H.wait(function() return popup(f, "wait") end, "No popup")
  action(f, "wait", id)
  local other = f:json({ "split", "-s", f.env.REX_SESSION, "-b", f.env.REX_BLOCK, "--shell=none", "--json", "--", "/bin/sh", "-c", "while :; do sleep 60; done" }).block_ids[1]
  action(f, "wait", other)
  f:call({ "send-key", "-s", f.env.REX_SESSION, "-b", id, "enter" }); absent(f, "wait")
  H.equal(f:view().windows[1].focused_block_id, other)
end)
H.test("tiled labels and unrelated floating siblings survive owned executor exit", function(t)
  local f = H.fixture(t, "lazygit")
  configure(f, { entries = { { name = "owned", execute = { "/bin/sh", "-c", "read -r answer" } } } })
  f:call({ "block", "rename", "-s", f.env.REX_SESSION, f.env.REX_BLOCK, "rex-floaters:owned" })
  local unowned = f:json({ "api", "call", "session.new_layer", H.json({ session_id = f.env.REX_SESSION,
    window_id = f:view().windows[1].window_id, bounds = { 0.1, 0.1, 0.5, 0.5 }, layout = { block = {
      flavor = "com.superlogical.terminal.shell", label = "Other", options = {
        command = { "/bin/sh", "-c", "while :; do sleep 60; done" },
      },
    } } }) }).block_ids[1]
  action(f, "owned")
  local owned = assert(popup(f, "owned"), "A matching tiled label must not prevent a new popup")
  local sibling = f:json({ "split", "-s", f.env.REX_SESSION, "-b", owned, "--shell=none", "--json", "--", "/bin/sh", "-c", "while :; do sleep 60; done" }).block_ids[1]
  H.equal(#select(2, popup(f, "owned")).blocks, 2)
  f:call({ "focus", "-s", f.env.REX_SESSION, owned })
  f:call({ "send-key", "-s", f.env.REX_SESSION, "-b", owned, "enter" }); absent(f, "owned")
  local live = {}
  for _, block in ipairs(f:blocks()) do live[block.block_id] = true end
  assert(live[sibling] and live[unowned] and live[f.env.REX_BLOCK], "An unrelated terminal was closed")
  for _, layer in ipairs(f:view().windows[1].layers) do
    for _, block in ipairs(layer.blocks or {}) do if block.block_id == sibling then
      assert(layer.state ~= "minimized", "Executor exit hid an unrelated sibling")
    end end
  end
end)
H.test("toggle closes a floater left as its tab's only visible pane", function(t)
  local f = H.fixture(t, "lazygit")
  configure(f, { entries = { { name = "last", execute = { "/bin/sh", "-c", "read -r answer" } } } })
  local tab = f:json({ "window", "new", "-s", f.env.REX_SESSION, "Last", "--shell=none", "--json", "--", "/bin/sh", "-c", "read -r answer" })
  local origin = tab.block_ids[1]
  action(f, "last", origin)
  local id = H.wait(function() return popup(f, "last") end, "No popup")
  action(f, "last", id)
  H.equal(select(2, popup(f, "last")).state, "minimized")
  -- The tab's last tiled pane exits; Rex keeps the tab and shows the hidden floater.
  f:call({ "send-key", "-s", f.env.REX_SESSION, "-b", origin, "enter" })
  H.wait(function() return select(2, popup(f, "last")).state ~= "minimized" end, "Floater was not shown")
  action(f, "last", id)
  absent(f, "last")
  for _, window in ipairs(f:view().windows) do assert(window.window_id ~= tab.window_id, "Tab stayed open") end
end)
H.test("native picker cancellation closes the actual popup and restores focus", function(t)
  local f = H.fixture(t, "lazygit")
  local origin = f:json({ "split", "-s", f.env.REX_SESSION, "-b", f.env.REX_BLOCK, "-c", f.workspace, "--shell=none", "--json", "--", "/bin/sh", "-c", "while :; do sleep 60; done" }).block_ids[1]
  action(f, "lazygit", origin)
  local id = H.wait(function() return popup(f, "lazygit") end, "No popup")
  H.wait(function() return f:capture(id):find("Lazygit · Choose a worktree", 1, true) end, "Picker did not start")
  f:call({ "send-key", "-s", f.env.REX_SESSION, "-b", id, "escape" }); absent(f, "lazygit")
  H.equal(f:view().windows[1].focused_block_id, origin); assert(not H.read(f.lazygitLog))
end)
H.test("collector values reach shell argv unchanged, with multi-selection owned by the picker", function(t)
  local f = H.fixture(t, "lazygit")
  local log, marker = f.directory .. "/argv", f.directory .. "/must-not-exist"
  local items = { { value = "a space's value\nwith a newline", label = "First" },
    { value = "$(touch " .. marker .. ")", label = "Second" } }
  H.write(f.directory .. "/collect.lua", "return assert(rex.json.decode(" .. H.json(H.json(items)) .. "))\n")
  H.write(f.directory .. "/execute.sh", "#!/bin/sh\nprintf '%s\\0' \"$@\" > " .. H.quote(log) .. "\n")
  local entry = resolve(f, { directory = f.directory, entries = { { name = "args", collect = "collect.lua",
    picker = { multiple = true }, execute = "execute.sh" } } })
  local ui = launch(t, f, entry, f.directory)
  ui:expect("First"); ui:press(" \27[B "); ui:press("\r"); ui:done()
  H.equal(H.read(log), items[1].value .. "\0" .. items[2].value .. "\0")
  assert(not H.read(marker), "A collector value was interpreted as shell source")
end)
H.test("single-item collection skips fzf and passes context to a Lua executor", function(t)
  local f = H.fixture(t, "lazygit")
  local log = f.directory .. "/lua-result"
  H.write(f.directory .. "/collect.lua", "local ctx=...; return {{value=ctx.cwd,label='Current directory'}}\n")
  H.write(f.directory .. "/execute.lua", "local ctx,values=...; local file=assert(io.open(" .. H.json(log) ..
    ", 'w')); file:write(values[1] .. '\\n' .. ctx.name); file:close(); return 0\n")
  local entry = resolve(f, { directory = f.directory, entries = { { name = "lua", collect = "collect.lua", execute = "execute.lua" } } })
  f.env.REX_FLOATERS_FZF = "/missing-fzf"
  launch(t, f, entry, f.web):done()
  H.equal(H.read(log), f.web .. "\nlua")
end)
H.test("empty or malformed collections never execute; nonzero executor statuses are preserved", function(t)
  local f = H.fixture(t, "lazygit")
  local log = f.directory .. "/executed"
  for _, case in ipairs({ { source = "return {}", code = 0 }, { source = "return nil", code = 1 },
    { source = "return {[2]={value='x',label='X'}}", code = 1 },
    { source = "return {{value=42,label='X'}}", code = 1 } }) do
    H.write(f.directory .. "/collect.lua", case.source .. "\n")
    local entry = resolve(f, { directory = f.directory, entries = { { name = "invalid", collect = "collect.lua",
      execute = { "touch", log } } } })
    launch(t, f, entry, f.directory):done(case.code)
    assert(not H.read(log), "Executor ran without a valid selection")
  end
  local entry = resolve(f, { entries = { { name = "failure", execute = { "/bin/sh", "-c", "exit 7" } } } })
  launch(t, f, entry, f.directory):done(7)
  -- A running terminal must also close after a fast failure, rather than leave a dead shell.
  configure(f, { entries = { { name = "failure", execute = { "/bin/sh", "-c", "exit 7" } } } })
  action(f, "failure"); absent(f, "failure")
end)
dofile(directory .. "discovery.lua")(H, "lazygit")
dofile(directory .. "television.lua")(H)
package.path = H.root .. "/floaters/?.lua;" .. package.path
_G.H = H
dofile(directory .. "pluck/tokens.lua")
dofile(directory .. "pluck/window.lua")
dofile(directory .. "pluck/integration.lua")
H.finish()
