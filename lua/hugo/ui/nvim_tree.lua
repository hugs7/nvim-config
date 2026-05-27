local M = {}

local DEFAULT_TREE_WIDTH = 35
local MIN_TREE_WIDTH = 20
local MIN_EDITOR_WIDTH = 50
local initial_root = (vim.uv or vim.loop).cwd() or vim.fn.getcwd()
local nvim_tree_width = DEFAULT_TREE_WIDTH

local function max_tree_width()
    return math.max(MIN_TREE_WIDTH, vim.o.columns - MIN_EDITOR_WIDTH)
end

local function clamp_tree_width(width)
    return math.max(MIN_TREE_WIDTH, math.min(width, max_tree_width()))
end

local function get_tree_win()
    local ok, view = pcall(require, "nvim-tree.view")
    if not ok then
        return nil
    end
    local win = view.get_winnr()
    if win and vim.api.nvim_win_is_valid(win) then
        return win
    end
    return nil
end

local function apply_tree_width()
    local win = get_tree_win()
    if not win then
        return
    end

    nvim_tree_width = clamp_tree_width(nvim_tree_width)
    vim.wo[win].winfixwidth = true

    if vim.api.nvim_win_get_width(win) ~= nvim_tree_width then
        vim.api.nvim_win_set_width(win, nvim_tree_width)
    end
end

function M.set_width(width)
    nvim_tree_width = clamp_tree_width(width)
    vim.schedule(apply_tree_width)
end

function M.adjust_width(delta)
    M.set_width(nvim_tree_width + delta)
end

function M.restore_width()
    vim.schedule(apply_tree_width)
end

require("nvim-tree").setup({
    on_attach = function(bufnr)
        local api = require("nvim-tree.api")

        local function opts(desc)
            return {
                desc = "nvim-tree: " .. desc,
                buffer = bufnr,
                noremap = true,
                silent = true,
                nowait = true
            }
        end

        -- load defaults first, then override/remove what you don't want
        api.config.mappings.default_on_attach(bufnr)

        -- remove the Ctrl-based split mappings that conflict with terminal paste
        pcall(vim.keymap.del, "n", "<C-v>", {
            buffer = bufnr
        })
        pcall(vim.keymap.del, "n", "<C-x>", {
            buffer = bufnr
        })
        pcall(vim.keymap.del, "n", "<C-t>", {
            buffer = bufnr
        })

        -- Remap <C-e> from expand-all to scroll down (matching <C-y> for scroll up)
        pcall(vim.keymap.del, "n", "<C-e>", { buffer = bufnr })
        vim.keymap.set("n", "<C-e>", function()
            local keys = vim.api.nvim_replace_termcodes("<C-e>", true, false, true)
            vim.api.nvim_feedkeys(keys, "n", false)
        end, opts("Scroll down"))
        vim.keymap.set("n", "E", api.tree.expand_all, opts("Expand All"))

        -- your custom split/tab mappings
        vim.keymap.set("n", "V", api.node.open.vertical, opts("Open: Vertical Split"))
        vim.keymap.set("n", "S", api.node.open.horizontal, opts("Open: Horizontal Split"))
        vim.keymap.set("n", "T", api.node.open.tab, opts("Open: New Tab"))

        -- Map + to change directory to the selected node
        vim.keymap.set("n", "+", function()
            local node = api.tree.get_node_under_cursor()
            if node and (node.type == "directory" or node.link_to) then
                local target = node.absolute_path
                -- If it's a symlink, resolve to the real path
                if node.link_to then
                    target = vim.fn.resolve(target)
                end
                vim.cmd("cd " .. vim.fn.fnameescape(target))
                -- Update nvim-tree root to match
                api.tree.change_root(target)
                print("Changed directory and tree root to: " .. target)
            else
                print("Not a directory or symlink node")
            end
        end, opts("Change directory and tree root to selected"))
    end,
    tab = {
        sync = {
            open = true, -- open tree in all tabs
            close = true -- close tree in all tabs when last tab closes
        }
    },
    update_focused_file = {
        enable = false, -- Disabled in favor of custom autocmd below
        update_root = false,
        ignore_list = {}
    },
    renderer = {
        root_folder_label = false,
    },
    view = {
        width = 35,
        preserve_window_proportions = true,
    },
    filters = {
        git_ignored = false,
        dotfiles = false,
        custom = {}
    },
    git = {
        enable = true,
        ignore = false
    }
})

-- =========================
-- Preserve NvimTree width
-- =========================

-- Track the last manually set width
local nvim_tree_width = 35

-- Set winfixwidth when the tree opens so :vs doesn't shrink it
vim.api.nvim_create_autocmd("FileType", {
    pattern = "NvimTree",
    callback = function()
        vim.wo.winfixwidth = true
        vim.wo.winbar = ""
    end,
})

-- Remember width when manually resized (e.g. via <leader>= / <leader>-)
vim.api.nvim_create_autocmd("WinResized", {
    callback = function()
        for _, winid in ipairs(vim.v.event.windows) do
            if vim.api.nvim_win_is_valid(winid) then
                local buf = vim.api.nvim_win_get_buf(winid)
                if vim.bo[buf].filetype == "NvimTree" then
                    nvim_tree_width = vim.api.nvim_win_get_width(winid)
                end
            end
        end
    end,
})

-- Restore width after splits or other layout changes
vim.api.nvim_create_autocmd("WinEnter", {
    callback = function()
        local api = require("nvim-tree.api")
        if not api.tree.is_visible() then
            return
        end
        vim.schedule(function()
            local tree_win = require("nvim-tree.view").get_winnr()
            if tree_win and vim.api.nvim_win_is_valid(tree_win) then
                local current = vim.api.nvim_win_get_width(tree_win)
                if current ~= nvim_tree_width then
                    vim.api.nvim_win_set_width(tree_win, nvim_tree_width)
                end
            end
        end)
    end,
})

-- =========================
-- Keymaps
-- =========================

-- Clear the active live filter
vim.keymap.set("n", "<leader>cf", function()
    require("nvim-tree.api").live_filter.clear()
end, {
    desc = "Clear NvimTree filter"
})

-- Toggle file tree
vim.keymap.set("n", "<leader>b", function()
    require("nvim-tree.api").tree.toggle({
        focus = false
    })
end, {
    noremap = true,
    silent = true,
    desc = "Toggle file tree"
})

-- Focus file tree
vim.keymap.set("n", "<leader>e", function()
    require("nvim-tree.api").tree.find_file({
        open = true,
        focus = true
    })
end, {
    noremap = true,
    silent = true,
    desc = "Focus file tree"
})

-- Clear all buffers
vim.api.nvim_create_user_command("Bda", "bufdo bw", {
    bang = true
})

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

        -- Skip if buffer itself is in node_modules
        if bufpath:match("/node_modules/") then
            return
        end

        -- Resolve symlinks to get real path
        local realpath = vim.fn.resolve(bufpath)

        -- Collapse node_modules in the tree before calling find_file, so it can't match files there
        local core = require("nvim-tree.core")
        local cwd = vim.fn.getcwd()
        local node_modules_path = cwd .. "/node_modules"

        local function collapse_node_modules(node)
            if node and node.absolute_path == node_modules_path and node.open then
                api.node.collapse(node)
                return
            end
            if node and node.nodes then
                for _, child in ipairs(node.nodes) do
                    collapse_node_modules(child)
                end
            end
        end

        local tree_root = core.get_explorer()
        if tree_root then
            collapse_node_modules(tree_root)
        end

        -- Now find the file
        api.tree.find_file({
            path = realpath,
            open = true,
            focus = false
        })
    end
})
