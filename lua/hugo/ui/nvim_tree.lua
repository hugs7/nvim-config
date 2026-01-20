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
    enable = false, -- Disabled in favor of custom autocmd below
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
  require("nvim-tree.api").tree.find_file({ open = true, focus = true })
end, { noremap = true, silent = true, desc = "Focus file tree" })

-- Clear all buffers
vim.api.nvim_create_user_command("Bda", "bufdo bw", { bang = true })

-- Custom autocmd that avoids focusing symlinks in node_modules
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    local api = require("nvim-tree.api")
    if not api.tree.is_visible() then
      return
    end

    local bufpath = vim.fn.expand("%:p")
    if bufpath == "" or vim.fn.filereadable(bufpath) == 0 then
      return
    end

    vim.notify("=== nvim-tree debug ===", vim.log.levels.TRACE)
    vim.notify("bufpath: " .. bufpath, vim.log.levels.TRACE)

    -- Skip if buffer itself is in node_modules
    if bufpath:match("/node_modules/") then
      vim.notify("Skipping: buffer is in node_modules", vim.log.levels.TRACE)
      vim.notify("=======================", vim.log.levels.TRACE)
      return
    end

    -- Resolve symlinks to get real path
    local realpath = vim.fn.resolve(bufpath)
    vim.notify("realpath: " .. realpath, vim.log.levels.TRACE)
    
    -- Use realpath for finding
    vim.notify("Finding file: " .. realpath, vim.log.levels.TRACE)
    
    -- Collapse node_modules in the tree before calling find_file, so it can't match files there
    local core = require("nvim-tree.core")
    local lib = require("nvim-tree.lib")
    local cwd = vim.fn.getcwd()
    local node_modules_path = cwd .. "/node_modules"
    vim.notify("node_modules_path: " .. node_modules_path, vim.log.levels.TRACE)

    local function collapse_node_modules(node)
      if node and node.absolute_path == node_modules_path and node.open then
        vim.notify("Collapsing node_modules before find_file", vim.log.levels.TRACE)
        api.node.collapse(node)
        vim.notify("Used api.node.collapse on node_modules", vim.log.levels.TRACE)
        return
      end
      if node and node.nodes then
        for _, child in ipairs(node.nodes) do
          collapse_node_modules(child)
        end
      end
    end

    local tree_root = core.get_explorer()
    vim.notify("tree_root: " .. tostring(tree_root), vim.log.levels.TRACE)
    if tree_root then
      collapse_node_modules(tree_root)
    end

    vim.notify("Finding file in nvim-tree: " .. realpath, vim.log.levels.TRACE)
    
    -- Now find the file
    api.tree.find_file({ path = realpath, open = true, focus = false })
    vim.notify("=======================", vim.log.levels.TRACE)
  end,
})
