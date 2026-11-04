local collect = require("pluck.collect")
local Snapshot = require("pluck.collect.snapshot")
local concat = require("pluck.collect.concat")
local UI = require("pluck.executor.ui")

local function base64(text)
  local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  local out = {}
  for index = 1, #text, 3 do
    local a, b, c = text:byte(index, index + 2)
    b, c = b or 0, c or 0
    local value = a * 65536 + b * 256 + c
    local first = math.floor(value / 262144) % 64 + 1
    local second = math.floor(value / 4096) % 64 + 1
    local third = math.floor(value / 64) % 64 + 1
    local fourth = value % 64 + 1
    out[#out + 1] = alphabet:sub(first, first)
    out[#out + 1] = alphabet:sub(second, second)
    out[#out + 1] = index + 1 <= #text and alphabet:sub(third, third) or "="
    out[#out + 1] = index + 2 <= #text and alphabet:sub(fourth, fourth) or "="
  end
  return concat(out)
end
local function clean_message(message)
  message = tostring(message)
  local out, cursor = {}, 1
  while cursor <= #message do
    local cp, after = Snapshot.codepoint(message, cursor)
    if cp <= 0x1F or cp >= 0x7F and cp <= 0x9F then out[#out + 1] = " "
    else out[#out + 1] = message:sub(cursor, after - 1) end
    cursor = after
  end
  return concat(out)
end

return function(ctx)
  local ok, err = pcall(function()
    local snapshot, tokens = collect(ctx)
    local selected = UI.pick_token(snapshot, tokens)
    if selected ~= nil then
      if #selected > 65536 then error("This token exceeds the 64 KiB copy limit. Copy a smaller selection manually.", 0) end
      io.write("\27]52;c;", base64(selected), "\7"); io.flush()
    end
  end)
  if not ok then io.stderr:write("Pluck: ", clean_message(err), "\n"); io.stderr:flush() end
  return ok and 0 or 1
end
