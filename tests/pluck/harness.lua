-- Pluck-specific fixtures share Floaters' isolated servers and PTY transport.
return function(Base)
  local H = setmetatable({}, { __index = Base })
  function H.fixture(test)
    local f = Base.fixture(test, "lazygit")
    f.root, f.rexbin, f.server_address = Base.root, f.rex, f.env.REX_SERVER
    function f:new_session(content)
      local command = type(content) == "table" and content.command or ("printf '%s' " .. H.quote(content) .. "; exec sleep 60")
      local created = self:json({ "new", "pluck-fixture", "-c", self.directory, "--shell=none", "--json", "--", "/bin/sh", "-c", command })
      self.session, self.source = created.session_id, created.initial_windows[1].block_ids[1]
      self.env.REX_SESSION, self.env.REX_BLOCK = self.session, self.source
      self.window = self:view().windows[1].window_id
    end
    function f:script(source) return self:json({ "do", "-e", source }) end
    function f:popup(previous_zoom)
      self.origin = { session_id = self.session, block_id = self.source, window_id = self.window,
        zoomed_block_id = previous_zoom or "", server_id = self:json({ "server", "status", "--json" }).instance_id }
      local created = self:json({ "api", "call", "session.new_layer", H.json({ session_id = self.session,
        window_id = self.window, bounds = { 0, 0, 1, 1 }, focus = false, layout = { block = {
          flavor = "com.superlogical.terminal.shell", label = "rex-floaters:pluck", options = {
            command = { "/bin/sh", "-c", "exec sleep 60" },
          },
        } } }) })
      self.popup_block = created.block_ids[1]
      self:call({ "zoom", "-s", self.session, self.popup_block, "--on" })
      self.env.REX_BLOCK = self.popup_block
      return created
    end
    function f:entry()
      local entry = self:script("return dofile(" .. H.json(H.root .. "/lib/config.lua") .. ").resolve{entries={{" ..
        "name='pluck',zoom=true,execute='pluck/execute.lua'}}}[1]")
      entry.origin = self.origin
      return entry
    end
    return f
  end
  function H.terminal(test, fixture, options)
    options = options or {}
    local ui = Base.terminal(test, fixture, { "/bin/sh", H.root .. "/launch.sh", H.json({ entry = fixture:entry(),
      window = fixture.window, focus = fixture.source, zoom = fixture.origin.zoomed_block_id }) }, fixture.directory,
      { ROWS = options.rows or 14, COLUMNS = options.columns or 100, NARROW_ROWS = 4, NARROW_COLUMNS = 12 })
    function ui:copies()
      local values = {}
      for encoded in self:output():gmatch("\27%]52;c;([^\7]*)\7") do values[#values + 1] = encoded end
      return values
    end
    function ui:frame()
      local output = self:output()
      local first = output:match("^.*()\27%[%?2026h")
      local last = output:find("\27%[%?2026l", first or 1, false)
      local raw = first and last and output:sub(first, last + #"\27[?2026l" - 1) or ""
      local painted, row, cursor = {}, 1, 1
      while cursor <= #raw do
        if raw:sub(cursor, cursor + 1) == "\27[" then
          local finish = cursor + 2
          while finish <= #raw do
            local byte = raw:byte(finish)
            finish = finish + 1
            if byte >= 0x40 and byte <= 0x7E then break end
          end
          local part = raw:sub(cursor, finish - 1)
          if part == "\27[2J" then painted = {}
          else
            local target = part:match("^\27%[(%d+);%d+H$") or part:match("^\27%[(%d*)H$")
            if target then row = tonumber(target) or 1 end
          end
          cursor = finish
        elseif raw:sub(cursor, cursor) == "\27" then
          local bell = raw:find("\7", cursor + 1, true)
          local st = raw:find("\27\\", cursor + 1, true)
          local finish = bell and (not st or bell < st) and bell or st
          cursor = finish and (finish + (finish == bell and 1 or 2)) or #raw + 1
        elseif raw:sub(cursor, cursor + 1) == "\r\n" then
          row = row + 1; cursor = cursor + 2
        else
          local finish = raw:find("\27", cursor, true) or raw:find("\r\n", cursor, true) or (#raw + 1)
          painted[row] = (painted[row] or "") .. raw:sub(cursor, finish - 1)
          cursor = finish
        end
      end
      local lines = {}
      for index = 1, 100 do if painted[index] ~= nil then lines[#lines + 1] = { row = index, text = painted[index] } end end
      return { raw = raw, rows = lines }
    end
    local done = ui.done
    function ui:done(code)
      done(self, code)
      H.contains(self:output(), "PTY_RESTORED=True")
      H.equal(fixture:view().windows[1].focused_block_id, fixture.source)
      fixture:no_node()
    end
    return ui
  end
  return H
end
