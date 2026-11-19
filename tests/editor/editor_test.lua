-- Headless test of AstroVim's project support, using the real config (nullptr.project + nvim-dap),
-- exactly as Space m b / F5 would run it. No project-specific code is involved.
-- env: NW_TEST_ROOT   project folder
--      NW_TEST_LINE   breakpoint line in NW_TEST_FILE (default main.c)
--      NW_TEST_VAR    variable to read at the breakpoint
--      NW_TEST_OUT    json report
--      NW_TEST_TRUST  "1": trust the project's .nvim.lua first (normally Neovim asks once)
local root = assert(vim.env.NW_TEST_ROOT)
local line = tonumber(vim.env.NW_TEST_LINE)
local var = vim.env.NW_TEST_VAR
local out = vim.env.NW_TEST_OUT or "/tmp/nw-editor-test.json"
local file = root .. "/" .. (vim.env.NW_TEST_FILE or "main.c")
local report = { root = root, nvim = tostring(vim.version()) }

local function finish(ok)
  report.PASS = ok and true or false
  vim.fn.writefile({ vim.json.encode(report) }, out)
  pcall(function() require("dap").terminate() end)
  vim.defer_fn(function() vim.cmd "qa!" end, 1500)
end

vim.schedule(function()
  local ok, err = pcall(function()
    if vim.env.NW_TEST_TRUST == "1" then assert(vim.secure.trust { action = "allow", path = root .. "/.nvim.lua" }) end
    local project = require "nullptr.project"
    local dap = require "dap"
    project.open(file) -- like opening the file from the project picker
    report.cwd = vim.fn.getcwd()
    local b = project.detect(root)
    report.build_kind = b and b.kind
    report.build_cmd = b and table.concat(b.build, " ")

    -- clangd (after a build, for compile_commands.json) -------------------------
    local built = false
    project.build(function() built = true end)
    if not vim.wait(240000, function() return built end, 200) then error "build did not finish" end
    report.compile_commands = vim.uv.fs_stat(root .. "/compile_commands.json") ~= nil
      or vim.uv.fs_stat(root .. "/build/compile_commands.json") ~= nil
    report.programs = vim.tbl_map(function(p) return p:sub(#root + 2) end, project.programs(root))
    vim.cmd.edit(vim.fn.fnameescape(file))
    vim.wait(20000, function() return #vim.lsp.get_clients { name = "clangd", bufnr = 0 } > 0 end, 200)
    report.clangd_attached = #vim.lsp.get_clients { name = "clangd", bufnr = 0 } > 0

    -- debug: breakpoint, F5 ------------------------------------------------------
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    dap.toggle_breakpoint()
    report.stops = {}
    dap.listeners.after.event_stopped.nwtest = function(_, body) table.insert(report.stops, body.reason) end
    project.debug()
    local function wait_stopped(ms)
      return vim.wait(ms, function()
        local s = dap.session()
        return s ~= nil and s.stopped_thread_id ~= nil and s.current_frame ~= nil
      end, 100)
    end
    if not wait_stopped(180000) then error "never stopped at the breakpoint" end
    local s = dap.session()
    report.adapter = s.config.type
    report.config_name = s.config.name
    report.stopped_line = s.current_frame.line
    local scopes
    s:request("scopes", { frameId = s.current_frame.id }, function(_, r) scopes = r and r.scopes or {} end)
    vim.wait(5000, function() return scopes ~= nil end)
    for _, sc in ipairs(scopes or {}) do
      local vars
      s:request("variables", { variablesReference = sc.variablesReference }, function(_, r) vars = r and r.variables or {} end)
      vim.wait(5000, function() return vars ~= nil end)
      for _, v in ipairs(vars or {}) do
        if v.name == var then report.variable = { name = v.name, value = v.value } end
      end
    end
    -- the line where the debugger really is, asked from the debugger (not cached state)
    local function where()
      local ss = dap.session()
      if not (ss and ss.stopped_thread_id) then return nil end
      local got
      ss:request("stackTrace", { threadId = ss.stopped_thread_id, levels = 1 }, function(_, r)
        got = r and r.stackFrames and r.stackFrames[1] and r.stackFrames[1].line or -1
      end)
      vim.wait(5000, function() return got ~= nil end, 50)
      return got
    end
    -- step over: wait for its stopped event, then let nvim-dap settle
    local n = #report.stops
    dap.step_over()
    vim.wait(30000, function() return #report.stops > n end, 100)
    vim.wait(1000)
    report.after_step_line = where()
    -- continue: the loop comes back to the breakpoint
    n = #report.stops
    dap.continue()
    vim.wait(60000, function() return #report.stops > n end, 100)
    vim.wait(1000)
    report.after_continue_line = where()
    finish(report.stopped_line == line and report.variable ~= nil and report.after_continue_line == line)
  end)
  if not ok then
    report.error = tostring(err)
    finish(false)
  end
end)
