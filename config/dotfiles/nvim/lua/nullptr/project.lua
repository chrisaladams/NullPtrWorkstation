-- nullptr Workstation: project selection, build/run/debug integration.
--
-- One source of truth: the shell commands `build`, `run-game`, `projects` etc.
-- (see /usr/local/bin) do the actual work. This module
--   * tracks the *active project* (shared with the shell through
--     ~/.local/state/nullptr/active-project),
--   * switches project when you open/enter a file of another project,
--   * runs the commands in a terminal split with the project root passed
--     explicitly (so the wrong project can never be built),
--   * starts nvim-dap with the right adapter (GDB or Emulicious).
local M = {}

local uv = vim.uv or vim.loop
local home = vim.env.HOME
M.projects_dir = vim.env.NW_PROJECTS_DIR or (home .. "/Projects")
local state_dir = (vim.env.XDG_STATE_HOME or (home .. "/.local/state")) .. "/nullptr"
local active_file = state_dir .. "/active-project"
local recent_file = state_dir .. "/recent-projects"

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "nullptr" }) end

local function read_lines(path)
  local f = io.open(path, "r")
  if not f then return {} end
  local lines = {}
  for l in f:lines() do
    if l ~= "" then table.insert(lines, l) end
  end
  f:close()
  return lines
end

local function write_atomic(path, text)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local tmp = path .. ".tmp" .. uv.os_getpid()
  local f = assert(io.open(tmp, "w"))
  f:write(text)
  f:close()
  assert(uv.fs_rename(tmp, path))
end

--- Project root containing `path` (a `.nullptr-project` file marks a project)
---@param path string?
---@return string?
function M.find_root(path)
  if not path or path == "" then return nil end
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  local root = vim.fs.root(path, ".nullptr-project")
  if root then return vim.fs.normalize(uv.fs_realpath(root) or root) end
end

---@param root string
---@return { type: string, target: string, name: string }
function M.meta(root)
  local m = { name = vim.fs.basename(root) }
  for _, l in ipairs(read_lines(root .. "/.nullptr-project")) do
    local k, v = l:match "^(%w+)=(.*)$"
    if k then m[k] = v end
  end
  m.target = (m.target and m.target ~= "") and m.target or m.name
  return m
end

---@return string?
function M.active()
  local p = read_lines(active_file)[1]
  if p and uv.fs_stat(p .. "/.nullptr-project") then return p end
end

function M.set_active(root, quiet)
  if not root then return end
  local prev = M.active()
  write_atomic(active_file, root .. "\n")
  local recent = { root }
  for _, r in ipairs(read_lines(recent_file)) do
    if r ~= root and #recent < 20 then table.insert(recent, r) end
  end
  write_atomic(recent_file, table.concat(recent, "\n") .. "\n")
  if vim.env.TMUX then
    vim.system({ "tmux", "set-environment", "-g", "NULLPTR_PROJECT", root })
    vim.system { "tmux", "refresh-client", "-S" }
  end
  if prev ~= root and not quiet then
    local m = M.meta(root)
    notify(("Active project: %s (%s)"):format(m.name, m.type or "?"))
  end
end

--- All projects: everything in ~/Projects plus recent ones elsewhere
---@return string[]
function M.list()
  local out, seen = {}, {}
  local function add(p)
    p = vim.fs.normalize(p)
    if not seen[p] and uv.fs_stat(p .. "/.nullptr-project") then
      seen[p] = true
      table.insert(out, p)
    end
  end
  for name, t in vim.fs.dir(M.projects_dir) do
    if t == "directory" then add(M.projects_dir .. "/" .. name) end
  end
  -- starter projects first (in this order), then alphabetical
  local rank = { ["raylib-hello"] = 1, ["gameboy-hello"] = 2 }
  table.sort(out, function(a, b)
    local ra, rb = rank[vim.fs.basename(a)] or 9, rank[vim.fs.basename(b)] or 9
    if ra ~= rb then return ra < rb end
    return a < b
  end)
  for _, r in ipairs(read_lines(recent_file)) do
    add(r)
  end
  return out
end

function M.recent()
  return vim.tbl_filter(function(p) return uv.fs_stat(p .. "/.nullptr-project") ~= nil end, read_lines(recent_file))
end

--- The project the user is looking at right now
---@return string?
function M.current()
  local buf = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype == "" and buf ~= "" then
    local r = M.find_root(buf)
    if r then return r end
  end
  return M.find_root(vim.fn.getcwd()) or M.active()
end

local function save_dirsession()
  local ok, resession = pcall(require, "resession")
  if not ok then return end
  local cwd = vim.fn.getcwd()
  if M.find_root(cwd) == cwd then pcall(resession.save, cwd, { dir = "dirsession", notify = false }) end
end

--- Open a project directory or a file (and make its project active)
---@param path string?
function M.open(path)
  path = path and vim.fs.normalize(vim.fn.fnamemodify(path, ":p")) or M.projects_dir
  local is_dir = vim.fn.isdirectory(path) == 1
  local root = M.find_root(path)
  if root and root ~= M.find_root(vim.fn.getcwd()) then save_dirsession() end
  if root then
    vim.cmd.cd(vim.fn.fnameescape(root))
    M.set_active(root)
  elseif is_dir then
    vim.cmd.cd(vim.fn.fnameescape(path))
  end
  if not is_dir then
    vim.cmd.edit(vim.fn.fnameescape(path))
    return
  end
  -- a project directory: restore its last session if there is one,
  -- otherwise open src/main.c and the file explorer
  if root == path then
    local ok, resession = pcall(require, "resession")
    if ok and pcall(resession.load, root, { dir = "dirsession", silence_errors = true }) then
      local name = vim.api.nvim_buf_get_name(0)
      if vim.bo.buftype == "" and name ~= "" and M.find_root(name) == root then return end
    end
    local main = root .. "/src/main.c"
    if uv.fs_stat(main) then vim.cmd.edit(vim.fn.fnameescape(main)) end
  end
  pcall(vim.cmd, "Neotree show reveal_force_cwd dir=" .. vim.fn.fnameescape(root or path))
end

local function pick_from(list, prompt)
  if #list == 0 then
    notify("No projects yet. Create one: Space m n, or in a terminal: new-c / new-raylib / new-gameboy NAME", vim.log.levels.WARN)
    return
  end
  local active = M.active()
  vim.ui.select(list, {
    prompt = prompt,
    format_item = function(p)
      local m = M.meta(p)
      return ("%s %-24s %-8s %s"):format(p == active and "*" or " ", m.name, m.type or "?", p)
    end,
  }, function(choice)
    if choice then M.open(choice) end
  end)
end

function M.pick() pick_from(M.list(), "Open project") end
function M.pick_recent() pick_from(M.recent(), "Recent projects") end

-- ---------------------------------------------------------------- terminal runner
local term_buf
--- Run `cmd` in a reusable terminal split at the bottom.
---@param cmd string[]
---@param on_success fun()?
function M.term(cmd, on_success)
  pcall(vim.cmd, "silent! wall")
  if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
    pcall(vim.api.nvim_buf_delete, term_buf, { force = true })
  end
  local origin = vim.api.nvim_get_current_win()
  vim.cmd "botright 14new"
  term_buf = vim.api.nvim_get_current_buf()
  vim.bo[term_buf].bufhidden = "wipe"
  local term_win = vim.api.nvim_get_current_win()
  vim.fn.jobstart(cmd, {
    term = true,
    on_exit = function(_, code)
      vim.schedule(function()
        if code == 0 and on_success then
          if vim.api.nvim_win_is_valid(term_win) then pcall(vim.api.nvim_win_close, term_win, true) end
          on_success()
        elseif code ~= 0 then
          notify(("`%s` failed (exit %d) — see the terminal below"):format(table.concat(cmd, " "), code),
            vim.log.levels.ERROR)
        end
      end)
    end,
  })
  local bufname = "nullptr://" .. table.concat(cmd, " ")
  local stale = vim.fn.bufnr(bufname)
  if stale > 0 and stale ~= term_buf then pcall(vim.api.nvim_buf_delete, stale, { force = true }) end
  pcall(vim.api.nvim_buf_set_name, term_buf, bufname)
  vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = term_buf, desc = "Close" })
  vim.cmd.stopinsert()
  -- keep the cursor on the last line so the split follows new output after focus leaves it
  vim.cmd "normal! G"
  if vim.api.nvim_win_is_valid(origin) then vim.api.nvim_set_current_win(origin) end
end

local function require_project()
  local root = M.current()
  if not root then
    notify("No project here. Open one first: Space m p (or [P] on the dashboard)", vim.log.levels.WARN)
    return
  end
  M.set_active(root)
  return root
end

function M.build(cfg)
  local root = require_project()
  if root then M.term { "build", "--" .. (cfg or "debug"), root } end
end

function M.run(cfg)
  local root = require_project()
  if root then M.term { "run-game", "--" .. (cfg or "debug"), root } end
end

function M.clean()
  local root = require_project()
  if not root then return end
  M.term { "build", "--clean", root }
end

-- ---------------------------------------------------------------- i3 workspaces
-- keep in sync with config/dotfiles/i3/config and scripts/lib/nullptr-common.sh
local ws_names = {
  astro = "1: astro", libresprite = "2: libresprite", tiled = "3: tiled", blender = "4: blender", game = "5: game", tools = "6: tools",
}
--- Show an i3 workspace by role: astro, libresprite, tiled, blender, game, tools (no-op outside X)
function M.workspace(n)
  if vim.env.DISPLAY and vim.fn.executable "i3-msg" == 1 then
    -- ignore I3SOCK: tmux (and this editor) may outlive an i3 restart and hold a dead path
    vim.system { "env", "-u", "I3SOCK", "i3-msg", "-q", "workspace number " .. ws_names[n] }
  end
end

-- While debugging a game: the game workspace is shown while the program runs
-- (games must be visible to start: GLFW waits for the window to become visible),
-- and the editor comes back whenever execution stops at a breakpoint/step.
function M.setup_dap_listeners(dap)
  if M._ws_listeners then return end
  M._ws_listeners = true
  local function ours(session) return session and session.config and session.config.nullptr_game end
  dap.listeners.before.launch.nullptr_ws = function(session)
    if ours(session) then M.workspace "game" end -- the game window must be visible while it starts
  end
  dap.listeners.after.event_stopped.nullptr_ws = function(session)
    if ours(session) then M.workspace "astro" end
  end
  dap.listeners.after.event_continued.nullptr_ws = function(session)
    if not ours(session) then return end
    vim.defer_fn(function() -- debounce: stepping stops again within milliseconds
      if dap.session() == session and not session.stopped_thread_id then M.workspace "game" end
    end, 400)
  end
  for _, ev in ipairs { "event_terminated", "event_exited" } do
    dap.listeners.after[ev].nullptr_ws = function(session)
      if ours(session) then M.workspace "astro" end
    end
  end
end

-- ---------------------------------------------------------------- debugging
--- nvim-dap configuration for a project (nil if unknown type)
function M.dap_config(root)
  local m = M.meta(root)
  if m.type == "raylib" then
    return {
      name = "Debug " .. m.name .. " (GDB)",
      type = "gdb",
      request = "launch",
      program = root .. "/build/debug/" .. m.target,
      cwd = root,
      stopAtBeginningOfMainSubprogram = false,
      nullptr_game = true,
    }
  elseif m.type == "generic" then
    -- same program the shell's `run-game`/`debug-game` use (see artifact= in .nullptr-project)
    local program
    if m.artifact and m.artifact ~= "" then
      program = m.artifact:sub(1, 1) == "/" and m.artifact or (root .. "/" .. m.artifact)
    elseif vim.uv.fs_stat(root .. "/CMakeLists.txt") then
      program = root .. "/build/debug/" .. m.target
    else
      program = root .. "/" .. m.target
    end
    return {
      name = "Debug " .. m.name .. " (GDB)",
      type = "gdb",
      request = "launch",
      program = program,
      cwd = root,
      stopAtBeginningOfMainSubprogram = false,
      nullptr_game = m.window == "yes", -- only windowed programs get the game workspace
    }
  elseif m.type == "gameboy" then
    return {
      name = "Debug " .. m.name .. " ROM (Emulicious)",
      type = "emulicious",
      request = "launch",
      program = root .. "/build/debug/" .. m.target .. ".gb",
      port = 58870,
      stopOnEntry = false,
      additionalSrcFolders = root .. "/src",
      nullptr_game = true,
    }
  end
end

--- Build a Debug version, then start the debugger. Breakpoints: Space d b (or F9).
---@param root string?
function M.debug(root)
  root = root or require_project()
  if not root then return end
  if root ~= M.active() then M.set_active(root) end
  local cfg = M.dap_config(root)
  if not cfg then return notify("Unknown project type in " .. root, vim.log.levels.ERROR) end
  if cfg.type == "emulicious" and vim.fn.executable "emulicious" == 0 then
    return notify("Emulicious is not installed. Run in a terminal: sudo nullptr-install-emulicious", vim.log.levels.ERROR)
  end
  M.term({ "build", "--debug", root }, function()
    local ok, dap = pcall(require, "dap")
    if not ok then return notify("nvim-dap is not available", vim.log.levels.ERROR) end
    M.setup_dap_listeners(dap)
    dap.run(cfg)
  end)
end

-- ---------------------------------------------------------------- new project
function M.new()
  local kinds = { "generic (plain C, CMake)", "raylib", "gameboy" }
  vim.ui.select(kinds, { prompt = "New project type" }, function(choice)
    if not choice then return end
    local kind = choice:match "^(%S+)"
    vim.ui.input({ prompt = "Project name (letters, digits, - _): " }, function(name)
      if not name or name == "" then return end
      local res = vim.system({ "nullptr-new", kind, name }, { text = true }):wait()
      if res.code ~= 0 then
        return notify(vim.trim((res.stderr or "") .. (res.stdout or "")), vim.log.levels.ERROR)
      end
      M.open(M.projects_dir .. "/" .. name)
    end)
  end)
end

function M.info()
  local root = M.current()
  if not root then return notify "No project selected" end
  local m = M.meta(root)
  notify(("Project: %s\nType:    %s\nRoot:    %s\nDebug:   %s"):format(m.name, m.type, root, (M.dap_config(root) or {}).program or "?"))
end

-- ---------------------------------------------------------------- setup
function M.setup()
  local group = vim.api.nvim_create_augroup("nullptr_project", { clear = true })
  -- Entering a file of another project makes that project active, so the
  -- shell commands (build / run-game / debug-game) follow what you edit.
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(args)
      if vim.bo[args.buf].buftype ~= "" then return end
      local name = vim.api.nvim_buf_get_name(args.buf)
      if name == "" or name:match "^%w+://" then return end
      local root = M.find_root(name)
      if root and root ~= M.active() then
        M.set_active(root)
        if M.find_root(vim.fn.getcwd()) ~= root then vim.cmd.cd(vim.fn.fnameescape(root)) end
      end
    end,
  })
  vim.api.nvim_create_user_command("NullptrOpen", function(o) M.open(o.args ~= "" and o.args or nil) end,
    { nargs = "?", complete = "dir", desc = "Open a project or file" })
  vim.api.nvim_create_user_command("NullptrBuild", function(o) M.build(o.bang and "release" or "debug") end,
    { bang = true, desc = "Build active project (! = release)" })
  vim.api.nvim_create_user_command("NullptrRun", function() M.run() end, { desc = "Run active project" })
  vim.api.nvim_create_user_command("NullptrDebug", function() M.debug() end, { desc = "Debug active project" })
  vim.api.nvim_create_user_command("NullptrProjects", function() M.pick() end, { desc = "Pick a project" })
end

return M
