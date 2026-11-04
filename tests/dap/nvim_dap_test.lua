-- Headless nvim-dap test using the workstation's real AstroNvim config and nullptr.project.
-- env: NW_TEST_ROOT (project root), NW_TEST_LINE (breakpoint line), NW_TEST_VAR (variable),
--      NW_TEST_OUT (json report path), NW_TEST_FILE (source file, default src/main.c)
local root = assert(vim.env.NW_TEST_ROOT)
local line = tonumber(vim.env.NW_TEST_LINE)
local var = vim.env.NW_TEST_VAR
local out = vim.env.NW_TEST_OUT or "/tmp/nvim-dap-report.json"
local file = root .. "/" .. (vim.env.NW_TEST_FILE or "src/main.c")
local report = { root = root, breakpoint = file .. ":" .. line, nvim = tostring(vim.version()) }
local function finish(ok)
  report.PASS = ok
  vim.fn.writefile({ vim.json.encode(report) }, out)
  pcall(function() require("dap").terminate() end)
  vim.defer_fn(function() vim.cmd "qa!" end, 1500)
end
vim.schedule(function()
  local ok, err = pcall(function()
    local dap = require "dap"
    local project = require "nullptr.project"
    vim.cmd.edit(vim.fn.fnameescape(file))
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    dap.toggle_breakpoint()
    local cfg = assert(project.dap_config(root), "no dap config")
    report.adapter = cfg.type
    report.program = cfg.program
    report.stops = {}
    dap.listeners.after.event_stopped.nwtest = function(_, body)
      table.insert(report.stops, { reason = body.reason, description = body.description, text = body.text })
    end
    dap.listeners.after.event_output.nwtest = function(_, body)
      if body.category == "console" or body.category == "important" then
        report.console = (report.console or "") .. body.output
      end
    end
    dap.run(cfg)
    local function wait_stopped(ms)
      return vim.wait(ms, function()
        local s = dap.session()
        return s ~= nil and s.stopped_thread_id ~= nil and s.current_frame ~= nil
      end, 100)
    end
    if not wait_stopped(tonumber(vim.env.NW_TEST_TIMEOUT or 120) * 1000) then error "never stopped at breakpoint" end
    local s = dap.session()
    report.stopped_line = s.current_frame.line
    report.stopped_frame = s.current_frame.name
    -- call stack
    local frames
    s:request("stackTrace", { threadId = s.stopped_thread_id, levels = 10 }, function(e, r) frames = r and r.stackFrames or {} end)
    vim.wait(5000, function() return frames ~= nil end)
    report.call_stack = vim.tbl_map(function(f) return f.name end, frames)
    -- variables
    local scopes
    s:request("scopes", { frameId = s.current_frame.id }, function(e, r) scopes = r and r.scopes or {} end)
    vim.wait(5000, function() return scopes ~= nil end)
    for _, sc in ipairs(scopes) do
      local vars
      s:request("variables", { variablesReference = sc.variablesReference }, function(e, r) vars = r and r.variables or {} end)
      vim.wait(5000, function() return vars ~= nil end)
      for _, v in ipairs(vars) do
        if v.name == var then report.variable = { name = v.name, value = v.value, scope = sc.name, type = v.type } end
      end
    end
    -- step over
    local before = s.current_frame.line
    dap.step_over()
    vim.wait(30000, function()
      local ss = dap.session()
      return ss and ss.stopped_thread_id and ss.current_frame and ss.current_frame.line ~= before
    end, 100)
    report.after_step_line = dap.session().current_frame.line
    -- continue: the loop comes back to the breakpoint
    dap.continue()
    vim.wait(500)
    if wait_stopped(60000) then report.after_continue_line = dap.session().current_frame.line end
    finish(report.stopped_line == line and report.variable ~= nil)
  end)
  if not ok then
    report.error = tostring(err)
    finish(false)
  end
end)
