return function(H)
  local function entry(f)
    return f:json({ "do", "-e", "local C=dofile(" .. H.json(H.root .. "/lib/config.lua") .. "); " ..
      "for _,item in ipairs(C.resolve()) do if item.name=='rex' then return item end end; error('Missing bundled Rex picker')" })
  end
  local function find_block(view, id)
    for _, window in ipairs(view.windows or {}) do
      for _, layer in ipairs(window.layers or {}) do
        for _, block in ipairs(layer.blocks or {}) do
          if block.block_id == id then return window end
        end
      end
    end
  end
  local function start_picker(t, f, origin, definition)
    f:call({ "focus", "-s", f.env.REX_SESSION, origin })
    local window = assert(find_block(f:json({ "session", "inspect", f.env.REX_SESSION, "--json" }), origin))
    local config = {}
    for key, value in pairs(definition) do config[key] = value end
    config.origin = { session_id = f.env.REX_SESSION, window_id = window.window_id, block_id = origin }
    local args = H.json({ entry = config, window = window.window_id, focus = origin, zoom = "" })
    return H.terminal(t, f, { "/bin/sh", H.root .. "/launch.sh", args }, f.directory)
  end
  local function origin_pane(f)
    local origin = f:json({ "split", "-s", f.env.REX_SESSION, "-b", f.env.REX_BLOCK,
      "--shell=none", "--json", "--", "/bin/sh", "-c", "while :; do sleep 60; done" }).block_ids[1]
    f:call({ "block", "rename", "-s", f.env.REX_SESSION, origin, "TV_ORIGIN" })
    f:call({ "focus", "-s", f.env.REX_SESSION, origin })
    return origin
  end
  local function target_window(f, label, content)
    local command = content or "printf 'TV_TARGET_SCREEN\\n'; while :; do sleep 60; done"
    local created = f:json({ "window", "new", "-s", f.env.REX_SESSION, "Television destination", "--shell=none", "--json",
      "--", "/bin/sh", "-c", command })
    local target = created.block_ids[1]
    f:call({ "block", "rename", "-s", f.env.REX_SESSION, target, label })
    return target, created.window_id
  end
  local function wait_for_ui(f, id, text)
    local ok, err = pcall(H.wait, function() return f:capture(id):find(text, 1, true) end,
      "Television did not display " .. text)
    if not ok then error(tostring(err) .. ". Terminal: " .. f:capture(id), 0) end
  end
  local function choose(ui, text)
    ui:press(text)
    ui:expect(text)
  end
  local function selected(view, block)
    for _, window in ipairs(view.windows or {}) do
      if window.window_id == view.active_window_id and window.focused_block_id == block then return true end
    end
    return false
  end

  H.test("Television previews every split in the selected tab with color and focuses its remembered pane", function(t)
    if not H.which("tv") then t:skip("Television is not installed") end
    local f = H.fixture(t, "lazygit")
    f.env.REX_FLOATERS_FZF = "/missing-fzf"
    local origin = origin_pane(f)
    local target, target_window_id = target_window(f, "TV_DESTINATION",
      "printf 'TV_OLD_SCROLLBACK_MARKER\\n'; i=0; while [ $i -lt 120 ]; do printf 'old-%s\\n' \"$i\"; i=$((i+1)); done; printf '\\033[31mTV_RED_MARKER\\033[0m\\n'; while :; do sleep 60; done")
    local sibling = f:json({ "split", "-s", f.env.REX_SESSION, "-b", target, "--split=right", "--shell=none", "--json", "--",
      "/bin/sh", "-c", "printf '\\033[?1049h\\033[2J\\033[H\\033[38;2;12;200;90mTV_GREEN_SPLIT\\033[0m\\033[5;3HTV_FULLSCREEN_BODY'; while :; do sleep 60; done" }).block_ids[1]
    f:call({ "block", "rename", "-s", f.env.REX_SESSION, sibling, "TV_SECOND_SPLIT" })
    f:call({ "focus", "-s", f.env.REX_SESSION, target })
    f:call({ "focus", "-s", f.env.REX_SESSION, origin })
    local ui = start_picker(t, f, origin, entry(f))
    ui:expect("Rex tabs"); ui:expect("CURRENT"); ui:expect("Television destination")
    choose(ui, "Television destination")
    ui:expect("TV_RED_MARKER"); ui:expect("TV_GREEN_SPLIT")
    local output = ui:output()
    assert(not output:find("TV_OLD_SCROLLBACK_MARKER", 1, true), "Preview included old scrollback instead of the visible screen")
    local marker = assert(output:find("TV_RED_MARKER", 1, true))
    local last_style
    for style in output:sub(math.max(1, marker - 160), marker - 1):gmatch("\27%[[0-9;]*m") do last_style = style end
    H.equal(last_style, "\27[38;5;1;49m", "Television stripped the pane's red foreground")
    local row, column
    for r, c in output:sub(1, marker - 1):gmatch("\27%[(%d+);(%d+)H") do row, column = r, c end
    assert(column and tonumber(column) > 60, "Television preview was not laid out on the right")
    ui:press("\r")
    ui:done()
    H.wait(function() return selected(f:view(), target) end, "Television selection did not focus the tab's remembered pane")
    H.equal(f:view().active_window_id, target_window_id)
  end)

  H.test("Television cancellation leaves focus unchanged and stale choices do not steal focus", function(t)
    if not H.which("tv") then t:skip("Television is not installed") end
    local f = H.fixture(t, "lazygit")
    f.env.REX_FLOATERS_FZF = "/missing-fzf"
    local origin = origin_pane(f)
    target_window(f, "TV_CANCEL_TARGET")
    local ui = start_picker(t, f, origin, entry(f))
    ui:expect("Rex tabs"); ui:expect("TV_CANCEL_TARGET")
    ui:press("\27")
    ui:done()
    H.wait(function() return selected(f:view(), origin) end, "Cancellation changed the focused pane")

    local target = target_window(f, "TV_DISAPPEARING")
    ui = start_picker(t, f, origin, entry(f))
    ui:expect("TV_DISAPPEARING")
    choose(ui, "TV_DISAPPEARING")
    f:call({ "block", "close", "-s", f.env.REX_SESSION, target })
    ui:press("\r")
    ui:done()
    H.wait(function() return selected(f:view(), origin) end, "A pane that disappeared during selection stole focus")
  end)

  H.test("The Television floater excludes itself and closes cleanly on Escape", function(t)
    if not H.which("tv") then t:skip("Television is not installed") end
    local f = H.fixture(t, "lazygit")
    f.env.REX_FLOATERS_FZF = "/missing-fzf"
    local origin = origin_pane(f)
    target_window(f, "TV_SELF_TEST")
    f:call({ "focus", "-s", f.env.REX_SESSION, origin })
    f:json({ "do", "floaters_rex_toggle", "-s", f.env.REX_SESSION, "-b", origin })
    local picker
    H.wait(function()
      for _, window in ipairs(f:view().windows or {}) do
        for _, layer in ipairs(window.layers or {}) do
          if layer.kind == "floating" then
            for _, block in ipairs(layer.blocks or {}) do
              if block.label == "rex-floaters:rex" then picker = block.block_id; return true end
            end
          end
        end
      end
    end, "Rex tab picker floater did not open")
    wait_for_ui(f, picker, "Rex tabs")
    local loaded, screen = pcall(H.wait, function()
      local capture = f:capture(picker)
      if capture:find("1 / 2", 1, true) then return capture end
    end, "Television did not load the two available tabs")
    if not loaded then error(tostring(screen) .. ". Terminal: " .. f:capture(picker), 0) end
    assert(not screen:find("rex-floaters:rex", 1, true), "The Television floater listed its own terminal")
    f:call({ "send-key", "-s", f.env.REX_SESSION, "-b", picker, "escape" })
    H.wait(function()
      for _, window in ipairs(f:view().windows or {}) do
        for _, layer in ipairs(window.layers or {}) do
          for _, block in ipairs(layer.blocks or {}) do if block.block_id == picker then return false end end
        end
      end
      return true
    end, "Escape did not close the Television floater")
    H.wait(function() return selected(f:view(), origin) end, "Escape did not restore the pane that opened the picker")
  end)

  H.test("Television lists and focuses a tab in another Rex session", function(t)
    if not H.which("tv") then t:skip("Television is not installed") end
    local f = H.fixture(t, "lazygit")
    f.env.REX_FLOATERS_FZF = "/missing-fzf"
    local origin = origin_pane(f)
    local other = f:json({ "new", "TV cross-session", "-c", f.directory, "--shell=none", "--json", "--",
      "/bin/sh", "-c", "printf 'TV_CROSS_SESSION_SCREEN\\n'; while :; do sleep 60; done" })
    local target = other.initial_windows[1].block_ids[1]
    f:call({ "block", "rename", "-s", other.session_id, target, "TV_CROSS_SESSION" })
    local ui = start_picker(t, f, origin, entry(f))
    ui:expect("Rex tabs"); ui:expect("TV_CROSS_SESSION")
    choose(ui, "TV_CROSS_SESSION")
    ui:press("\r")
    ui:done()
    local view = f:json({ "session", "inspect", other.session_id, "--json" })
    H.wait(function() return selected(f:json({ "session", "inspect", other.session_id, "--json" }), target) end,
      "Cross-session selection did not focus its exact destination")
    H.equal(view.session_id, other.session_id)
  end)
end
