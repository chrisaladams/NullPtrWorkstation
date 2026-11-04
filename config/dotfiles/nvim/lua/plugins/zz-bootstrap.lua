-- Loaded last (alphabetical). During the image build (NULLPTR_TS_BOOTSTRAP=1) no plugin may
-- start parser downloads on its own: scripts/install/nvim-ts-install.lua installs them all,
-- from git, at the revisions pinned by the locked nvim-treesitter.
---@type LazySpec
return {
  "AstroNvim/astrocore",
  opts = function(_, opts)
    if vim.env.NULLPTR_TS_BOOTSTRAP then
      opts.treesitter = opts.treesitter or {}
      opts.treesitter.ensure_installed = {}
      opts.treesitter.auto_install = false
    end
  end,
}
