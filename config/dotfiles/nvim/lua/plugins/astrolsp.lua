-- C language intelligence: system clangd (clang-tidy runs inside clangd).
-- Formatting is done by clang-format through none-ls (see none-ls.lua).
---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    features = { codelens = true, inlay_hints = false, semantic_tokens = true },
    formatting = {
      format_on_save = { enabled = false }, -- format on demand: Space l f
      disabled = { "clangd" }, -- clang-format (none-ls) formats C files
      timeout_ms = 3000,
    },
    servers = { "clangd" }, -- installed from Debian, not Mason
    config = {
      clangd = {
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--header-insertion=never",
          "--completion-style=detailed",
          "--function-arg-placeholders=true",
          "--fallback-style=llvm",
          -- let clangd ask cross compilers (devkitARM, other toolchains under /opt or ~)
          -- for their system headers, so any target works without editing this file
          "--query-driver=/usr/bin/*,/usr/local/bin/*,/opt/**/bin/*," .. vim.env.HOME .. "/**/bin/*",
        },
        capabilities = { offsetEncoding = { "utf-8" } },
        root_markers = { "compile_commands.json", ".clangd", ".git" },
      },
    },
  },
}
