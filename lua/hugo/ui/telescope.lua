-- =========================
-- Telescope Setup
-- =========================
require('telescope').setup({
  defaults = {
    file_ignore_patterns = { "node_modules/", ".git/", "dist/", "build/", ".next/" },
  },
  pickers = {
    find_files = {
      hidden = true,  -- Show hidden files (files starting with .)
      no_ignore = true,  -- Include gitignored files
      no_ignore_parent = true,  -- Include files ignored by parent .gitignore
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

-- Search selected text in visual mode
vim.keymap.set("v", "<leader>fw", function()
  -- Exit visual mode and get the selected text
  vim.cmd('normal! "vy')
  local selected_text = vim.fn.getreg('v')
  
  if selected_text and selected_text ~= "" then
    builtin.grep_string({ search = selected_text })
  else
    print("No text selected")
  end
end, { desc = "Find selected text" })
