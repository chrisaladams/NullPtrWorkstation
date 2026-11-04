-- Everything the workstation needs comes from Debian or the image build.
-- Mason stays available (Space p m) but installs nothing automatically.
---@type LazySpec
return {
  { "WhoIsSethDaniel/mason-tool-installer.nvim", opts = { ensure_installed = {}, run_on_start = false } },
  { "mason-org/mason-lspconfig.nvim", opts = { ensure_installed = {}, automatic_enable = false } },
}
