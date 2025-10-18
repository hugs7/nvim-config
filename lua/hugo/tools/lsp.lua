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
    on_attach = function(client, bufnr)
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
  tailwindcss = {
    settings = {
      tailwindCSS = {
        experimental = {
          classRegex = {
            -- optional: support for clsx, cva, cn, twMerge etc.
            "clsx\\(([^)]*)\\)",
            "cn\\(([^)]*)\\)",
            "cva\\(([^)]*)\\)",
            "twMerge\\(([^)]*)\\)",
          },
        },
      },
    },
  }
}

for name, opts in pairs(servers) do
  vim.lsp.config[name] = vim.tbl_extend("force", {
    capabilities = capabilities,
    on_attach = on_attach,
  }, opts)

  vim.lsp.enable(name) -- auto-start when filetype matches
end
