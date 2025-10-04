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
  update_focused_file = {
    enable = true,
    update_root = false,
    ignore_list = {},
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
  bufmap("n", "K", vim.lsp.buf.hover)
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
vim.keymap.set("n", "<leader>+", "<cmd>vertical resize +5<CR>", { desc = "Increase NvimTree width" })
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
