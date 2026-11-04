-- Debug adapters (both talk the Debug Adapter Protocol directly; no Mason, no VS Code):
--   gdb         GDB >= 14 has a built-in DAP server:  gdb --interpreter=dap
--   emulicious  Emulicious *is* a DAP server: `emulicious -remotedebug PORT` listens on TCP.
--               (The VS Code "Emulicious Debugger" extension only spawns it and connects.)
---@type LazySpec
return {
  "mfussenegger/nvim-dap",
  config = function(plugin, opts)
    require "astronvim.plugins.configs.nvim-dap"(plugin, opts)
    local dap = require "dap"

    dap.adapters.gdb = {
      type = "executable",
      command = "gdb",
      args = { "--quiet", "--interpreter=dap", "--eval-command", "set print pretty on" },
    }

    local emulicious = {
      type = "server",
      port = "${port}",
      executable = { command = "emulicious", args = { "-remotedebug", "${port}" } },
      -- the JVM needs a few seconds to start Emulicious: retry for up to 30 s (250 ms steps)
      options = { max_retries = 120 },
    }
    dap.adapters.emulicious = emulicious
    dap.adapters["emulicious-debugger"] = emulicious -- name used by .vscode/launch.json

    -- `Space d c` / F5 inside a session pick the right configuration for the project.
    local project = require "nullptr.project"
    project.setup_dap_listeners(dap) -- game workspace while running, editor when stopped
    dap.providers.configs["nullptr"] = function()
      local root = project.current()
      local cfg = root and project.dap_config(root)
      return cfg and { cfg } or {}
    end
  end,
}
