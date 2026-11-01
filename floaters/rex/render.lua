local M = {}

local function codepoint(text, index)
  local first = text:byte(index)
  if not first then return nil, index end
  if first < 0x80 then return first, index + 1 end
  local count, value
  if first >= 0xC2 and first <= 0xDF then count, value = 2, first - 0xC0
  elseif first >= 0xE0 and first <= 0xEF then count, value = 3, first - 0xE0
  elseif first >= 0xF0 and first <= 0xF4 then count, value = 4, first - 0xF0
  else return 0xFFFD, index + 1 end
  if index + count - 1 > #text then return 0xFFFD, index + 1 end
  for offset = 1, count - 1 do
    local byte = text:byte(index + offset)
    if byte < 0x80 or byte > 0xBF then return 0xFFFD, index + 1 end
    value = value * 64 + byte - 0x80
  end
  return value, index + count
end

local function encode(cp)
  if cp < 0x80 then return string.char(cp) end
  if cp < 0x800 then return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64) end
  if cp < 0x10000 then
    return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
  end
  if cp <= 0x10FFFF then
    return string.char(0xF0 + math.floor(cp / 262144), 0x80 + math.floor(cp / 4096) % 64,
      0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
  end
  return "\239\191\189"
end

local function in_range(value, first, last) return value >= first and value <= last end
local function cell_width(cp)
  if cp == 0x200D or in_range(cp, 0x0300, 0x036F) or in_range(cp, 0x1AB0, 0x1AFF)
    or in_range(cp, 0x1DC0, 0x1DFF) or in_range(cp, 0x20D0, 0x20FF)
    or in_range(cp, 0xFE00, 0xFE0F) or in_range(cp, 0xFE20, 0xFE2F)
    or in_range(cp, 0x1F3FB, 0x1F3FF) then return 0 end
  if in_range(cp, 0x1100, 0x115F) or in_range(cp, 0x2329, 0x232A)
    or in_range(cp, 0x2E80, 0xA4CF) and cp ~= 0x303F or in_range(cp, 0xAC00, 0xD7A3)
    or in_range(cp, 0xF900, 0xFAFF) or in_range(cp, 0xFE10, 0xFE6F)
    or in_range(cp, 0xFF01, 0xFF60) or in_range(cp, 0xFFE0, 0xFFE6)
    or in_range(cp, 0x1F1E6, 0x1FAFF) or in_range(cp, 0x20000, 0x3FFFD) then return 2 end
  return 1
end

local entities = { lt = "<", gt = ">", amp = "&", quot = '"', apos = "'", nbsp = " " }
local function decode_entities(text)
  return (text:gsub("&([^;]+);", function(entity)
    if entities[entity] then return entities[entity] end
    local decimal = entity:match("^#(%d+)$")
    local hexadecimal = entity:match("^#[xX]([%da-fA-F]+)$")
    local value = decimal and tonumber(decimal) or hexadecimal and tonumber(hexadecimal, 16)
    return value and encode(value) or ("&" .. entity .. ";")
  end))
end

local function color(value, foreground)
  local palette = value and value:match("var%(%-%-vt%-palette%-(%d+)%)")
  if palette then return (foreground and "38;5;" or "48;5;") .. palette end
  local red, green, blue
  if value then red, green, blue = value:match("rgb%(%s*(%d+),%s*(%d+),%s*(%d+)%)") end
  if red then return (foreground and "38;2;" or "48;2;") .. red .. ";" .. green .. ";" .. blue end
  local hex = value and value:match("#(%x%x%x%x%x%x)")
  if hex then
    return string.format("%s;%d;%d;%d", foreground and "38;2" or "48;2",
      tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
  end
end

local function ansi_style(source)
  local properties = {}
  for declaration in tostring(source or ""):gmatch("[^;]+") do
    local key, value = declaration:match("^%s*([^:]+):%s*(.-)%s*$")
    if key then properties[key] = value end
  end
  local codes = {}
  local foreground = color(properties.color, true)
  local background = color(properties["background-color"], false)
  if foreground then codes[#codes + 1] = foreground end
  if background then codes[#codes + 1] = background end
  if properties["font-weight"] == "bold" then codes[#codes + 1] = "1" end
  if properties.opacity and tonumber(properties.opacity) and tonumber(properties.opacity) < 1 then codes[#codes + 1] = "2" end
  if properties["font-style"] == "italic" then codes[#codes + 1] = "3" end
  local decoration = properties["text-decoration-line"] or ""
  if decoration:find("underline", 1, true) then codes[#codes + 1] = "4" end
  if decoration:find("blink", 1, true) then codes[#codes + 1] = "5" end
  if properties.filter and properties.filter:find("invert", 1, true) then codes[#codes + 1] = "7" end
  if decoration:find("line-through", 1, true) then codes[#codes + 1] = "9" end
  return #codes > 0 and ("\27[" .. table.concat(codes, ";") .. "m") or ""
end

local function append_text(lines, text, style)
  text = decode_entities(text)
  local index = 1
  while index <= #text do
    local cp, after = codepoint(text, index)
    local bytes = text:sub(index, after - 1)
    if cp == 10 then
      lines[#lines + 1] = {}
    elseif cp == 13 then
    elseif cp == 9 then
      local line = lines[#lines]
      local used = 0
      for _, cell in ipairs(line) do used = used + cell.width end
      local count = 8 - used % 8
      for _ = 1, count do line[#line + 1] = { text = " ", width = 1, style = style } end
    elseif cp < 32 or in_range(cp, 0x7F, 0x9F) or in_range(cp, 0x202A, 0x202E)
      or in_range(cp, 0x2066, 0x2069) then
      lines[#lines][#lines[#lines] + 1] = { text = " ", width = 1, style = style }
    else
      local width = cell_width(cp)
      local line = lines[#lines]
      if width == 0 and #line > 0 then line[#line].text = line[#line].text .. bytes
      else line[#line + 1] = { text = bytes, width = width, style = style } end
    end
    index = after
  end
end

function M.html_lines(content)
  local lines, styles, position = { {} }, { "" }, 1
  while position <= #content do
    local opening = content:find("<", position, true)
    if not opening then append_text(lines, content:sub(position), styles[#styles]); break end
    if opening > position then append_text(lines, content:sub(position, opening - 1), styles[#styles]) end
    local closing = content:find(">", opening + 1, true)
    if not closing then break end
    local tag = content:sub(opening + 1, closing - 1)
    local name = tag:match("^%s*/%s*([%w]+)")
    if name then
      if (name == "div" or name == "span" or name == "a") and #styles > 1 then table.remove(styles) end
    else
      name = tag:match("^%s*([%w]+)")
      if name == "br" then lines[#lines + 1] = {}
      elseif name == "div" or name == "span" or name == "a" then
        local source = tag:match('style%s*=%s*"(.-)"') or tag:match("style%s*=%s*'(.-)'")
        styles[#styles + 1] = source and ansi_style(source) or styles[#styles]
      end
    end
    position = closing + 1
  end
  while #lines > 1 and #lines[#lines] == 0 do table.remove(lines) end
  return lines
end

function M.text_cells(text, style)
  local lines = { {} }
  append_text(lines, text, style or "")
  return lines[1]
end

local function canvas(rows, columns)
  local result = {}
  for row = 1, rows do
    result[row] = {}
    for column = 1, columns do result[row][column] = { text = " ", width = 1, style = "" } end
  end
  return result
end

local function put(target, row, column, cell, columns)
  if not target[row] or column < 1 or column > columns then return end
  target[row][column] = { text = cell.text, width = cell.width, style = cell.style }
  if cell.width == 2 and column < columns then target[row][column + 1] = { continuation = true } end
end

local function put_cells(target, row, column, cells, limit, columns)
  local used = 0
  for _, cell in ipairs(cells or {}) do
    if used + cell.width > limit then break end
    put(target, row, column + used, cell, columns)
    used = used + cell.width
  end
end

local function rectangle(rect, columns, rows)
  if type(rect) ~= "table" or #rect ~= 4 then return nil end
  local x1 = math.max(1, math.min(columns, math.floor(rect[1] * columns) + 1))
  local y1 = math.max(1, math.min(rows, math.floor(rect[2] * rows) + 1))
  local x2 = math.max(x1, math.min(columns, math.floor((rect[1] + rect[3]) * columns + 0.000001)))
  local y2 = math.max(y1, math.min(rows, math.floor((rect[2] + rect[4]) * rows + 0.000001)))
  return x1, y1, x2, y2
end

function M.compose(panes, columns, rows, selected)
  columns, rows = math.max(20, math.floor(columns)), math.max(8, math.floor(rows))
  local output = canvas(rows, columns)
  for _, pane in ipairs(panes) do
    local x1, y1, x2, y2 = rectangle(pane.rect, columns, rows)
    if x1 then
      local border = pane.block_id == selected and "\27[38;5;14m" or "\27[38;5;8m"
      for x = x1 + 1, x2 - 1 do
        put(output, y1, x, { text = "─", width = 1, style = border }, columns)
        put(output, y2, x, { text = "─", width = 1, style = border }, columns)
      end
      for y = y1 + 1, y2 - 1 do
        put(output, y, x1, { text = "│", width = 1, style = border }, columns)
        put(output, y, x2, { text = "│", width = 1, style = border }, columns)
      end
      put(output, y1, x1, { text = "┌", width = 1, style = border }, columns)
      put(output, y1, x2, { text = "┐", width = 1, style = border }, columns)
      put(output, y2, x1, { text = "└", width = 1, style = border }, columns)
      put(output, y2, x2, { text = "┘", width = 1, style = border }, columns)
      local inner_width, inner_height = math.max(0, x2 - x1 - 1), math.max(0, y2 - y1 - 1)
      if inner_width > 2 then
        local title = M.text_cells(" " .. tostring(pane.label or "Pane") .. " ", border)
        put_cells(output, y1, x1 + 2, title, inner_width - 2, columns)
      end
      if inner_width > 0 and inner_height > 0 then
        local lines = pane.lines or { M.text_cells("(preview unavailable)", "\27[38;5;8m") }
        local first = math.max(1, #lines - inner_height + 1)
        local destination = y1 + 1
        for index = first, #lines do
          if destination > y2 - 1 then break end
          put_cells(output, destination, x1 + 1, lines[index], inner_width, columns)
          destination = destination + 1
        end
      end
    end
  end
  local rendered = {}
  for row = 1, rows do
    local current, parts, column = nil, {}, 1
    while column <= columns do
      local cell = output[row][column]
      if cell.continuation then column = column + 1
      else
        local style = cell.style or ""
        if style ~= current then
          parts[#parts + 1] = "\27[0m"
          if style ~= "" then parts[#parts + 1] = style end
          current = style
        end
        parts[#parts + 1] = cell.text or " "
        column = column + math.max(1, cell.width or 1)
      end
    end
    rendered[#rendered + 1] = table.concat(parts):gsub(" +$", "") .. "\27[0m"
  end
  return table.concat(rendered, "\n") .. "\n"
end

return M
