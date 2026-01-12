-- =========================
-- TypeScript Import Helpers
-- =========================
local M = {}

local function organize_imports(bufnr)
  vim.lsp.buf.execute_command({
    command = "_typescript.organizeImports",
    arguments = { vim.api.nvim_buf_get_name(bufnr or 0) },
  })
end

local function remove_unused()
  vim.lsp.buf.code_action({
    apply = true,
    context = {
      only = { "source.removeUnused.ts" },
      diagnostics = {},
    },
  })
end

local function fix_imports_sequential()
  -- Remove unused imports first
  vim.lsp.buf.code_action({
    apply = true,
    context = {
      only = { "source.removeUnused.ts" },
      diagnostics = {},
    },
  })
  
  -- Wait a bit then organize imports to avoid timing issues
  vim.defer_fn(function()
    organize_imports(0)

    -- Run formatter after organizing imports
    require("hugo.plugins.format").format_buffer()
  end, 100)
end

-- Export the function for use in keymaps
M.fix_imports_sequential = fix_imports_sequential

vim.api.nvim_create_user_command("SortImports", function()
  organize_imports(0)
end, { desc = "Sort/Organize TypeScript imports" })

vim.api.nvim_create_user_command("RemoveUnused", function()
  remove_unused()
end, { desc = "Remove unused TypeScript imports" })

vim.api.nvim_create_user_command("FixImports", function()
  fix_imports_sequential()
end, { desc = "Sort and remove unused imports" })

return M
