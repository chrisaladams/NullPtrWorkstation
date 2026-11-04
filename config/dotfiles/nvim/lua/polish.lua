-- Runs last: nullptr project integration and small quality-of-life settings.
require("nullptr.project").setup()

-- Markdown: wrap and spell-check prose
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "gitcommit" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.spell = true
  end,
})

-- clangd: Space l w switches between foo.c and foo.h
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == "clangd" then
      vim.keymap.set("n", "<Leader>lw", "<Cmd>LspClangdSwitchSourceHeader<CR>",
        { buffer = args.buf, desc = "Switch source/header (.c/.h)" })
    end
  end,
})
