require("lazy").setup({
  {
    "AstroNvim/AstroNvim",
    version = "^6",
    import = "astronvim.plugins",
    opts = {
      mapleader = " ",
      maplocalleader = ",",
      icons_enabled = true, -- JetBrainsMono Nerd Font is installed system-wide
      pin_plugins = true, -- keep the plugin versions AstroNvim v6 was tested with
      update_notifications = false, -- updates are a deliberate act: Space p a
    },
  },
  { import = "community" },
  { import = "plugins" },
} --[[@as LazySpec]], {
  install = { colorscheme = { "tokyonight", "astrotheme", "habamax" }, missing = true },
  checker = { enabled = false }, -- no background network checks
  change_detection = { notify = false },
  ui = { backdrop = 100, border = "rounded" },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "netrwPlugin", "tarPlugin", "tohtml", "zipPlugin" },
    },
  },
} --[[@as LazyConfig]])
