-- nullptr Workstation: build / run / debug for ANY C project, with no per-target code here.
--
-- A project is just a folder: its git repository root (or, without git, the folder that has
-- the build file). Nothing has to be added to a repository you clone.
--
-- What Space m b / r / d do, in this order:
--   1. the project's own settings, if it has a `.nvim.lua` that returns a table
--      (Neovim asks once whether you trust that file):
--          return {
--            build   = "make -j8",              -- string (run by sh) or { "argv", ... }
--            run     = "mgba-qt build/game.gba", -- what Space m r runs
--            clean   = "make clean",
--            program = "build/game.elf",         -- what the debugger loads (and run, if no run=)
--            debug   = { ... },                  -- nvim-dap configuration(s), see docs/c-projects.md
--          }
--   2. `.vscode/launch.json` debug configurations (read by nvim-dap itself)
--   3. otherwise detection: CMakeLists.txt -> CMake + Ninja (Debug, compile_commands.json)
--                            Makefile        -> make, through `bear` so clangd understands it
--                            build.sh        -> ./build.sh
--      and the debugger is LLDB (lldb-dap) on the program the build produced.
local M = {}

local uv = vim.uv or vim.loop
local home = vim.env.HOME
M.projects_dir = vim.env.NW_PROJECTS_DIR or (home .. "/Projects")
local state_dir = (vim.env.XDG_STATE_HOME or (home .. "/.local/state")) .. "/nullptr"
local cwd_file = state_dir .. "/editor-cwd" -- read by Super+E, LazyGit (Ctrl+b 3), import-assets
local recent_file = state_dir .. "/recent-projects"
local targets_file = state_dir .. "/run-targets.json"

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "nullptr" }) end
local function exists(p) return uv.fs_stat(p) ~= nil end
local function norm(p) return vim.fs.normalize(uv.fs_realpath(p) or p) end

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
  local f = io.open(tmp, "w")
  if not f then return end
  f:write(text)
  f:close()
  uv.fs_rename(tmp, path)
end

-- ---------------------------------------------------------------- project root
local build_files = { "CMakeLists.txt", "Makefile", "makefile", "GNUmakefile", "build.sh" }

--- Project root for `path`: the git repository, else the nearest folder with a build file.
---@param path string?
---@return string?
function M.root(path)
  path = (path and path ~= "") and vim.fn.fnamemodify(path, ":p") or vim.fn.getcwd()
  local r = vim.fs.root(path, { ".git" }) or vim.fs.root(path, build_files)
  return r and norm(r) or nil
end

--- The project you are looking at: the current file's project, else the working folder's.
function M.current()
  local name = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype == "" and name ~= "" and not name:match "^%w+://" then
    local r = M.root(name)
    if r then return r end
  end
  return M.root(vim.fn.getcwd())
end

local function remember(root)
  write_atomic(cwd_file, root .. "\n")
  local recent = { root }
  for _, r in ipairs(read_lines(recent_file)) do
    if r ~= root and #recent < 20 and exists(r) then table.insert(recent, r) end
  end
  write_atomic(recent_file, table.concat(recent, "\n") .. "\n")
  if vim.env.TMUX then vim.system { "tmux", "refresh-client", "-S" } end
end

-- ---------------------------------------------------------------- per-project settings
local settings_cache = {}
--- The table returned by <root>/.nvim.lua ({} if there is none or you did not trust it).
---@param root string
function M.settings(root)
  local file = root .. "/.nvim.lua"
  local st = uv.fs_stat(file)
  if not st then return {} end
  local key = ("%d:%d"):format(st.mtime.sec, st.size)
  local c = settings_cache[root]
  if c and c.key == key then return c.value end
  local value = {}
  local src = vim.secure.read(file) -- asks once per version of the file: [v]iew, [d]eny, [a]llow
  if src then
    local chunk, err = load(src, "@" .. file)
    if not chunk then
      notify(".nvim.lua: " .. err, vim.log.levels.ERROR)
    else
      local ok, res = pcall(chunk)
      if not ok then
        notify(".nvim.lua: " .. tostring(res), vim.log.levels.ERROR)
      elseif type(res) == "table" then
        value = res
      end
    end
  end
  settings_cache[root] = { key = key, value = value }
  return value
end

local function as_cmd(c)
  if type(c) == "string" then return { "sh", "-c", c } end
  return c
end

-- ---------------------------------------------------------------- build system
--- How this project builds: { kind, configure?, build, clean }
---@param root string
function M.detect(root)
  local s = M.settings(root)
  if s.build then return { kind = ".nvim.lua", build = as_cmd(s.build), clean = s.clean and as_cmd(s.clean) } end
  local function has(f) return exists(root .. "/" .. f) end
  local jobs = tostring(#(uv.cpu_info() or { 1 }))
  if has "CMakeLists.txt" then
    return {
      kind = "CMake",
      configure = not has "build/CMakeCache.txt" and {
        "cmake", "-S", ".", "-B", "build", "-G", "Ninja",
        "-DCMAKE_BUILD_TYPE=Debug", "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
      } or nil,
      build = { "cmake", "--build", "build" },
      clean = { "cmake", "--build", "build", "--target", "clean" },
    }
  end
  for _, mk in ipairs { "Makefile", "makefile", "GNUmakefile" } do
    if has(mk) then
      local make = { "make", "-j" .. jobs }
      -- bear records the compiler commands -> compile_commands.json, so clangd knows the flags
      local build = vim.fn.executable "bear" == 1 and vim.list_extend({ "bear", "--append", "--" }, make) or make
      return { kind = "Make", build = build, clean = { "make", "clean" } }
    end
  end
  if has "build.sh" then return { kind = "build.sh", build = { "sh", "./build.sh" } } end
end

-- ---------------------------------------------------------------- terminal runner
local term_buf
--- Run `cmd` (argv) in `cwd` in a reusable terminal split at the bottom.
---@param cmd string[]
---@param opts { cwd: string, on_success: fun()?, keep: boolean? }
function M.term(cmd, opts)
  pcall(vim.cmd, "silent! wall")
  if term_buf and vim.api.nvim_buf_is_valid(term_buf) then pcall(vim.api.nvim_buf_delete, term_buf, { force = true }) end
  local origin = vim.api.nvim_get_current_win()
  vim.cmd "botright 14new"
  term_buf = vim.api.nvim_get_current_buf()
  vim.bo[term_buf].bufhidden = "wipe"
  local term_win = vim.api.nvim_get_current_win()
  vim.fn.jobstart(cmd, {
    term = true,
    cwd = opts.cwd,
    on_exit = function(_, code)
      vim.schedule(function()
        if code == 0 and opts.on_success then
          if not opts.keep and vim.api.nvim_win_is_valid(term_win) then pcall(vim.api.nvim_win_close, term_win, true) end
          opts.on_success()
        elseif code ~= 0 then
          notify(("`%s` failed (exit %d), see the terminal below"):format(table.concat(cmd, " "), code), vim.log.levels.ERROR)
        end
      end)
    end,
  })
  pcall(vim.api.nvim_buf_set_name, term_buf, "nullptr://" .. table.concat(cmd, " ") .. "#" .. term_buf)
  vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = term_buf, desc = "Close" })
  vim.cmd.stopinsert()
  vim.cmd "normal! G" -- follow the output
  if vim.api.nvim_win_is_valid(origin) then vim.api.nvim_set_current_win(origin) end
end

local function need_root()
  local root = M.current()
  if not root then notify("No project here. Open one: Space m p, or clone one: Space m g", vim.log.levels.WARN) end
  return root
end

--- Build the project, then call `after` (if given) when the build succeeded.
function M.build(after)
  local root = need_root()
  if not root then return end
  local b = M.detect(root)
  if not b then
    if after then return after(root) end -- nothing to build (e.g. a prebuilt program)
    return notify("No CMakeLists.txt, Makefile or build.sh in " .. root
      .. "\nTell AstroVim how to build it in .nvim.lua (see Space ?).", vim.log.levels.WARN)
  end
  local cmd = b.build
  if b.configure then
    cmd = { "sh", "-c", vim.fn.join(vim.tbl_map(vim.fn.shellescape, b.configure), " ")
      .. " && " .. vim.fn.join(vim.tbl_map(vim.fn.shellescape, b.build), " ") }
  end
  M.term(cmd, { cwd = root, on_success = function() if after then after(root) end end })
end

function M.clean()
  local root = need_root()
  if not root then return end
  local b = M.detect(root)
  if not (b and b.clean) then return notify("No clean command known for " .. root .. " (set clean= in .nvim.lua)") end
  M.term(b.clean, { cwd = root, keep = true, on_success = function() notify "Clean done" end })
end

-- ---------------------------------------------------------------- the program to run / debug
local function is_elf_program(path, name)
  if name:match "%.so[%.%d]*$" or name:match "%.[ao]$" then return false end
  if not uv.fs_access(path, "X") then return false end
  local f = io.open(path, "rb")
  if not f then return false end
  local magic = f:read(4)
  f:close()
  return magic == "\127ELF"
end

--- Programs the build produced, newest first.
function M.programs(root)
  local found = {}
  local skip = { CMakeFiles = true, _deps = true, [".git"] = true, node_modules = true, [".cache"] = true }
  local function scan(dir, depth)
    for name, t in vim.fs.dir(dir) do
      local p = dir .. "/" .. name
      if t == "directory" and depth > 0 and not skip[name] then
        scan(p, depth - 1)
      elseif t == "file" and is_elf_program(p, name) then
        table.insert(found, { path = p, mtime = uv.fs_stat(p).mtime.sec })
      end
    end
  end
  for _, d in ipairs { "build", "bin", "out" } do
    if exists(root .. "/" .. d) then scan(root .. "/" .. d, 4) end
  end
  scan(root, 0)
  table.sort(found, function(a, b) return a.mtime > b.mtime end)
  return vim.tbl_map(function(x) return x.path end, found)
end

local function load_targets()
  local f = io.open(targets_file, "r")
  if not f then return {} end
  local ok, t = pcall(vim.json.decode, f:read "*a")
  f:close()
  return ok and type(t) == "table" and t or {}
end

--- Ask which program to run/debug (and remember it for this project).
function M.choose_program(root, cb)
  root = root or need_root()
  if not root then return end
  local list = M.programs(root)
  if #list == 0 then
    return notify("No program found under build/, bin/ or out/. Build first (Space m b), or set program= in .nvim.lua.",
      vim.log.levels.WARN)
  end
  vim.ui.select(list, {
    prompt = "Program to run / debug",
    format_item = function(p) return p:sub(#root + 2) end,
  }, function(choice)
    if not choice then return end
    local t = load_targets()
    t[root] = choice
    write_atomic(targets_file, vim.json.encode(t))
    if cb then cb(choice) end
  end)
end

--- The program for `root`: .nvim.lua program=, else the remembered choice, else the only one.
function M.program(root, cb)
  local s = M.settings(root)
  if s.program then
    local p = s.program:sub(1, 1) == "/" and s.program or (root .. "/" .. s.program)
    return cb(p)
  end
  local remembered = load_targets()[root]
  if remembered and exists(remembered) then return cb(remembered) end
  local list = M.programs(root)
  if #list == 1 then return cb(list[1]) end
  M.choose_program(root, cb)
end

-- ---------------------------------------------------------------- run
function M.run()
  M.build(function(root)
    local s = M.settings(root)
    local cwd = s.cwd and (s.cwd:sub(1, 1) == "/" and s.cwd or root .. "/" .. s.cwd) or root
    if s.run then return M.term(as_cmd(s.run), { cwd = cwd, keep = true, on_success = function() end }) end
    M.program(root, function(p)
      -- a program that opens a window appears on workspace 6 (run); i3 brings you back when it closes
      M.term({ p }, { cwd = cwd, keep = true, on_success = function() end })
    end)
  end)
end

-- ---------------------------------------------------------------- i3 workspaces
-- keep in sync with config/dotfiles/i3/config and scripts/lib/nullptr-common.sh
local ws_names = {
  astro = "1: astro", firefox = "2: firefox", libresprite = "3: libresprite", tiled = "4: tiled",
  blockbench = "5: blockbench", run = "6: run", tools = "7: tools",
}
local function i3(args)
  if not (vim.env.DISPLAY and vim.fn.executable "i3-msg" == 1) then return end
  -- ignore I3SOCK: tmux (and this editor) may outlive an i3 restart and hold a dead path
  return vim.system(vim.list_extend({ "env", "-u", "I3SOCK", "i3-msg" }, args), { text = true })
end
function M.workspace(role)
  local j = i3 { "-q", "workspace number " .. ws_names[role] }
  return j
end
local function run_ws_has_windows()
  local j = i3 { "-t", "get_workspaces" }
  if not j then return false end
  local res = j:wait(1000)
  return (res.stdout or ""):find('"name":"6: run"', 1, true) ~= nil
end

-- While debugging: the editor comes back whenever the program stops (breakpoint, step);
-- a program window on workspace 6 is shown again while it runs.
function M.setup_dap_listeners(dap)
  if M._listeners then return end
  M._listeners = true
  dap.listeners.after.event_stopped.nullptr_ws = function() M.workspace "astro" end
  dap.listeners.after.event_continued.nullptr_ws = function(session)
    vim.defer_fn(function() -- debounce: stepping stops again within milliseconds
      if dap.session() == session and not session.stopped_thread_id and run_ws_has_windows() then M.workspace "run" end
    end, 400)
  end
  for _, ev in ipairs { "event_terminated", "event_exited" } do
    dap.listeners.after[ev].nullptr_ws = function() M.workspace "astro" end
  end
end

-- ---------------------------------------------------------------- debug
M._program = nil
--- Default debug configuration (used when the project defines none): LLDB on the program.
function M.default_debug_config(root, program)
  local lldb = vim.fn.executable "lldb-dap" == 1 or vim.fn.executable "lldb-dap-19" == 1
  return {
    name = ("Debug %s (%s)"):format(vim.fs.basename(program), lldb and "LLDB" or "GDB"),
    type = lldb and "lldb" or "gdb",
    request = "launch",
    program = program,
    cwd = root,
    args = {},
    stopOnEntry = false,
    stopAtBeginningOfMainSubprogram = false,
  }
end

--- Configurations nvim-dap offers from this module ("nullptr" provider): .nvim.lua debug=,
--- else the default LLDB launch of the program. launch.json / dap.configurations come on top.
function M.dap_configs()
  local root = M.current()
  if not root then return {} end
  local s = M.settings(root)
  if s.debug then
    local list = vim.islist(s.debug) and s.debug or { s.debug }
    return vim.deepcopy(list)
  end
  if exists(root .. "/.vscode/launch.json") then return {} end -- the project chose its own
  if M._program and M._program_root == root then return { M.default_debug_config(root, M._program) } end
  return {}
end

--- Build, then start the debugger. Breakpoints: F9.
function M.debug()
  local ok, dap = pcall(require, "dap")
  if not ok then return notify("nvim-dap is not available", vim.log.levels.ERROR) end
  M.setup_dap_listeners(dap)
  M.build(function(root)
    if vim.fn.getcwd() ~= root then vim.cmd.cd(vim.fn.fnameescape(root)) end -- launch.json is read from here
    local s = M.settings(root)
    if s.debug or exists(root .. "/.vscode/launch.json") then return dap.continue() end
    M.program(root, function(p)
      M._program, M._program_root = p, root
      dap.continue()
    end)
  end)
end

-- ---------------------------------------------------------------- projects
--- Open a project folder (or a file): working folder = its project root.
function M.open(path)
  path = path and vim.fs.normalize(vim.fn.fnamemodify(path, ":p")) or M.projects_dir
  local is_dir = vim.fn.isdirectory(path) == 1
  local root = M.root(path) or (is_dir and norm(path)) or nil
  if root then
    vim.cmd.cd(vim.fn.fnameescape(root))
    remember(root)
  end
  if not is_dir then return vim.cmd.edit(vim.fn.fnameescape(path)) end
  if root and root == norm(path) then
    local okr, resession = pcall(require, "resession")
    if okr and pcall(resession.load, root, { dir = "dirsession", silence_errors = true }) then
      local name = vim.api.nvim_buf_get_name(0)
      if vim.bo.buftype == "" and name ~= "" and M.root(name) == root then return end
    end
    for _, f in ipairs { "README.md", "readme.md", "README" } do
      if exists(root .. "/" .. f) then
        vim.cmd.edit(vim.fn.fnameescape(root .. "/" .. f))
        break
      end
    end
  end
  pcall(vim.cmd, "Neotree show reveal_force_cwd dir=" .. vim.fn.fnameescape(root or path))
end

--- Folders in ~/Projects plus recently used projects elsewhere.
function M.list()
  local out, seen = {}, {}
  local function add(p)
    p = vim.fs.normalize(p)
    if not seen[p] and vim.fn.isdirectory(p) == 1 then
      seen[p] = true
      table.insert(out, p)
    end
  end
  for _, r in ipairs(read_lines(recent_file)) do add(r) end
  local rest = {}
  for name, t in vim.fs.dir(M.projects_dir) do
    if t == "directory" and name:sub(1, 1) ~= "." then table.insert(rest, M.projects_dir .. "/" .. name) end
  end
  table.sort(rest)
  for _, p in ipairs(rest) do add(p) end
  return out
end

function M.pick()
  local list = M.list()
  if #list == 0 then return notify("~/Projects is empty. Clone a project: Space m g", vim.log.levels.WARN) end
  vim.ui.select(list, {
    prompt = "Open project",
    format_item = function(p) return ("%-28s %s"):format(vim.fs.basename(p), p) end,
  }, function(choice) if choice then M.open(choice) end end)
end

--- Clone a repository into ~/Projects (with submodules) and open it.
function M.clone()
  vim.ui.input({ prompt = "Clone (owner/repo or git URL): " }, function(spec)
    spec = spec and vim.trim(spec) or ""
    if spec == "" then return end
    local url = spec
    if spec:match "^[%w%._-]+/[%w%._-]+$" then url = "https://github.com/" .. spec .. ".git" end
    local name = (url:match "([^/:]+)$" or "project"):gsub("%.git$", "")
    local dest = M.projects_dir .. "/" .. name
    if exists(dest) then return notify(dest .. " already exists; opening it") or M.open(dest) end
    vim.fn.mkdir(M.projects_dir, "p")
    M.term({ "git", "clone", "--recurse-submodules", url, dest },
      { cwd = M.projects_dir, on_success = function() M.open(dest) end })
  end)
end

function M.info()
  local root = M.current()
  if not root then return notify "No project here" end
  local b = M.detect(root)
  local s = M.settings(root)
  local lines = {
    "Project:  " .. root,
    "Build:    " .. (b and (b.kind .. ": " .. table.concat(b.build, " ")) or "nothing detected"),
    "Settings: " .. (exists(root .. "/.nvim.lua") and (next(s) and ".nvim.lua (trusted)" or ".nvim.lua (not trusted / returns no table)") or "none"),
    "Debug:    " .. (s.debug and ".nvim.lua debug=" or exists(root .. "/.vscode/launch.json") and ".vscode/launch.json"
      or "LLDB on the program"),
    "Program:  " .. (s.program or load_targets()[root] or "(asked on first run)"),
  }
  notify(table.concat(lines, "\n"))
end

-- ---------------------------------------------------------------- setup
function M.setup()
  local group = vim.api.nvim_create_augroup("nullptr_project", { clear = true })
  -- Opening a file of another project makes its folder the working folder, so the
  -- terminal tools (Super+E, LazyGit, import-assets) follow what you edit.
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(args)
      if vim.bo[args.buf].buftype ~= "" then return end
      local name = vim.api.nvim_buf_get_name(args.buf)
      if name == "" or name:match "^%w+://" then return end
      local root = M.root(name)
      if root and root ~= M.root(vim.fn.getcwd()) then vim.cmd.cd(vim.fn.fnameescape(root)) end
    end,
  })
  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function() remember(M.root(vim.fn.getcwd()) or norm(vim.fn.getcwd())) end,
  })
  local cmd = vim.api.nvim_create_user_command
  cmd("NullptrOpen", function(o) M.open(o.args ~= "" and o.args or nil) end, { nargs = "?", complete = "dir", desc = "Open a project or file" })
  cmd("NullptrBuild", function() M.build() end, { desc = "Build the project" })
  cmd("NullptrRun", function() M.run() end, { desc = "Build and run the project" })
  cmd("NullptrDebug", function() M.debug() end, { desc = "Build and debug the project" })
  cmd("NullptrClone", function() M.clone() end, { desc = "Clone a repository into ~/Projects" })
  cmd("NullptrProjects", function() M.pick() end, { desc = "Pick a project" })
end

return M
