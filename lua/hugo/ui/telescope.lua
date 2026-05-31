-- =========================
-- Telescope Setup
-- =========================
local holo = require("hugo.ui.holo_borders")
local previewers = require("telescope.previewers")

local hard_exclude_globs = {
  "!.git/**",
  "!**/.git/**",
  "!node_modules/**",
  "!**/node_modules/**",
  "!.next/**",
  "!**/.next/**",
  "!.nx/**",
  "!**/.nx/**",
  "!coverage/**",
  "!**/coverage/**",
  "!tmp/**",
  "!**/tmp/**",
}

local conditional_gitignored_dir_names = {
  build = true,
  dist = true,
  out = true,
}

local file_ignore_patterns = {
  "node_modules/",
  "%.git/",
  "%.next/",
  "%.nx/",
  "coverage/",
  "tmp/",
}

local function gitignored_output_dir_globs()
  if vim.fn.executable("git") ~= 1 then
    return {}
  end

  local ignored_dirs = vim.fn.systemlist({
    "git",
    "ls-files",
    "--others",
    "--ignored",
    "--exclude-standard",
    "--directory",
  })
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local globs = {}
  for _, dir in ipairs(ignored_dirs) do
    local normalized = dir:gsub("/+$", "")
    local name = normalized:match("([^/]+)$")
    if name and conditional_gitignored_dir_names[name] then
      globs[#globs + 1] = "!" .. normalized .. "/**"
    end
  end
  return globs
end

local function rg_hard_exclude_args()
  local args = {}
  for _, glob in ipairs(hard_exclude_globs) do
    args[#args + 1] = "--glob"
    args[#args + 1] = glob
  end
  for _, glob in ipairs(gitignored_output_dir_globs()) do
    args[#args + 1] = "--glob"
    args[#args + 1] = glob
  end
  return args
end

local function vimgrep_arguments(use_hard_excludes)
  local args = {
    "rg",
    "--color=never",
    "--no-heading",
    "--with-filename",
    "--line-number",
    "--column",
    "--smart-case",
    "--hidden",
    "--follow",
    "--no-ignore",
  }

  if use_hard_excludes then
    return vim.list_extend(args, rg_hard_exclude_args())
  end

  args[#args + 1] = "--glob"
  args[#args + 1] = "!.git/**"
  args[#args + 1] = "--glob"
  args[#args + 1] = "!**/.git/**"
  return args
end

local function find_files_command(use_hard_excludes)
  local command = { "rg", "--files", "--hidden", "--follow", "--no-ignore" }
  if use_hard_excludes then
    vim.list_extend(command, rg_hard_exclude_args())
  else
    command[#command + 1] = "--glob"
    command[#command + 1] = "!.git/**"
    command[#command + 1] = "--glob"
    command[#command + 1] = "!**/.git/**"
  end
  return command
end

local original_buffer_previewer_maker = previewers.buffer_previewer_maker
previewers.buffer_previewer_maker = function(filepath, bufnr, opts)
  local stat = vim.uv.fs_stat(filepath)
  if stat and stat.size > 1024 * 1024 then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "Preview disabled for files larger than 1MB.",
      "Open the file to view it.",
    })
    return
  end

  original_buffer_previewer_maker(filepath, bufnr, opts)
end

vim.api.nvim_set_hl(0, "TelescopeBorder", { fg = "#00e5ff", bg = "#0a0e14" })
vim.api.nvim_set_hl(0, "TelescopePromptBorder", { fg = "#00e5ff", bg = "#0a0e14" })
vim.api.nvim_set_hl(0, "TelescopeResultsBorder", { fg = "#005f7a", bg = "#0a0e14" })
vim.api.nvim_set_hl(0, "TelescopePreviewBorder", { fg = "#005f7a", bg = "#0a0e14" })
vim.api.nvim_set_hl(0, "TelescopeTitle", { fg = "#00e5ff", bg = "#0a0e14", bold = true })
vim.api.nvim_set_hl(0, "TelescopePromptTitle", { fg = "#00e5ff", bg = "#0a0e14", bold = true })
vim.api.nvim_set_hl(0, "TelescopeResultsTitle", { fg = "#00e5ff", bg = "#0a0e14", bold = true })
vim.api.nvim_set_hl(0, "TelescopePreviewTitle", { fg = "#00e5ff", bg = "#0a0e14", bold = true })
vim.api.nvim_set_hl(0, "TelescopeNormal", { bg = "#0a0e14" })
vim.api.nvim_set_hl(0, "TelescopePromptNormal", { bg = "#0a0e14" })
vim.api.nvim_set_hl(0, "TelescopeResultsNormal", { bg = "#0a0e14" })
vim.api.nvim_set_hl(0, "TelescopePreviewNormal", { bg = "#0a0e14" })

require('telescope').setup({
  defaults = {
    file_ignore_patterns = file_ignore_patterns,
    borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
    vimgrep_arguments = vimgrep_arguments(true),
  },
  pickers = {
    find_files = {
      hidden = true,
      no_ignore = true,
      no_ignore_parent = true,
      find_command = find_files_command(true),
    },
  },
})

-- =========================
-- Telescope keymaps
-- =========================
local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", function()
  builtin.find_files({
    hidden = true,
    no_ignore = true,
    no_ignore_parent = true,
    find_command = find_files_command(true),
  })
end, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", function()
  builtin.live_grep({
    vimgrep_arguments = vimgrep_arguments(true),
  })
end, { desc = "Live grep" })
vim.keymap.set("n", "<leader>fF", function()
  builtin.find_files({
    hidden = true,
    no_ignore = true,
    no_ignore_parent = true,
    find_command = find_files_command(false),
  })
end, { desc = "Find files without hard excludes" })
vim.keymap.set("n", "<leader>fG", function()
  builtin.live_grep({
    vimgrep_arguments = vimgrep_arguments(false),
  })
end, { desc = "Live grep without hard excludes" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
vim.keymap.set("n", "<leader>fh", builtin.help_tags, {})
vim.keymap.set("n", "<leader>fw", builtin.grep_string, { desc = "Find word under cursor" })

-- Search selected text in visual mode
vim.keymap.set("v", "<leader>fw", function()
  -- Exit visual mode and get the selected text
  vim.cmd('normal! "vy')
  local selected_text = vim.fn.getreg('v')

  if selected_text and selected_text ~= "" then
    builtin.grep_string({ search = selected_text })
  else
    print("No text selected")
  end
end, { desc = "Find selected text" })
