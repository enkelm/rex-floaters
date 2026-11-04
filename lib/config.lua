-- Definitions are data: they can be snapshotted into the popup's separate Lua process.
local directory = debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*/)")
local U = dofile(directory .. "util.lua")
local M = { directory = directory .. "../floaters" }
local default_bounds = { 0.05, 0.05, 0.9, 0.9 }
local previous = {}

local function reject(message) error("rex-floaters: " .. message, 0) end
local function fields(value, allowed, where)
  if type(value) ~= "table" then reject(where .. " must be a table") end
  for key in pairs(value) do
    if not allowed[key] then reject("unknown " .. where .. " option " .. tostring(key)) end
  end
end
local function text(value, where)
  if type(value) ~= "string" or not value:find("%S") or value:find("%z") then
    reject(where .. " must be a non-empty string without NUL bytes")
  end
  return value
end
local function array(value, where)
  if type(value) ~= "table" then reject(where .. " must be an array") end
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then reject(where .. " must be a dense array") end
    count = count + 1
  end
  for index = 1, count do if value[index] == nil then reject(where .. " must be a dense array") end end
  return count
end
local function bounds(value)
  if array(value, "bounds") ~= 4 then reject("bounds must contain exactly four coordinates") end
  local copy = {}
  for index = 1, 4 do
    local coordinate = value[index]
    if type(coordinate) ~= "number" or coordinate ~= coordinate or math.abs(coordinate) == math.huge then
      reject("bounds must contain four finite numbers")
    end
    copy[index] = coordinate
  end
  local x, y, width, height = unpack(copy)
  if x < 0 or y < 0 or width <= 0 or height <= 0 or x + width > 1 or y + height > 1 then
    reject("bounds must be a positive rectangle inside the normalized 0..1 window")
  end
  return copy
end
local function script(value, base, where, lua_only)
  local path = U.absolute(text(value, where), base)
  local extension = path:match("%.([^.]+)$")
  if extension ~= "lua" and (lua_only or (extension ~= "sh" and extension ~= "bash")) then
    reject(where .. (lua_only and " must be a .lua script" or " must be a .lua, .sh, or .bash script"))
  end
  local file, err = io.open(path, "r")
  if not file then reject(where .. ": " .. tostring(err)) end
  file:close()
  return path, extension
end
-- Catch reordered modifier chords as well as exact duplicates; Rex remains the key syntax authority.
local function chord(value)
  local aliases = { command = "cmd", control = "ctrl", option = "alt" }
  local sequence = {}
  for step in value:lower():gmatch("[^>]+") do
    local parts = {}
    for part in step:gmatch("[^+]+") do
      part = U.trim(part); parts[#parts + 1] = aliases[part] or part
    end
    table.sort(parts); sequence[#sequence + 1] = table.concat(parts, "+")
  end
  return table.concat(sequence, ">")
end
local function definition(value, name, base, defaults)
  fields(value, { name=true, title=true, binding=true, bounds=true, zoom=true, collect=true, picker=true,
    execute=true, category=true, description=true, keywords=true }, "entry")
  name = value.name or name
  if type(name) ~= "string" or not name:match("^[a-z][a-z0-9_]*$") then
    reject("entry name must start with a lowercase letter and contain only lowercase letters, digits, and underscores")
  end
  local entry = { name = name, directory = base, title = value.title == nil and name or text(value.title, "title"),
    bounds = bounds(value.bounds == nil and defaults or value.bounds), binding = false,
    picker = { multiple = false, skip_single = true, backend = "fzf" }, zoom = false }
  if value.zoom ~= nil then
    if type(value.zoom) ~= "boolean" then reject("zoom must be a boolean") end
    entry.zoom = value.zoom
  end
  if value.binding ~= nil and value.binding ~= false then entry.binding = text(value.binding, "binding") end
  for _, key in ipairs({ "category", "description", "keywords" }) do
    if value[key] ~= nil then entry[key] = text(value[key], key) end
  end
  if value.collect ~= nil then entry.collect = script(value.collect, base, "collect", true) end
  if value.picker ~= nil then
    fields(value.picker, { multiple=true, skip_single=true, title=true, backend=true, preview=true }, "picker")
    for _, key in ipairs({ "multiple", "skip_single" }) do
      if value.picker[key] ~= nil then
        if type(value.picker[key]) ~= "boolean" then reject("picker." .. key .. " must be a boolean") end
        entry.picker[key] = value.picker[key]
      end
    end
    if value.picker.title ~= nil then entry.picker.title = text(value.picker.title, "picker.title") end
    if value.picker.backend ~= nil then
      if value.picker.backend ~= "fzf" and value.picker.backend ~= "tv" then
        reject("picker.backend must be 'fzf' or 'tv'")
      end
      entry.picker.backend = value.picker.backend
    end
    if value.picker.preview ~= nil then
      if entry.picker.backend ~= "tv" then reject("picker.preview requires picker.backend = 'tv'") end
      entry.picker.preview = script(value.picker.preview, base, "picker.preview", true)
    end
    if entry.picker.backend == "tv" and not entry.picker.preview then
      reject("picker.preview is required when picker.backend = 'tv'")
    end
    if entry.picker.backend == "tv" and entry.picker.multiple then
      reject("picker.backend = 'tv' does not support multiple selections")
    end
  end
  if type(value.execute) == "table" then
    local count = array(value.execute, "execute")
    if count == 0 then reject("execute must name a command") end
    local argv = {}
    for index = 1, count do
      local argument = value.execute[index]
      if type(argument) ~= "string" or argument:find("%z") then reject("execute arguments must be strings without NUL bytes") end
      argv[index] = argument
    end
    text(argv[1], "execute command")
    entry.execute = { kind = "command", argv = argv }
  else
    local path, extension = script(value.execute, base, "execute", false)
    entry.execute = { kind = extension, path = path }
  end
  return entry
end

function M.resolve(options)
  options = options == nil and {} or options
  fields(options, { directory=true, entries=true, bounds=true }, "setup")
  local base = options.directory == nil and M.directory or text(options.directory, "directory")
  if base:sub(1, 1) ~= "/" and base:sub(1, 2) ~= "~/" then reject("directory must be an absolute path or start with ~/") end
  base = U.absolute(base)
  local defaults = bounds(options.bounds == nil and default_bounds or options.bounds)
  local entries = {}
  if options.entries ~= nil then
    for index = 1, array(options.entries, "entries") do
      entries[#entries + 1] = definition(options.entries[index], nil, base, defaults)
    end
  else
    local result, err = rex.exec({ "find", "-L", base, "-mindepth", "2", "-maxdepth", "2", "-name", "init.lua", "-type", "f", "-print0" })
    if not result or not result.ok then reject("cannot discover definitions in " .. base .. ": " .. tostring(err or result.stderr)) end
    local paths = U.split(result.stdout, "\0"); table.sort(paths)
    for _, path in ipairs(paths) do
      if path ~= "" then
        local parent = U.dirname(path)
        local name = U.basename(parent)
        local ok, value = pcall(dofile, path)
        if not ok then reject(path .. ": " .. tostring(value)) end
        if type(value) == "table" and value.name ~= nil and value.name ~= name then reject(path .. ": name must match its directory") end
        entries[#entries + 1] = definition(value, name, parent, defaults)
      end
    end
  end
  local names, keys = {}, {}
  for _, entry in ipairs(entries) do
    if names[entry.name] then reject("duplicate entry name " .. entry.name) end
    names[entry.name] = true
    if entry.binding then
      local key = chord(entry.binding)
      if keys[key] then reject("binding for " .. entry.name .. " conflicts with " .. keys[key]) end
      keys[key] = entry.name
    end
  end
  return entries
end

function M.apply(options, register)
  local entries = M.resolve(options) -- Validate every definition before changing registration.
  for key, action in pairs(previous) do rex.unbind(key, action) end
  register(entries)
  local current = {}
  for _, entry in ipairs(entries) do
    if entry.binding then
      local action = "floaters_" .. entry.name .. "_toggle"
      rex.bind(entry.binding, action); current[entry.binding] = action
    end
  end
  previous = current
end
return M
