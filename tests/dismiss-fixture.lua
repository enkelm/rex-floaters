local file = arg[1]
local restored, window
rex = {
  args = { window = "window:origin", focus = "block:origin", zoom = "" }, block_id = "block:popup",
  session = {
    view = function() return { active_window_id = window.active, windows = { window } } end,
    focus_block = function(args) restored = { block = args.block_id, zoom = false }; return {} end,
    zoom_block = function(args) restored = { block = args.block_id, zoom = args.zoom }; return {} end,
  },
}
local function reset()
  restored = nil; rex.args.zoom = ""
  window = { active = "window:origin", window_id = "window:origin", focused_block_id = "block:popup",
    layers = { { blocks = { { block_id = "block:origin" }, { block_id = "block:popup" } } } } }
end
reset(); dofile(file)
assert(restored.block == "block:origin" and restored.zoom == false)
reset(); rex.args.zoom = "block:origin"; dofile(file)
assert(restored.block == "block:origin" and restored.zoom == true)
reset(); window.active = "window:other"; dofile(file); assert(not restored)
reset(); window.focused_block_id = "block:other"; dofile(file); assert(not restored)
reset(); window.layers[1].blocks = { { block_id = "block:popup" } }; dofile(file); assert(not restored)
