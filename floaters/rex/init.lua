return {
  title = "Rex tab picker",
  binding = false,
  category = "Rex",
  description = "Choose a Rex tab, preview all of its splits, and focus its remembered pane.",
  keywords = "rex tab pane split session television picker",
  collect = "collect.lua",
  picker = {
    title = "Rex tabs",
    backend = "tv",
    preview = "preview.lua",
    skip_single = false,
  },
  execute = "execute.lua",
}
