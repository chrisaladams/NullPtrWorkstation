-- AstroCommunity packs. Only what the workstation needs, nothing that competes
-- with AstroNvim's built-in features (Neo-tree, Snacks picker, Gitsigns,
-- toggleterm/LazyGit, nvim-dap + dap-ui, Aerial, Resession are built in).
---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.colorscheme.tokyonight-nvim" },
  { import = "astrocommunity.file-explorer.oil-nvim" }, -- edit directories like text: Space O
  { import = "astrocommunity.git.diffview-nvim" }, -- :DiffviewOpen, Space g d
  { import = "astrocommunity.diagnostics.trouble-nvim" }, -- Space x x / Space x X
  { import = "astrocommunity.markdown-and-latex.render-markdown-nvim" },
}
