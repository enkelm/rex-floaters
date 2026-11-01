return {
  title = "Lazygit",
  category = "Git",
  keywords = "lg lazygit git repository floating popup",
  description = "Show or hide Lazygit. Outside a checkout, choose between discovered repositories.",
  binding = "cmd+shift+g",
  collect = "collect.lua",
  picker = { title = "Lazygit · Choose a worktree", multiple = false, skip_single = true },
  execute = "execute.lua",
}
