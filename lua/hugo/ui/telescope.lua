-- =========================
-- Telescope Setup
-- =========================
require('telescope').setup({
  defaults = {
    file_ignore_patterns = { "node_modules", ".git/" },
  },
  pickers = {
    find_files = {
      hidden = true,  -- Show hidden files (files starting with .)
    },
  },
})

-- =========================
-- Telescope keymaps
-- =========================
local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", builtin.find_files, {})
vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
vim.keymap.set("n", "<leader>fh", builtin.help_tags, {})
vim.keymap.set("n", "<leader>fw", builtin.grep_string, { desc = "Find word under cursor" })
