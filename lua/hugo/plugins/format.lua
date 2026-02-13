local format_config = {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      javascript = { "prettier" },
      typescript = { "prettier" },
      javascriptreact = { "prettier" },
      typescriptreact = { "prettier" },
      json = { "prettier" },
      html = { "prettier" },
      css = { "prettier" },
      markdown = { "prettier" },
      yaml = { "prettier" },
    },
    format_on_save = {
      timeout_ms = 1000,
      lsp_fallback = true,
    },
    formatters = {
      prettier = {
        command = "prettier",
        args = { "--stdin-filepath", "$FILENAME", "--single-quote" },
      },
    },
  },
}

-- =========================
-- Keymaps
-- =========================

-- Reusable format function
local function format_buffer()
  require("conform").format({ async = true, lsp_fallback = true })
end

-- Format
vim.api.nvim_create_user_command("Format", function()
  format_buffer()
end, { desc = "Format current buffer" })

-- Export for use in other modules
local M = {
  config = format_config,
  format_buffer = format_buffer,
}

return M
