-- =========================
-- Big file optimisations
-- =========================
-- Disable expensive features for large or known-heavy files.

local bigfile_threshold = 512 * 1024 -- 512 KB

-- Files that are always treated as big regardless of size
local always_big_patterns = {
  "package%-lock%.json$",
  "yarn%.lock$",
  "pnpm%-lock%.yaml$",
  "%.min%.js$",
  "%.min%.css$",
  "%.bundle%.js$",
}

local function is_always_big(name)
  for _, pattern in ipairs(always_big_patterns) do
    if name:match(pattern) then return true end
  end
  return false
end

vim.api.nvim_create_autocmd("BufReadPre", {
  desc = "Disable heavy features for big files",
  callback = function(args)
    local name = vim.api.nvim_buf_get_name(args.buf)
    local forced = is_always_big(name)

    if not forced then
      local ok, stats = pcall(vim.uv.fs_stat, name)
      if not ok or not stats or stats.size < bigfile_threshold then
        return
      end
    end

    vim.b[args.buf].bigfile = true

    -- Disable treesitter highlighting
    vim.schedule(function()
      pcall(vim.treesitter.stop, args.buf)
    end)

    -- Disable LSP for this buffer
    vim.api.nvim_create_autocmd("LspAttach", {
      buffer = args.buf,
      callback = function(a)
        vim.schedule(function()
          pcall(vim.lsp.buf_detach_client, a.buf, a.data.client_id)
        end)
      end,
    })

    -- Disable indent-blankline
    vim.schedule(function()
      local ibl_ok, ibl = pcall(require, "ibl")
      if ibl_ok then
        pcall(ibl.setup_buffer, args.buf, { enabled = false })
      end
    end)

    -- Disable illuminate
    vim.schedule(function()
      local ill_ok, illuminate = pcall(require, "illuminate.engine")
      if ill_ok then
        pcall(illuminate.stop_buf, args.buf)
      end
    end)

    -- Disable gitsigns
    vim.schedule(function()
      local gs_ok, gitsigns = pcall(require, "gitsigns")
      if gs_ok then
        pcall(gitsigns.detach, args.buf)
      end
    end)

    -- Disable minimap / codewindow
    vim.schedule(function()
      local cw_ok, codewindow = pcall(require, "codewindow")
      if cw_ok then
        pcall(codewindow.close_minimap)
      end
    end)

    -- Disable dropbar
    vim.schedule(function()
      local db_ok, dropbar_api = pcall(require, "dropbar.api")
      if db_ok and dropbar_api then
        pcall(function() vim.b[args.buf].dropbar_disabled = true end)
      end
    end)

    -- Minimal buffer options for speed
    vim.api.nvim_create_autocmd("BufReadPost", {
      buffer = args.buf,
      once = true,
      callback = function()
        vim.bo[args.buf].syntax = ""
        vim.opt_local.foldmethod = "manual"
        vim.opt_local.spell = false
        vim.opt_local.swapfile = false
        vim.opt_local.undolevels = 100
        -- Disable matchparen (expensive on large buffers)
        pcall(vim.cmd, "NoMatchParen")
      end,
    })
  end,
})
