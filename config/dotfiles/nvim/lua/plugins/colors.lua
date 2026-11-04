-- Tokyo Night everywhere (kitty, tmux and lazygit use the same palette)
---@type LazySpec
return {
  "folke/tokyonight.nvim",
  opts = { style = "night", transparent = false, terminal_colors = true, styles = { sidebars = "dark", floats = "dark" } },
}
