-- =========================
-- Pane Navigation Shortcuts
-- =========================
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-l>", "<C-w>l")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-j>", "<C-w>j")

-- =========================
-- Quality of life keymaps
-- =========================

-- Ctrl+Backspace → delete previous word
vim.keymap.set("i", "<C-H>", "<C-w>", { noremap = true })

-- Ctrl+Delete → delete next word
vim.keymap.set("i", "<C-Del>", "<C-o>de", { noremap = true })

-- Focus editor
vim.keymap.set("n", "<leader>ee", "<C-w>l", { noremap = true, silent = true, desc = "Focus editor" })

-- Find file by name
vim.keymap.set("n", "<C-p>", ":Telescope find_files<CR>", { noremap = true, silent = true, desc = "Quick Open" })

-- Adjust Nvim Tree Width
vim.keymap.set("n", "<leader>=", "<cmd>vertical resize +5<CR>", { desc = "Increase NvimTree width" })
vim.keymap.set("n", "<leader>-", "<cmd>vertical resize -5<CR>", { desc = "Decrease NvimTree width" })

-- Copy open file path
vim.keymap.set('n', '<leader>cp', function()
  local abs = vim.fn.expand('%:p')
  local rel = vim.fn.fnamemodify(abs, ':.')
  vim.fn.setreg('+', rel)
  print("Copied path: " .. rel)
end)

vim.keymap.set("n", "<leader>rr", function()
  vim.cmd("restart")
end, { desc = "Restart Neovim and restore buffers" })

-- Braile--
local is_braille_active = false

vim.keymap.set("n", "<leader>br", function()
  local braille = require("hugo.ui.braille")

  if is_braille_active then
    braille.clear()
  else
    braille.overlay()
  end

  is_braille_active = not is_braille_active
end, { desc = "Toggle Braille overlay" })

-- =========================
-- TypeScript Keymaps
-- =========================
local typescript = require("hugo.langs.typescript")
vim.keymap.set("n", "<leader>fi", typescript.fix_imports_sequential, { desc = "Fix imports (remove unused + organize)" })

-- =========================
-- React Component Creation
-- =========================
local react_components = require("hugo.utils.react-components")
local react_component_test = require("hugo.utils.react-component-test")
local react_hooks = require('hugo.utils.react-hooks')
local react_providers = require('hugo.utils.react-providers')
local barrel = require('hugo.utils.barrel')

vim.keymap.set("n", "<leader>rc", react_components.create_component, { desc = "Create React component" })
vim.keymap.set("n", "<leader>rct", react_components.create_component_with_types,
  { desc = "Create React component with types" })
vim.keymap.set("n", "<leader>rcv", react_component_test.generate_react_test, { desc = "Create React component test" })

vim.keymap.set("n", "<leader>rh", react_hooks.create_hook, { desc = "Create React hook" })
vim.keymap.set("n", "<leader>rht", react_hooks.create_hook_with_types, { desc = "Create React hook with types" })

vim.keymap.set("n", "<leader>rp", react_providers.create_provider, { desc = "Create React Provider" })

vim.keymap.set("n", "<leader>bf", barrel.generate_barrel_export, { desc = "Generate barrel file" })
