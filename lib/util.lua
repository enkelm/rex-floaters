-- Shared Rex Lua helpers. No standalone Lua/Node interpreter or FFI modules are needed.
local M = {}
M.directory = debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*/)")
function M.checked(value, err) if value == nil then error(err or "Rex call failed", 0) end; return value end
function M.trim(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end
function M.copy(value) local out = {}; for k, v in pairs(value or {}) do out[k] = v end; return out end
function M.extend(value, extra) local out = M.copy(value); for k, v in pairs(extra or {}) do out[k] = v end; return out end
function M.array(value) return setmetatable(value or {}, { array = true }) end
function M.contains(values, value) for _, v in ipairs(values or {}) do if v == value then return true end end; return false end
function M.filter(values, fn) local out = M.array(); for i, v in ipairs(values or {}) do if fn(v, i) then out[#out + 1] = v end end; return out end
function M.map(values, fn) local out = M.array(); for i, v in ipairs(values or {}) do out[#out + 1] = fn(v, i) end; return out end
function M.split(text, separator)
  local out, start = M.array(), 1
  while true do local at = text:find(separator, start, true); if not at then out[#out + 1] = text:sub(start); break end
    out[#out + 1] = text:sub(start, at - 1); start = at + #separator end
  return out
end
function M.join(...) return (table.concat({...}, "/"):gsub("/+", "/")) end
function M.dirname(value) return value:match("^(.*)/[^/]+/?$") or "." end
function M.basename(value) return value:gsub("/+$", ""):match("([^/]+)$") end
function M.absolute(value, cwd)
  if value == "~" or value:sub(1, 2) == "~/" then value = os.getenv("HOME") .. value:sub(2) end
  if value:sub(1, 1) ~= "/" then value = M.join(cwd or M.trim(M.command({"pwd"})), value) end
  local parts = {}; for part in value:gmatch("[^/]+") do if part == ".." then table.remove(parts) elseif part ~= "." then parts[#parts + 1] = part end end
  return "/" .. table.concat(parts, "/")
end
function M.inside(root, value) return value == root or value:sub(1, #root + 1) == root .. "/" end
function M.quote(text) return "'" .. tostring(text):gsub("'", "'\\''") .. "'" end
function M.display(value)
  return tostring(value or ""):gsub("[%z\1-\31\127]", " "):gsub("\194[\128-\159]", " "):gsub("\226\128[\170-\174]", " "):gsub("\226\129[\166-\169]", " ")
end
function M.run(argv, opts) return M.checked(rex.exec(argv, M.extend({ timeout = 15 }, opts))) end
function M.command(argv, opts)
  local r = M.run(argv, opts); if not r.ok then error(argv[1] .. ": " .. M.trim(r.stderr ~= "" and r.stderr or r.stdout) .. (r.timed_out and " (timed out)" or ""), 0) end
  return r.stdout
end
function M.start(argv, opts) return M.checked(rex.exec.start(argv, M.extend({timeout = 15}, opts))) end
function M.real(value) return M.trim(M.command({"realpath", value})) end
function M.now() return os.date("!%Y-%m-%dT%H:%M:%SZ") end
local pid, serial = nil, 0
function M.pid() if not pid then pid = M.checked(rex.call("server.whoami")).principal.pid; assert(pid, "Rex did not report this local script's PID") end; return pid end
function M.uuid() return M.trim(M.command({"uuidgen"})):lower() end
function M.digest(text) return assert(M.command({"openssl", "dgst", "-sha256"}, {stdin = text}):match("([a-fA-F0-9]+)%s*$")):lower() end
function M.mkdir(directory) M.command({"mkdir", "-p", "-m", "700", directory}) end
function M.remove(filename, recursive) M.command({"rm", recursive and "-rf" or "-f", "--", filename}) end
function M.exists(filename) return M.run({"test", "-e", filename}).ok end
function M.read(filename)
  local file, err, code = io.open(filename, "rb"); if not file then if code == 2 or tostring(err):find("no such file or directory", 1, true) then return nil end; error(err, 0) end
  local data = file:read("*a"); file:close(); return data
end
-- Rex's encoder emits {} for empty tables. Preserve empty lists in the persisted wire format.
local lists = {comments=true, paths=true, args=true, oldRange=true, newRange=true}
function M.encode(value, pretty, depth, key)
  if type(value) ~= "table" then if value == nil then return "null" end; return M.checked(rex.json.encode(value)) end
  depth = depth or 0
  local array = #value > 0 or (getmetatable(value) or {}).array or lists[key]
  local keys = {}; if array then for i = 1, #value do keys[#keys + 1] = i end else for k in pairs(value) do keys[#keys + 1] = k end; table.sort(keys) end
  local parts = {}; for _, k in ipairs(keys) do
    parts[#parts + 1] = (pretty and string.rep("  ", depth + 1) or "") .. (array and "" or M.encode(k) .. (pretty and ": " or ":")) .. M.encode(value[k], pretty, depth + 1, k)
  end
  local first, last = array and "[" or "{", array and "]" or "}"
  if #parts == 0 then return first .. last end
  return first .. (pretty and "\n" or "") .. table.concat(parts, pretty and ",\n" or ",") .. (pretty and "\n" .. string.rep("  ", depth) or "") .. last
end
function M.decode(text) return M.checked(rex.json.decode(text)) end
function M.read_json(filename, fallback) local text = M.read(filename); if not text then return fallback end; return M.decode(text) end
function M.write(filename, text)
  M.mkdir(M.dirname(filename)); serial = serial + 1
  local temporary = filename .. "." .. M.pid() .. "." .. serial .. ".tmp"
  local ok, err = pcall(function()
    -- Create privately before writing tokens or feedback, not with a later chmod.
    M.command({"/bin/sh", "-c", 'umask 077; set -C; : > "$1"', "rex-private", temporary})
    local file = assert(io.open(temporary, "wb")); assert(file:write(text)); assert(file:close()); assert(os.rename(temporary, filename))
  end)
  if not ok then M.remove(temporary); error(err, 0) end
end
function M.write_json(filename, value) M.write(filename, M.encode(value, true) .. "\n") end
function M.entries(directory)
  local r = M.checked(rex.block.call("com.superlogical.terminal", "list_dir", { path=directory, files=true, limit=10000 }))
  if r.status == "missing" then return {} end
  if r.status ~= "ok" or r.truncated then error("Cannot list " .. directory .. ": " .. r.status .. (r.truncated and " (too many entries)" or ""), 0) end
  table.sort(r.entries, function(a,b) return a.name < b.name end); return r.entries
end
function M.lock(directory, fn, wait)
  local deadline = os.time() + (wait or 0)
  while not M.run({"mkdir", "-m", "700", directory}).ok do
    if not wait or os.time() >= deadline then error("Review/delivery lock exists at " .. directory .. ". Saved data was kept; retry after the owner stops.", 0) end
    rex.sleep(0.05)
  end
  local ok, result = pcall(fn); M.remove(directory, true); if not ok then error(result, 0) end; return result
end
function M.parallel(values, start, finish)
  local out = M.array()
  for offset = 1, #values, 4 do
    local handles = {}; for i = offset, math.min(#values, offset + 3) do handles[i] = start(values[i], i) end
    for i = offset, math.min(#values, offset + 3) do out[i] = finish(handles[i], values[i], i) end
  end
  return out
end
return M
