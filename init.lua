-- =========================
-- Bootstrap lazy.nvim
-- =========================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- LSP + tooling
  { "williamboman/mason.nvim",         build = ":MasonUpdate" },
  "williamboman/mason-lspconfig.nvim",
  "neovim/nvim-lspconfig",

  -- Completion
  "hrsh7th/nvim-cmp",
  "hrsh7th/cmp-nvim-lsp",
  "hrsh7th/cmp-buffer",
  "hrsh7th/cmp-path",
  "hrsh7th/cmp-nvim-lsp-signature-help",
  "L3MON4D3/LuaSnip",
  "saadparwaiz1/cmp_luasnip",

  -- Syntax
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },

  -- UI
  "nvim-tree/nvim-tree.lua",
  "nvim-lualine/lualine.nvim",
  "nvim-telescope/telescope.nvim",
  "nvim-lua/plenary.nvim",
  "lewis6991/gitsigns.nvim",

  {
    "Mofiqul/vscode.nvim",
    config = function()
      require("vscode").setup({
        transparent = false, -- keep background solid
        italic_comments = true,
        disable_nvimtree_bg = true,
      })
      vim.cmd("colorscheme vscode")
    end,
  },

  -- Formatting
  {
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
  },

  -- Extra essentials
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("which-key").setup({})
    end,
  },

  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup()
    end,
  },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup({})
    end,
  },

  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("todo-comments").setup({})
    end,
  },

  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("trouble").setup({})
    end,
  },

  -- {
  --   "gcmt/cmdfix.nvim",
  --   config = function()
  --     require("cmdfix").setup({
  --       Bda = "bda",
  --       Format = "format",
  --       FixImports = "fiximports",
  --       SortImports = "sortimports",
  --       RemoveUnused = 'removeunused',
  --       Lazy = "Lazy",
  --     })
  --   end,
  -- },
})

-- =========================
-- General settings
-- =========================
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"

vim.g.mapleader = " "
vim.o.winbar = "%f"

-- Cursor shape per mode
vim.opt.guicursor = {
  "n-v-c:block", -- Normal/Visual/Command → block
  "i-ci:ver25",  -- Insert/Command-insert → vertical bar (25% height)
  "r-cr:hor20",  -- Replace modes → horizontal underline
  "o:hor50",     -- Operator-pending → half-height underline
}

-- Reset cursor shape when leaving Neovim
vim.api.nvim_create_autocmd("VimLeave", {
  callback = function()
    vim.opt.guicursor = ""
    io.write("\027[6 q")
    io.flush()
  end,
})

-- =========================
-- Plugin configs
-- =========================

-- Lualine
require("lualine").setup({
  options = { theme = "gruvbox" },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch" },
    lualine_c = { "filename" },
    lualine_x = { "encoding", "fileformat", "filetype" },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
})

-- Nvim-tree
require("nvim-tree").setup({
  on_attach = function(_, bufnr)
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

    -- (optional) quick help and go-up mappings
    -- vim.keymap.set("n", "?", api.tree.toggle_help, opts("Help"))
    -- vim.keymap.set("n", "-", api.tree.change_root_to_parent, opts("Up"))
  end,
  actions = {
    open_file = {
      resize_window = false
    }
  },
  update_focused_file = {
    enable = true,
    update_root = false,
    ignore_list = {},
  },
  view = {
    width = 50,
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

-- Treesitter
require("nvim-treesitter.configs").setup({
  ensure_installed = { "lua", "typescript", "javascript", "json", "tsx", "html", "css" },
  highlight = {
    enable = true, additional_vim_regex_highlighting = false
  },
})

-- Gitsigns
require("gitsigns").setup()

--- Mason + LSP setup
require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = { "ts_ls", "lua_ls", "jsonls", "html", "cssls" },
})

local capabilities = require("cmp_nvim_lsp").default_capabilities()

local function on_attach(_, bufnr)
  local bufmap = function(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true, buffer = bufnr })
  end
  bufmap("n", "gd", vim.lsp.buf.definition)
  bufmap("n", "K", function()
    vim.lsp.buf.hover()
    -- wait briefly for the hover float to spawn
    vim.defer_fn(function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local cfg = vim.api.nvim_win_get_config(win)
        if cfg and cfg.relative ~= "" then -- this is a floating window
          local buf = vim.api.nvim_win_get_buf(win)
          local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
          if ft == "markdown" then
            vim.api.nvim_set_current_win(win)
            -- optional: allow q to close the hover window
            vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, nowait = true, silent = true })
            break
          end
        end
      end
    end, 100)
  end)
  bufmap("n", "<leader>rn", vim.lsp.buf.rename)
  bufmap("n", "<leader>ca", vim.lsp.buf.code_action)
  bufmap("n", "gr", vim.lsp.buf.references)
  bufmap("n", "<leader>f", function() vim.lsp.buf.format { async = true } end)
end

-- Register servers using vim.lsp.config (new API)
local servers = {
  ts_ls = {
    on_attach = function(client, buffer)
      -- disable tsserver formatting so Conform/Prettier takes over
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false

      -- still apply your generic on_attach keymaps
      on_attach(client, bufnr)
    end,
  },
  lua_ls = {
    settings = { Lua = { diagnostics = { globals = { "vim" } } } },
  },
  jsonls = {},
  html = {},
  cssls = {},
}

for name, opts in pairs(servers) do
  vim.lsp.config[name] = vim.tbl_extend("force", {
    capabilities = capabilities,
    on_attach = on_attach,
  }, opts)

  vim.lsp.enable(name) -- auto-start when filetype matches
end

-- =========================
-- Autocomplete (nvim-cmp)
-- =========================
local cmp = require("cmp")
local luasnip = require("luasnip")

cmp.setup({
  snippet = {
    expand = function(args) luasnip.lsp_expand(args.body) end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { "i", "s" }),
  }),
  sources = {
    { name = "nvim_lsp" },
    { name = "nvim_lsp_signature_help" },
    { name = "buffer" },
    { name = "path" },
    { name = "luasnip" },
  },
})

-- =========================
-- Diagnostic
-- =========================
vim.diagnostic.config({
  virtual_text = true, -- show inline text
  signs = true,        -- show in sign column
  float = { border = "rounded" },
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

-- Clear the active live filter
vim.keymap.set("n", "<leader>cf", function()
  require("nvim-tree.api").live_filter.clear()
end, { desc = "Clear NvimTree filter" })

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

-- Focus editor
vim.keymap.set("n", "<leader>ee", "<C-w>l", { noremap = true, silent = true, desc = "Focus editor" })

-- Find file by name
vim.keymap.set("n", "<C-p>", ":Telescope find_files<CR>", { noremap = true, silent = true, desc = "Quick Open" })

-- Adjust Nvim Tree Width
vim.keymap.set("n", "<leader>=", "<cmd>vertical resize +5<CR>", { desc = "Increase NvimTree width" })
vim.keymap.set("n", "<leader>-", "<cmd>vertical resize -5<CR>", { desc = "Decrease NvimTree width" })

-- Format
vim.api.nvim_create_user_command("Format", function()
  require("conform").format({ async = true, lsp_fallbask = true })
end, { desc = "Format current buffer" })

vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show diagnostics under cursor" })

-- F12 → go to definition
vim.keymap.set("n", "<F12>", vim.lsp.buf.definition, { noremap = true, silent = true, desc = "Go to definition" })

-- Shift+F12 → references (like VSCode)
vim.keymap.set("n", "<S-F12>", vim.lsp.buf.references, { noremap = true, silent = true, desc = "Find references" })

-- Alt+F12 → hover (like peek)
vim.keymap.set("n", "<A-F12>", vim.lsp.buf.hover, { noremap = true, silent = true, desc = "Hover info" })

-- =========================
-- TypeScript Import Helpers
-- =========================
local function organize_imports(bufnr)
  vim.lsp.buf.execute_command({
    command = "_typescript.organizeImports",
    arguments = { vim.api.nvim_buf_get_name(bufnr or 0) },
  })
end

local function remove_unused(bufnr)
  vim.lsp.buf.code_action({
    apply = true,
    context = {
      only = { "source.removeUnused.ts" },
      diagnostics = {},
    },
  })
end

vim.api.nvim_create_user_command("SortImports", function()
  organize_imports(0)
end, { desc = "Sort/Organize TypeScript imports" })

vim.api.nvim_create_user_command("RemoveUnused", function()
  remove_unused(0)
end, { desc = "Remove unused TypeScript imports" })

vim.api.nvim_create_user_command("FixImports", function()
  remove_unused(0)
  organize_imports(0)
end, { desc = "Sort and remove unused imports" })

-- Clear all buffers
vim.api.nvim_create_user_command("Bda", "bufdo bw", { bang = true })
