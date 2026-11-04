---@type LazySpec
return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      filtered_items = { hide_dotfiles = false, hide_gitignored = true, hide_by_name = { ".git" } },
      follow_current_file = { enabled = true },
      bind_to_cwd = true,
    },
    window = { width = 32 },
  },
}
