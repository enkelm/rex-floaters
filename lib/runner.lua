-- The runner owns selection, terminal I/O, and exit status; collectors only return data.
local directory = debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*/)")
local U, Picker = dofile(directory .. "util.lua"), dofile(directory .. "picker.lua")
local M = {}
local function invoke(path, ctx, values)
  local chunk, err = loadfile(path)
  if not chunk then error(err, 0) end
  return chunk(ctx, values)
end
local function choices(items)
  if type(items) ~= "table" then error("Collector must return an array of {value, label} items.", 0) end
  local count = 0
  for key in pairs(items) do
    if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then error("Collector must return a dense array.", 0) end
    count = count + 1
  end
  for index = 1, count do
    local item = items[index]
    if type(item) ~= "table" or type(item.value) ~= "string" or item.value:find("%z") or
      type(item.label) ~= "string" or not item.label:find("%S") or item.label:find("%z") or
      (item.description ~= nil and type(item.description) ~= "string") then
      error("Collector item " .. index .. " must have a string value and non-empty label, with no NUL bytes.", 0)
    end
  end
  return items
end
local function status(result)
  if result == nil then return 0 end
  local code = type(result) == "table" and result.code or result
  if type(code) ~= "number" or code % 1 ~= 0 or code < -1 or code > 255 then
    error("Lua executor must return nothing, an exit status (0..255), or a ctx.exec result.", 0)
  end
  return code == -1 and 1 or code
end
function M.run(entry)
  local ctx = { name = entry.name, directory = entry.directory, cwd = U.trim(U.command({ "pwd" })), origin = entry.origin }
  function ctx.exec(argv, options)
    if type(argv) ~= "table" or #argv == 0 then error("ctx.exec expects a program and its arguments.", 0) end
    -- Never interpolate values into shell source. A captured rex.exec isn't otherwise a TUI.
    local command = { "/bin/sh", "-c", 'exec "$@" </dev/tty >/dev/tty 2>/dev/tty', "rex-floaters" }
    for _, argument in ipairs(argv) do command[#command + 1] = argument end
    return U.checked(rex.exec(command, U.extend({ cwd = ctx.cwd }, options)))
  end
  local values = {}
  if entry.collect then
    local items = choices(invoke(entry.collect, ctx))
    if #items == 0 then print(entry.title .. ": no items found."); return 0 end
    if #items == 1 and entry.picker.skip_single then values = { items[1].value }
    else
      values = Picker.choose(entry.picker.title or entry.title, items, entry.picker, ctx)
      if not values then return 0 end
    end
  end
  local executor = entry.execute
  if executor.kind == "lua" then return status(invoke(executor.path, ctx, values)) end
  local argv = {}
  if executor.kind == "command" then
    for _, argument in ipairs(executor.argv) do argv[#argv + 1] = argument end
  else
    argv = { executor.kind == "bash" and "/bin/bash" or "/bin/sh", executor.path }
  end
  for _, value in ipairs(values) do argv[#argv + 1] = value end
  return status(ctx.exec(argv))
end
return M
