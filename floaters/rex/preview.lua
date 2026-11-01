local directory = debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*/)")
local Render = dofile(directory .. "render.lua")
local state_path = os.getenv("REX_FLOATERS_TV_STATE")
local own_prefix = "rex-floaters:"
local terminal = "com.superlogical.terminal"
local index = tonumber(rex.args.index)

local function call(method, args)
  local result, err = rex.call(method, args)
  if result == nil then error(err or ("Rex call failed: " .. method), 0) end
  return result
end
local function owned(block)
  return (block.label or ""):sub(1, #own_prefix) == own_prefix
end
local function display(value, fallback)
  value = type(value) == "string" and value:match("%S") and value or fallback
  return value:gsub("[%z\1-\31\127]", " "):gsub("\194[\128-\159]", " ")
    :gsub("\226\128[\170-\174]", " "):gsub("\226\129[\166-\169]", " ")
end
local function block(session_id, block_id, method, args)
  return call("block.method", { session_id = session_id, block_id = block_id, method = method, args = args })
end

local function capture(session_id, pane)
  if pane.block.creator_name ~= terminal then
    return { Render.text_cells("(" .. display(pane.block.creator_name, "non-terminal pane") .. ")", "\27[38;5;8m") }
  end
  local size = block(session_id, pane.block.block_id, "size")
  local rows = math.max(1, math.min(1000, tonumber(size.rows) or 24))
  local columns = math.max(1, math.min(5000, tonumber(size.columns) or 80))
  local budget = math.min(983040, math.max(65536, rows * columns * 128))
  local formatted = block(session_id, pane.block.block_id, "format", { format = "html", trim = true, max_bytes = 1 })
  local content = formatted.content or ""
  if formatted.id then
    local offset = math.max(0, (formatted.total or 0) - budget)
    local tail = block(session_id, pane.block.block_id, "blob_read",
      { id = formatted.id, offset = offset, max_bytes = budget })
    content = tail.data or ""
    if offset > 0 then
      local newline = content:find("\n", 1, true)
      content = newline and content:sub(newline + 1) or ""
    end
  end
  local lines = Render.html_lines(content)
  while #lines > rows do table.remove(lines, 1) end
  if #lines == 0 then lines[1] = Render.text_cells("(pane screen is empty)", "\27[38;5;8m") end
  return lines
end

local function preview()
  if not state_path or not index or index % 1 ~= 0 or index < 0 then error("Tab preview is unavailable.", 0) end
  local file = assert(io.open(state_path, "rb"))
  local encoded = file:read("*a"); file:close()
  local state = assert(rex.json.decode(encoded))
  local choice = state.choices and state.choices[index + 1]
  if not choice or type(choice.value) ~= "string" then error("Tab preview is unavailable.", 0) end
  local target = assert(rex.json.decode(choice.value))
  if type(target.session_id) ~= "string" or type(target.window_id) ~= "string" or
    type(target.block_id) ~= "string" then error("Tab preview is unavailable.", 0) end

  call("session.attach", { session_id = target.session_id })
  local view = call("session.view", { session_id = target.session_id })
  local selected_window
  for _, window in ipairs(view.windows or {}) do if window.window_id == target.window_id then selected_window = window; break end end
  if not selected_window then error("Tab preview is unavailable.", 0) end

  local panes, selected_present = {}, false
  for _, layer in ipairs(selected_window.layers or {}) do
    if layer.kind == "tiled" then
      local members = {}
      for _, candidate in ipairs(layer.blocks or {}) do members[candidate.block_id] = candidate end
      local function visit(node)
        if not node then return end
        if node.split then visit(node.split.before); visit(node.split.after); return end
        local candidate = members[node.block_id]
        if candidate and not owned(candidate) then
          if candidate.block_id == target.block_id then selected_present = true end
          panes[#panes + 1] = { block_id = candidate.block_id, block = candidate, rect = node.rect,
            label = display(candidate.label, "Pane " .. tostring(candidate.block_id):sub(-8)) }
        end
      end
      visit(layer.layout)
      break
    end
  end
  if not selected_present or #panes == 0 then error("Tab preview is unavailable.", 0) end
  if #panes > 64 then error("This tab has too many splits to preview.", 0) end

  for _, pane in ipairs(panes) do
    local ok, lines = pcall(capture, target.session_id, pane)
    pane.lines = ok and lines or { Render.text_cells("(preview unavailable)", "\27[38;5;8m") }
  end
  local columns = tonumber(os.getenv("REX_FLOATERS_TV_COLUMNS")) or 80
  local rows = tonumber(os.getenv("REX_FLOATERS_TV_ROWS")) or 30
  return Render.compose(panes, columns, rows, target.block_id)
end

local ok, content = pcall(preview)
if ok then
  io.write(content)
else
  io.write("Tab preview unavailable: ", tostring(content):gsub("[%z\1-\31\127]", " "), "\n")
end
