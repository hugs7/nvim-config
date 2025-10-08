require("nvim-tree").setup({
  on_attach = function(bufnr)
    local api = require("nvim-tree.api")

    local function opts(desc)
      return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
    end

    -- load defaults first, then override/remove what you don't want
    api.config.mappings.default_on_attach(bufnr)

    -- remove the Ctrl-based split mappings that conflict with terminal paste
    pcall(vim.keymap.del, "n", "<C-v>", { buffer = bufnr })
    pcall(vim.keymap.del, "n", "<C-x>", { buffer = bufnr })
    pcall(vim.keymap.del, "n", "<C-t>", { buffer = bufnr })

    -- your custom split/tab mappings
    vim.keymap.set("n", "V", api.node.open.vertical, opts("Open: Vertical Split"))
    vim.keymap.set("n", "S", api.node.open.horizontal, opts("Open: Horizontal Split"))
    vim.keymap.set("n", "T", api.node.open.tab, opts("Open: New Tab"))
  end,
  tab = {
    sync = {
      open = true,  -- open tree in all tabs
      close = true, -- close tree in all tabs when last tab closes
    },
  },
  update_focused_file = {
    enable = true,
    update_root = false,
    ignore_list = {},
  },
  view = {
    width = 35,
    preserve_window_proportions = true,
  },
  filters = {
    git_ignored = false,
    dotfiles = false,
    custom = {},
  },
  git = {
    enable = true,
    ignore = false,
  },
})

-- =========================
-- Keymaps
-- =========================

-- Clear the active live filter
vim.keymap.set("n", "<leader>cf", function()
  require("nvim-tree.api").live_filter.clear()
end, { desc = "Clear NvimTree filter" })

-- Toggle file tree
vim.keymap.set("n", "<leader>b", function()
  require("nvim-tree.api").tree.toggle({ focus = false })
end, { noremap = true, silent = true, desc = "Toggle file tree" })

-- Focus file tree
vim.keymap.set("n", "<leader>e", function()
  require("nvim-tree.api").tree.focus()
end, { noremap = true, silent = true, desc = "Focus file tree" })

-- Reveal current file in tree
vim.keymap.set("n", "<leader>r", function()
  require("nvim-tree.api").tree.find_file({ open = true, focus = true })
end, { desc = "Reveal current file in tree" })

-- Clear all buffers
vim.api.nvim_create_user_command("Bda", "bufdo bw", { bang = true })
