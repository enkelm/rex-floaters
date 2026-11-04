-- Each sample starts the shipping launcher in a fresh Rex/Lua process. No preloaded Pluck modules.
local directory = debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*/)")
local H = dofile(directory .. "../harness.lua")
local P = dofile(directory .. "harness.lua")(H)
local budget = tonumber(os.getenv("REX_FLOATERS_COLD_BUDGET_MS")) or 750

for _, size in ipairs({ { 120, 40 }, { 240, 80 }, { 240, 80, mixed = true }, { 240, 80, mixed = true, history = true } }) do
  local label = size[1] .. "x" .. size[2] .. (size.mixed and " mixed Unicode" or " ASCII") ..
    (size.history and " + 1,000 history rows" or "")
  H.test("Pluck cold first frame " .. label, function(t)
    local f = P.fixture(t)
    local columns, rows = size[1], size[2]
    local lines = {}
    for index = 1, rows - 2 do
      local text = string.format("line %03d https://example.test/%03d /tmp/project/src/file_%03d.lua deadbeef 192.168.0.1:3000 ", index, index, index)
      local prefix = size.mixed and "界 é 👩‍💻 " or ""
      lines[index] = prefix .. text .. string.rep("x", math.max(0, columns - #text - (size.mixed and 8 or 0) - 1))
    end
    local content = table.concat(lines, "\r\n") .. "\r\nBENCH_READY\r\n"
    if size.history then
      local history = {}
      for index = 1, 1000 do
        history[index] = "\27[32m界 é 👩‍💻 /tmp/history/old.lua " .. string.rep("x", 190) .. "\27[0m\r\n"
      end
      local file = f.directory .. "/synthetic-source.txt"
      H.write(file, table.concat(history) .. content)
      f:new_session({ command = "/bin/cat " .. H.quote(file) .. "; exec sleep 60" })
    else
      f:new_session(content)
    end
    H.wait(function() return f:capture(f.source):find("BENCH_READY", 1, true) end, "Source did not finish printing")
    local popup = f:popup()
    -- Keep a desktop-sized source viewport; a one-shot resize loses to the existing owner's size.
    local ready = f.directory .. "/owner-ready"
    local script = "assert(rex.session.own_block{block_ids={rex.block_id}}); " ..
      "assert(rex.block.call('com.superlogical.terminal','resize',{block_id=rex.block_id,columns=" .. columns .. ",rows=" .. rows .. "})); " ..
      "local f=assert(io.open(" .. H.json(ready) .. ",'w'));f:write('ready');f:close();rex.sleep(120)"
    local owner = assert(rex.exec.start({ f.rexbin, "--server", f.server_address, "--autostart=false",
      "do", "-s", f.session, "-b", f.source, "-e", script }, { env = f.env, stdout = false }))
    t:after(function() if owner:running() then owner:kill() end; owner:wait(10) end)
    H.wait(function()
      if not owner:running() then error(assert(owner:wait(1)).stderr, 0) end
      return H.read(ready) == "ready"
    end, "Source owner did not resize the benchmark terminal")
    local entry = f:entry()
    local times = {}
    for sample = 1, 3 do
      local before = os.clock()
      local ui = H.terminal(t, f, { "/bin/sh", H.root .. "/launch.sh", H.json({ entry = entry,
        window = f.window, focus = f.source, zoom = "" }) }, f.directory, { ROWS = rows, COLUMNS = columns })
      H.wait(function() return ui:output():find("\27[?2026l", 1, true) end, "No complete first frame", 30)
      times[sample] = (os.clock() - before) * 1000
      assert(ui:output():find(((rows - 2) * 2 + 2) .. " tokens", 1, true), "The benchmark must retain all unique copy targets")
      ui:press("\27"); ui:done()
      assert(not ui:output():find("\27]52;", 1, true), "Benchmark cancellation must not write a clipboard")
      f:call({ "api", "call", "session.set_layer_state", H.json({ session_id = f.session,
        layer_id = popup.layer_id, state = "normal", focus = true }) })
      f:call({ "zoom", "-s", f.session, f.popup_block, "--on" })
    end
    print(string.format("%s cold first-frame ms: %.1f, %.1f, %.1f", label, times[1], times[2], times[3]))
    table.sort(times)
    assert(times[2] <= budget, string.format("Cold median %.1f ms exceeds %.1f ms budget", times[2], budget))
    f:no_node()
  end)
end
H.finish()
