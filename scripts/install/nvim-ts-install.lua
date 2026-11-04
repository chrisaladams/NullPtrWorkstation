-- Install the treesitter parsers AstroNvim is configured to use, fetching each grammar
-- with git at the exact revision pinned by the (lazy-lock pinned) nvim-treesitter.
-- Usage: nvim --headless -c "luafile scripts/install/nvim-ts-install.lua" -c qa
local parsers = require "nvim-treesitter.parsers"
local want = require "nullptr.parsers"

-- include required parsers (e.g. cpp -> c)
local all, seen = {}, {}
local function add(lang)
  if seen[lang] or not parsers[lang] then return end
  seen[lang] = true
  for _, dep in ipairs(parsers[lang].requires or {}) do add(dep) end
  table.insert(all, lang)
end
for _, l in ipairs(want) do add(l) end

local cache = vim.fn.stdpath "cache" .. "/nullptr-ts-src"
vim.fn.mkdir(cache, "p")
local failed = {}
local local_src = {}
for _, lang in ipairs(all) do
  local info = parsers[lang].install_info
  if info and info.url and not info.path then
    local dir = cache .. "/" .. lang
    local function git(args)
      local r = vim.system(vim.list_extend({ "git", "-C", dir }, args), { text = true }):wait()
      return r.code == 0, (r.stderr or "")
    end
    vim.fn.mkdir(dir, "p")
    git { "init", "-q" }
    git { "remote", "add", "origin", info.url }
    local ok, err = git { "fetch", "-q", "--depth", "1", "origin", info.revision or info.branch or "HEAD" }
    if ok then ok, err = git { "checkout", "-q", "--force", "FETCH_HEAD" } end
    if ok then
      local_src[lang] = dir
    else
      table.insert(failed, lang .. ": " .. err)
    end
  end
end
-- nvim-treesitter reloads its parser table before installing and then fires
-- `User TSUpdate`; that is the supported place to point grammars at local sources.
local function apply_paths()
  local p = require "nvim-treesitter.parsers"
  for lang, dir in pairs(local_src) do
    if p[lang] and p[lang].install_info then p[lang].install_info.path = dir end
  end
end
vim.api.nvim_create_autocmd("User", { pattern = "TSUpdate", callback = apply_paths })
apply_paths()
local ok = require("nvim-treesitter").install(all, { summary = true }):wait(1800000)
local installed = require("nvim-treesitter").get_installed "parsers"
local missing = vim.tbl_filter(function(l)
  return parsers[l].install_info ~= nil and not vim.tbl_contains(installed, l) -- query-only langs have no parser
end, all)
io.stdout:write(("treesitter: %d requested, %d installed, missing: %s\n"):format(#all, #installed,
  #missing > 0 and table.concat(missing, ", ") or "none"))
for _, f in ipairs(failed) do io.stdout:write("fetch failed: " .. f .. "\n") end
io.stdout:flush()
if #missing > 0 or not ok then vim.cmd "cquit 1" end
