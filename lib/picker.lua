local U = dofile(debug.getinfo(1,"S").source:gsub("^@", ""):match("(.*/)") .. "util.lua")
local M = {}

local function fzf(title, choices, options)
  local toggle = options.multiple and "toggle" or 'transform(if [ "$FZF_SELECT_COUNT" = 1 ] && [ {n} = {+n} ]; then printf deselect; else printf clear-multi+select; fi)'
  local args = { "/bin/sh", "-c", 'exec "$@" 2>/dev/tty', "rex-fzf", os.getenv("REX_FLOATERS_FZF") or os.getenv("REX_HUNK_FZF") or "fzf",
    "--read0", "--print0", "--delimiter=\t", "--with-nth=2..", "--tiebreak=index", "--layout=reverse", "--border", "--prompt=Filter > ", "--with-shell=/bin/sh -c",
    "--header=" .. U.display(title) .. "\nSpace/Tab toggle · Enter continue · Esc cancel · Ctrl+X clear", "--no-mouse", options.multiple and "--multi" or "--multi=1",
    "--bind", "space:" .. toggle .. ",tab:" .. toggle .. "+down,btab:" .. toggle .. "+up,ctrl-space:put( ),ctrl-x:clear-multi" }
  local temporary
  local ok, result = pcall(function()
    if options.preview then
      temporary = U.trim(U.command({ "mktemp", "-d", U.join(os.getenv("TMPDIR") or "/tmp", "rex-hunk-preview.XXXXXXXX") }))
      local filename = U.join(temporary, "feedback.txt"); U.write(filename, options.preview:gsub("[%z\1-\8\11-\31\127]", ""))
      args[#args + 1] = "--preview"; args[#args + 1] = "/bin/cat " .. U.quote(filename); args[#args + 1] = "--preview-window=right:60%:wrap"
    end
    local rows = {}
    for i, choice in ipairs(choices) do rows[i] = (i - 1) .. "\t" .. U.display(choice.label) .. (choice.description and " — " .. U.display(choice.description) or "") end
    -- Only fzf's UI goes to the terminal; its NUL-delimited result stays in Lua. No pasted shell input.
    local r = U.checked(rex.exec(args, { stdin = table.concat(rows, "\0") .. "\0", env = { FZF_DEFAULT_OPTS = "", FZF_DEFAULT_OPTS_FILE = "" } }))
    if r.code == 1 or r.code == 130 then return nil end
    if not r.ok then error("fzf failed; no selection was applied. Install fzf or set REX_FLOATERS_FZF. " .. r.stderr, 0) end
    local picked, seen = {}, {}
    for _, row in ipairs(U.split(r.stdout, "\0")) do if row ~= "" then
      local index = tonumber(row:match("^(%d+)\t")); index = index and index + 1
      if not index or not choices[index] or rows[index] ~= row or seen[index] then error("The picker returned an invalid selection.", 0) end
      seen[index] = true; picked[#picked + 1] = choices[index].value
    end end
    if #picked == 0 then error("The picker returned an empty selection.", 0) end
    return picked
  end)
  if temporary then U.remove(temporary, true) end
  if not ok then error(result, 0) end
  return result
end

local function television(title, choices, options)
  if type(options.preview) ~= "string" then error("The Television picker needs a Lua preview script.", 0) end
  local temporary
  local ok, result = pcall(function()
    temporary = U.trim(U.command({ "mktemp", "-d", "/tmp/rex-floaters-tv.XXXXXXXX" }))
    local source = U.join(temporary, "choices.tsv")
    local state = U.join(temporary, "state.json")
    local rows, stored = {}, { choices = {} }
    for index, choice in ipairs(choices) do
      local id = index - 1
      rows[index] = id .. "\t" .. U.display(choice.label) .. (choice.description and " — " .. U.display(choice.description) or "")
      stored.choices[index] = { value = choice.value }
    end
    U.write(source, table.concat(rows, "\n") .. "\n")
    U.write_json(state, stored)

    -- Only an integer row index is expanded by tv into shell source; labels and values stay in files.
    local delimiter = "\t"
    local preview = U.quote(os.getenv("REX_FLOATERS_REX") or os.getenv("REX_HUNK_REX") or "rex") ..
      " --autostart=false do " .. U.quote(options.preview) .. " index={split:" .. delimiter .. ":0}"
    local tv = os.getenv("REX_FLOATERS_TV") or "tv"
    local preview_columns, preview_rows = 80, 30
    local sized, size = pcall(function()
      return U.checked(rex.block.call("com.superlogical.terminal", "size", { block_id = rex.block_id }))
    end)
    if sized then
      preview_columns = math.max(20, math.floor((tonumber(size.columns) or 150) * 0.55) - 4)
      preview_rows = math.max(8, (tonumber(size.rows) or 40) - 4)
    end
    local command = { "/bin/sh", "-c", 'exec "$@" </dev/tty 2>/dev/tty', "rex-tv", tv,
      "--source-command", "cat " .. U.quote(source), "--source-display={split:" .. delimiter .. ":-1}",
      "--source-output={split:" .. delimiter .. ":0}",
      "--preview-command", preview, "--preview-header=Tab layout", "--preview-size=55", "--layout=landscape",
      "--no-sort", "--no-remote", "--no-help-panel", "--input-header=" .. U.display(title), "--input-prompt=Filter > " }
    local r = U.checked(rex.exec(command, { env = { REX_FLOATERS_TV_STATE = state,
      REX_FLOATERS_TV_COLUMNS = tostring(preview_columns), REX_FLOATERS_TV_ROWS = tostring(preview_rows) } }))
    if r.code == 1 or r.code == 130 then return nil end
    if not r.ok then
      error("Television failed; no selection was applied. Install Television 0.15.9 or set REX_FLOATERS_TV. " .. tostring(r.stderr), 0)
    end
    local selected = U.trim(r.stdout)
    if selected == "" then return nil end
    if not selected:match("^%d+$") then error("Television returned an invalid selection.", 0) end
    local index = tonumber(selected) + 1
    if not index or index % 1 ~= 0 or not choices[index] then error("Television returned an unknown selection.", 0) end
    return { choices[index].value }
  end)
  if temporary then U.remove(temporary, true) end
  if not ok then error(result, 0) end
  return result
end

function M.choose(title, choices, options)
  options = options or {}
  if #choices == 0 then return nil end
  if options.backend == "tv" then return television(title, choices, options) end
  return fzf(title, choices, options)
end

function M.input(title, initial)
  io.write(title .. (initial and initial ~= "" and " [" .. U.display(initial) .. "]" or "") .. ": "); io.flush()
  local line = io.read("*l"); if not line then return nil end
  line = U.trim(line); return line ~= "" and line or initial or ""
end
function M.acknowledge(message)
  print(message)
  local tty = io.open("/dev/tty", "r"); if tty then tty:close(); M.input("Press Enter to close this menu") end
end
return M
