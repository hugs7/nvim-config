--- Mason + LSP setup
require("mason").setup()

require("mason-lspconfig").setup({
  ensure_installed = { "ts_ls", "lua_ls", "jsonls", "html", "cssls", "tailwindcss" },
})
