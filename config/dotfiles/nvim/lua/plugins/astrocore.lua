-- Core behaviour: options, project-aware rooter, treesitter, nullptr mappings.
---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    features = {
      large_buf = { size = 1024 * 256, lines = 10000 },
      autopairs = true,
      cmp = true,
      diagnostics = { virtual_text = true, virtual_lines = false },
      highlighturl = true,
      notifications = true,
    },
    diagnostics = { virtual_text = true, underline = true, update_in_insert = false },
    rooter = {
      enabled = true,
      -- a nullptr project marker wins over everything else
      detector = { { ".nullptr-project" }, "lsp", { ".git" }, { "CMakeLists.txt", "Makefile" } },
      ignore = { servers = {}, dirs = {} },
      autochdir = false,
      scope = "global",
      notify = false,
    },
    sessions = {
      autosave = { last = true, cwd = true }, -- remember open files per project
      ignore = { dirs = {}, filetypes = { "gitcommit", "gitrebase" }, buftypes = {} },
    },
    treesitter = {
      highlight = true,
      indent = true,
      auto_install = false, -- parsers are pre-installed in the image; no surprise downloads
      auto_install_cli = false, -- tree-sitter CLI is installed system-wide
      -- NULLPTR_TS_BOOTSTRAP=1 is set only by the image build, which installs them itself
      ensure_installed = vim.env.NULLPTR_TS_BOOTSTRAP and {} or require "nullptr.parsers",
    },
    options = {
      opt = {
        number = true,
        relativenumber = false, -- friendlier while learning; toggle with Space u n
        spell = false,
        signcolumn = "yes",
        wrap = false,
        scrolloff = 5,
        confirm = true,
        termguicolors = true,
      },
    },
    mappings = {
      n = {
        -- nullptr: projects, build, run, debug  (Space m ...)
        ["<Leader>m"] = { desc = "󰐊 Make / Game" },
        ["<Leader>mb"] = { function() require("nullptr.project").build "debug" end, desc = "Build (Debug)" },
        ["<Leader>mB"] = { function() require("nullptr.project").build "release" end, desc = "Build (Release)" },
        ["<Leader>mr"] = { function() require("nullptr.project").run() end, desc = "Run game / ROM" },
        ["<Leader>md"] = { function() require("nullptr.project").debug() end, desc = "Debug (build + start debugger)" },
        ["<Leader>mc"] = { function() require("nullptr.project").clean() end, desc = "Clean build files" },
        ["<Leader>mp"] = { function() require("nullptr.project").pick() end, desc = "Open project" },
        ["<Leader>mR"] = { function() require("nullptr.project").pick_recent() end, desc = "Recent projects" },
        ["<Leader>mn"] = { function() require("nullptr.project").new() end, desc = "New project" },
        ["<Leader>mi"] = { function() require("nullptr.project").info() end, desc = "Project info" },
        ["<Leader>ma"] = { function() vim.system { "art" } end, desc = "Open LibreSprite (art)" },
        ["<Leader>mt"] = { function() vim.system { "tiles" } end, desc = "Open Tiled map editor (tiles)" },
        ["<Leader>fp"] = { function() require("nullptr.project").pick() end, desc = "Find project" },
        ["<Leader>gD"] = { "<Cmd>DiffviewOpen<CR>", desc = "Diffview: all changes in project" },
        ["<Leader>?"] = { function() require("nullptr.help").open "cheatsheet.txt" end, desc = "nullptr cheat sheet" },
        -- F5: continue if debugging, otherwise build + start the right debugger
        ["<F5>"] = {
          function()
            local ok, dap = pcall(require, "dap")
            if ok and dap.session() then
              dap.continue()
            else
              require("nullptr.project").debug()
            end
          end,
          desc = "Debugger: start / continue",
        },
      },
    },
  },
}
