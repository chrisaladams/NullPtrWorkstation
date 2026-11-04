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
        },
        capabilities = { offsetEncoding = { "utf-8" } },
        root_markers = { ".nullptr-project", "compile_commands.json", ".clangd", ".git" },
      },
    },
  },
}
