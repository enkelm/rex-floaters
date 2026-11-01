local ctx = ...
local prefix = "rex-floaters:"
local terminal = "com.superlogical.terminal"
local items = {}

local function call(method, args)
  local result, err = rex.call(method, args)
  if result == nil then error(err or ("Rex call failed: " .. method), 0) end
  return result
end

local function short_id(value)
  return tostring(value or "?"):match("([^:]+)$"):sub(-8)
end
local function label(value, fallback)
  value = type(value) == "string" and value:match("%S") and value or fallback
  return value:gsub("[%z\1-\31\127]", " "):gsub("\194[\128-\159]", " ")
    :gsub("\226\128[\170-\174]", " "):gsub("\226\129[\166-\169]", " ")
end
local function owned(block)
  return (block.label or ""):sub(1, #prefix) == prefix
end

for _, session in ipairs((call("session.list").sessions or {})) do
  local ok, view = pcall(function()
    call("session.attach", { session_id = session.session_id })
    return call("session.view", { session_id = session.session_id })
  end)
  if ok then
    local session_label = label(view.label or session.label, "Session " .. short_id(session.session_id))
    for _, window in ipairs(view.windows or {}) do
      local blocks, tiled, terminals, first_terminal = {}, {}, 0
      for _, layer in ipairs(window.layers or {}) do
        for _, block in ipairs(layer.blocks or {}) do blocks[block.block_id] = block end
        if layer.kind == "tiled" then
          for _, block in ipairs(layer.blocks or {}) do
            tiled[block.block_id] = true
            if block.creator_name == terminal and not owned(block) then
              terminals = terminals + 1
              first_terminal = first_terminal or block.block_id
            end
          end
        end
      end
      if first_terminal then
        local current = ctx.origin and ctx.origin.session_id == session.session_id and
          ctx.origin.window_id == window.window_id
        local remembered = current and ctx.origin.block_id or window.focused_block_id
        if not remembered or not tiled[remembered] or not blocks[remembered] or owned(blocks[remembered]) then
          remembered = first_terminal
        end
        local remembered_block = blocks[remembered]
        local window_label = label(window.label, "Tab " .. short_id(window.window_id))
        local row = session_label .. " / " .. window_label
        if current then row = "● CURRENT · " .. row end
        local pane_label = label(remembered_block and remembered_block.label, "Pane " .. short_id(remembered))
        items[#items + 1] = {
          value = assert(rex.json.encode({ session_id = session.session_id, window_id = window.window_id,
            block_id = remembered })),
          label = row,
          description = string.format("%d %s · %s", terminals, terminals == 1 and "pane" or "panes", pane_label),
        }
      end
    end
  end
end
return items
