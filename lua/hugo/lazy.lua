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
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate"
  },
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
    config = function()
      require("nvim-ts-autotag").setup({
        opts = {
          enable_close = true,
          enable_rename = true,
          enable_close_on_slash = false
        }
      })
    end,
  },

  -- Syntax
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "lua", "typescript", "javascript", "json", "tsx", "html", "css" },
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false
        },
      })
    end,
  },

  -- UI
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      require("bufferline").setup({
        options = {
          diagnostics = "nvim_lsp",
          offsets = {
            { filetype = "NvimTree", text = "NvimTree", highlight = "Directory", separator = true },
          },
          show_buffer_close_icons = true,
          show_close_icon = false,
          separator_style = "slant",
        },
      })
    end,
  },
  {
    "Bekaboo/dropbar.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("dropbar").setup({
        bar = {
          sources = function(buf, _)
            local sources = require("dropbar.sources")
            local utils = require("dropbar.utils")
            if vim.bo[buf].ft == "markdown" then
              return { sources.markdown }
            end
            if vim.bo[buf].buftype == "terminal" then
              return { sources.terminal }
            end
            return {
              sources.path,
              utils.source.fallback({
                sources.lsp,
                sources.treesitter,
              }),
            }
          end,
        },
      })
    end,
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = "BufReadPost",
    config = function()
      require("ibl").setup({
        indent = { char = "│" },
        scope = {
          enabled = true,
          show_start = true,
          show_end = false,
        },
        exclude = {
          filetypes = { "help", "dashboard", "NvimTree", "lazy" },
        },
      })
    end,
  },
  {
    "gorbit99/codewindow.nvim",
    event = "BufReadPost",
    config = function()
      local codewindow = require("codewindow")
      codewindow.setup({
        auto_enable = true,
        minimap_width = 10,
        width_multiplier = 4,
        window_border = "none",
        exclude_filetypes = { "help", "NvimTree", "lazy", "dashboard" },
      })
      vim.keymap.set("n", "<leader>mm", codewindow.toggle_minimap, { desc = "Toggle minimap" })
    end,
  },
  {
    "RRethy/vim-illuminate",
    event = "BufReadPost",
    config = function()
      require("illuminate").configure({
        delay = 200,
        filetypes_denylist = { "NvimTree", "lazy", "help", "dashboard" },
      })
    end,
  },
  {
    "NStefan002/screenkey.nvim",
    cmd = "Screenkey",
    keys = {
      { "<leader>sk", "<cmd>Screenkey<CR>", desc = "Toggle screenkey" },
    },
    config = function()
      require("screenkey").setup({
        win_opts = {
          border = "rounded",
        },
      })
    end,
  },
  "nvim-tree/nvim-tree.lua",
  "nvim-lualine/lualine.nvim",
  "nvim-telescope/telescope.nvim",
  "nvim-lua/plenary.nvim",
  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPost",
    opts = {
      -- Inline blame config
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 500,
        virt_text_pos = "eol",
        ignore_whitespace = true
      },
      current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> • <summary>",
    },
  },
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    keys = {
      { "<leader>td", "<cmd>DiffviewOpen<CR>",          desc = "Git diff view" },
      { "<leader>tf", "<cmd>DiffviewFileHistory %<CR>", desc = "File git history" },
      { "<leader>tl", "<cmd>DiffviewFileHistory<CR>",   desc = "Repo git log" },
      { "<leader>tq", "<cmd>DiffviewClose<CR>",         desc = "Close diff view" },
    },
    config = function()
      require("diffview").setup({
        enhanced_diff_hl = true,
      })
    end,
  },

  -- Markdown Preview
  {
    "iamcco/markdown-preview.nvim",
    ft = { "markdown" },
    build = ":call mkdp#util#install()",
    init = function()
      vim.g.mkdp_auto_start = 0
    end
  },

  -- Theme
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
    dependencies = { "MunifTanjim/nui.nvim" },
    config = function()
      -- Jarvis HUD highlight groups for noice
      vim.api.nvim_set_hl(0, "NoiceCmdlinePopupBorder", { fg = "#00e5ff", bg = "#0a0e14" })
      vim.api.nvim_set_hl(0, "NoiceCmdlinePopupTitle", { fg = "#00e5ff", bg = "#0a0e14", bold = true })
      vim.api.nvim_set_hl(0, "NoiceCmdlineIcon", { fg = "#00e5ff" })
      vim.api.nvim_set_hl(0, "NoiceConfirm", { bg = "#0a0e14" })
      vim.api.nvim_set_hl(0, "NoiceConfirmBorder", { fg = "#00e5ff", bg = "#0a0e14" })
      vim.api.nvim_set_hl(0, "NoiceMini", { fg = "#00e5ff", bg = "#0a0e14" })

      local holo = require("hugo.ui.holo_borders")
      local holo_border = holo.border()

      require("noice").setup({
        presets = {
          bottom_search = true,
          command_palette = true,
          long_message_to_split = true,
          inc_rename = true,
        },
        views = {
          cmdline_popup = {
            border = {
              style = holo_border,
              text = { top = " ▸ JARVIS COMMAND " },
            },
            position = { row = 1, col = "50%" },
            size = { width = 80, height = "auto" },
            win_options = {
              wrap = true,
              linebreak = true,
              winblend = 10,
              winhighlight = holo.winhighlight(),
            },
          },
          hover = {
            border = { style = holo_border },
            win_options = {
              winblend = 10,
              winhighlight = holo.winhighlight(),
            },
          },
          popup = {
            border = { style = holo_border },
            win_options = {
              winhighlight = holo.winhighlight(),
            },
          },
          mini = {
            win_options = {
              winblend = 15,
              winhighlight = "Normal:NoiceMini",
            },
          },
        },
        lsp = {
          progress = { enabled = false },
          hover = { enabled = true },
          signature = { enabled = true },
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
        },
        messages = {
          enabled = false,
        },
        notify = {
          enabled = false,
        },
        routes = {
          {
            filter = { event = "msg_show" },
            view = "cmdline",
          },
          {
            filter = { event = "notify" },
            opts = { skip = true },
          },
        },
      })
    end,
  },

  {
    "xiyaowong/nvim-transparent",
    config = function()
      require("transparent").setup({
        enable = false,
        extra_groups = { "NormalFloat", "NvimTreeNormal", "NormalNC" },
      })
    end,
  },

  require("hugo.plugins.format").config,
  require("hugo.plugins.debug"),
}

vim.list_extend(lazy_plugins, require("hugo.plugins.essentials"))

require("lazy").setup(lazy_plugins)
