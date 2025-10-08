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

local lazy_plugins = {
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
  {
    "windwp/nvim-ts-autotag",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {},
    config = function()
      require("nvim-treesitter.configs").setup({
        autotag = {
          enable = true
        }
      })
    end,
  },

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
    lazy = false,
    priority = 1000,
    config = function()
      require("vscode").setup({
        transparent = false,
        italic_comments = true,
        disable_nvimtree_bg = true,
        color_overrides = {
          vscLineNumber = "#3E4451",
          vscCursorLine = "#1f2233",
          vscDiffAdded = "#00e5ff",
          vscDiffChanged = "#00b3ff",
        },
        group_overrides = {
          CursorLine = { bg = "#0f111a" },
          NormalFloat = { bg = "#0f111a" },
          FloatBorder = { fg = "#00e5ff", bg = "#0f111a" },
          PmenuSel = { bg = "#00b3ff", fg = "#0f111a" },
        },
      })
      vim.cmd("colorscheme vscode")
    end,
  },

  {
    "folke/noice.nvim",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
    config = function()
      require("noice").setup({
        presets = { command_palette = true, long_message_to_split = true },
        views = {
          mini = { win_options = { winblend = 0 } },
          cmdline_popup = {
            border = { style = "rounded", text = { top = " COMMAND " } },
            position = { row = "40%", col = "50%" },
            size = { width = 60 },
          },
        },
      })
    end,
  },

  {
    "xiyaowong/nvim-transparent",
    config = function()
      require("transparent").setup({
        enable = true,
        extra_groups = { "NormalFloat", "NvimTreeNormal", "NormalNC" },
      })
    end,
  },

  require("hugo.plugins.format"),
  require("hugo.plugins.debug"),
}

vim.list_extend(lazy_plugins, require("hugo.plugins.essentials"))

require("lazy").setup(lazy_plugins)
