-- Beginner dashboard (Snacks dashboard, which AstroNvim already uses)
---@type LazySpec
return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    local function act(fn) return function() require("nullptr.project")[fn]() end end
    -- "[P]  Open Project" — key first; the key still triggers the action (p or P)
    local function item(key, icon, desc, action)
      return {
        key = key,
        action = action,
        text = {
          { "[", hl = "NonText" }, { key:upper(), hl = "SnacksDashboardKey" }, { "]  ", hl = "NonText" },
          { icon, hl = "SnacksDashboardIcon" }, { desc, hl = "SnacksDashboardDesc" },
        },
      }
    end
    local function projects_section()
      local items = {}
      local list = require("nullptr.project").list()
      for i, root in ipairs(list) do
        if i > 9 then break end
        local m = require("nullptr.project").meta(root)
        local icon = ({ gameboy = "󰊴 ", raylib = "󰺵 " })[m.type] or "󰙱 "
        local label = ({ gameboy = "Game Boy", raylib = "raylib", generic = "C" })[m.type] or (m.type or "?")
        table.insert(items, item(tostring(i), icon,
          ("%-18s %s"):format(m.name, label),
          function() require("nullptr.project").open(root) end))
      end
      if #items == 0 then
        items = { { text = { { "  (none yet — Space m n, or new-c / new-raylib / new-gameboy NAME)", hl = "Comment" } } } }
      end
      return items
    end

    opts.dashboard = {
      width = 60,
      preset = {
        keys = {
          item("p", "󰝰 ", "Open Project", act "pick"),
          item("f", "󰈞 ", "Find File", "<Leader>ff"),
          item("n", "󰝒 ", "New File", "<Cmd>enew<CR>"),
          item("e", "󰙅 ", "File Explorer", "<Cmd>Neotree toggle<CR>"),
          item("r", "󰋚 ", "Recent Projects", act "pick_recent"),
          item("h", "󰋖 ", "Help", function() require("nullptr.help").open "cheatsheet.txt" end),
          item("q", "󰗼 ", "Quit", "<Cmd>qa<CR>"),
        },
        header = "Welcome, " .. (vim.env.USER or "nullptr"),
      },
      sections = {
        { section = "header", padding = 1 },
        { section = "keys", gap = 0, padding = 1 },
        { title = "Starter projects", padding = 1 },
        function() return projects_section() end,
        { text = { { require("nullptr.help").tip(), hl = "Comment" } }, padding = { 1, 1 }, align = "center" },
        { text = { { "i insert · Esc normal · :w save · :q quit · Space ? cheat sheet", hl = "NonText" } }, align = "center" },
      },
    }

    -- Upper-case aliases ([P] works as p or P). Snacks (re)creates its buffer-local item
    -- keymaps on every render, then fires User SnacksDashboardUpdatePost.
    vim.api.nvim_create_autocmd("User", {
      pattern = "SnacksDashboardUpdatePost",
      group = vim.api.nvim_create_augroup("nullptr_dashboard_keys", { clear = true }),
      callback = function()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "snacks_dashboard" then
            for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
              if m.lhs:match "^%l$" and m.callback then
                vim.keymap.set("n", m.lhs:upper(), m.callback, { buffer = buf, nowait = true, desc = m.desc })
              end
            end
          end
        end
      end,
    })
    return opts
  end,
}
