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
-- Grep settings
-- =========================
-- Use ripgrep for grep (respects .gitignore automatically)
if vim.fn.executable("rg") == 1 then
  vim.opt.grepprg = "rg --vimgrep --smart-case --follow --hidden --glob '!.git/' --respect-gitignore"
  vim.opt.grepformat = "%f:%l:%c:%m"
end

-- Configure wildignore to exclude common gitignored patterns for vimgrep
vim.opt.wildignore:append({
  "*/node_modules/*",
  "*/.git/*",
  "*/dist/*",
  "*/build/*",
  "*/.next/*",
  "*/.nx/*",
  "*/coverage/*",
  "*.log",
  "*.tmp",
  "*/tmp/*",
  "*/.cache/*",
  "*.min.js",
  "*.min.css"
})
