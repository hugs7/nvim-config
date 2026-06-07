-- =========================
-- Telescope Setup
-- =========================
local actions = require("telescope.actions")
local previewers = require("telescope.previewers")

local function picker_history_key(picker)
  if not picker then
    return "global"
  end

  return picker.prompt_title or picker.results_title or "global"
end

local function read_picker_history(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or #lines == 0 then
    return {}
  end

  local decoded_ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if decoded_ok and type(decoded) == "table" then
    return decoded
  end

  return { global = lines }
end

local function write_picker_history(path, history)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile({ vim.json.encode(history) }, path)
end

local function repo_history_path()
  local cwd = vim.fn.getcwd()
  local git_root = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })[1]
  local root = vim.v.shell_error == 0 and git_root or cwd
  local name = vim.fn.fnamemodify(root, ":t")
  local hash = vim.fn.sha256(root)

  return vim.fn.stdpath("data") .. "/telescope_picker_history/" .. name .. "-" .. hash .. ".json"
end

local function get_picker_history()
  local config = require("telescope.config").values
  local path = repo_history_path()
  local limit = config.history.limit
  local cycle_wrap = config.history.cycle_wrap
  local content = read_picker_history(path)
  local indexes = {}

  local function entries_for(picker)
    local key = picker_history_key(picker)
    content[key] = content[key] or {}
    indexes[key] = indexes[key] or (#content[key] + 1)
    return key, content[key]
  end

  local function save()
    write_picker_history(path, content)
  end

  return {
    reset = function()
      for key, entries in pairs(content) do
        indexes[key] = #entries + 1
      end
    end,
    append = function(_, line, picker, no_reset)
      if line == "" then
        return
      end

      local key, entries = entries_for(picker)
      if entries[#entries] ~= line then
        entries[#entries + 1] = line

        if limit and #entries > limit then
          local extra = #entries - limit
          for _ = 1, extra do
            table.remove(entries, 1)
          end
        end

        save()
      end

      if not no_reset then
        indexes[key] = #entries + 1
      end
    end,
    get_next = function(_, _, picker)
      local key, entries = entries_for(picker)
      local next_index = indexes[key] + 1
      if next_index > #entries and cycle_wrap then
        next_index = 1
      end

      if next_index <= #entries then
        indexes[key] = next_index
        return entries[next_index]
      end

      indexes[key] = #entries + 1
      return nil
    end,
    get_prev = function(self, line, picker)
      local key, entries = entries_for(picker)
      local next_index = indexes[key] - 1
      if next_index < 1 and cycle_wrap then
        next_index = #entries
      end

      if indexes[key] == #entries + 1 and line ~= "" then
        self:append(line, picker, true)
      end

      if next_index >= 1 then
        indexes[key] = next_index
        return entries[next_index]
      end

      return nil
    end,
  }
end

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
    history = {
      path = repo_history_path(),
      limit = 200,
      cycle_wrap = true,
      handler = get_picker_history,
    },
    mappings = {
      i = {
        ["<C-Up>"] = actions.cycle_history_prev,
        ["<C-Down>"] = actions.cycle_history_next,
        ["<M-p>"] = actions.cycle_history_prev,
        ["<M-n>"] = actions.cycle_history_next,
      },
      n = {
        ["<C-Up>"] = actions.cycle_history_prev,
        ["<C-Down>"] = actions.cycle_history_next,
        ["<M-p>"] = actions.cycle_history_prev,
        ["<M-n>"] = actions.cycle_history_next,
      },
    },
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
