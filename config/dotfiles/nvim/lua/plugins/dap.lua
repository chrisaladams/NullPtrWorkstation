-- Debuggers (all speak the Debug Adapter Protocol directly; no Mason, no VS Code):
--   lldb      LLVM's lldb-dap (the clang toolchain's debugger)         type = "lldb" / "lldb-dap"
--   gdb       GDB >= 14 has a built-in DAP server: gdb --interpreter=dap  type = "gdb"
--   gdb-multiarch  the same for other CPUs (ARM for GBA, remote stubs)  type = "gdb-multiarch"
-- Which one a project uses, and how, lives in the project (.vscode/launch.json or .nvim.lua),
-- never here. Without either, F5 debugs the program the build produced with LLDB.
---@type LazySpec
return {
  "mfussenegger/nvim-dap",
  config = function(plugin, opts)
    require "astronvim.plugins.configs.nvim-dap"(plugin, opts)
    local dap = require "dap"

    local lldb_dap = vim.fn.exepath "lldb-dap"
    if lldb_dap == "" then lldb_dap = vim.fn.exepath "lldb-dap-19" end
    dap.adapters.lldb = { type = "executable", command = lldb_dap ~= "" and lldb_dap or "lldb-dap", name = "lldb" }
    dap.adapters["lldb-dap"] = dap.adapters.lldb

    local function gdb(cmd)
      return { type = "executable", command = cmd, args = { "--quiet", "--interpreter=dap", "--eval-command", "set print pretty on" } }
    end
    dap.adapters.gdb = gdb "gdb"
    dap.adapters["gdb-multiarch"] = gdb "gdb-multiarch"

    -- configurations from the project (.nvim.lua debug=) or the default LLDB launch;
    -- .vscode/launch.json and dap.configurations are added by nvim-dap itself
    local project = require "nullptr.project"
    project.setup_dap_listeners(dap)
    dap.providers.configs["nullptr"] = function() return project.dap_configs() end
  end,
}
