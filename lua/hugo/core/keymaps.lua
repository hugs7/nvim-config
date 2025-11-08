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

-- Braile
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
