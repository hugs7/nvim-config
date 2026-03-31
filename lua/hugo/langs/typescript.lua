-- =========================
-- TypeScript Import Helpers
-- =========================
local M = {}

local function deferred_format(delay)
  vim.defer_fn(function()
    require("hugo.plugins.format").format_buffer()
  end, delay or 100)
end

local function is_react_import(line)
  return line:match('^import .+ from ["\']react["\']')
    or line:match('^import .+ from ["\']react/')
    or line:match("^import .+ from ['\"]react['\"]")
    or line:match("^import .+ from ['\"]react/")
end

local function is_alias_import(line)
  return line:match('^import .+ from ["\']@/') or line:match("^import .+ from ['\"]@/")
end

local function is_relative_import(line)
  return line:match('^import .+ from ["\']%.') or line:match("^import .+ from ['\"]%.")
end

local function is_import_line(line)
  return line:match("^import ")
end

local function sort_imports_custom(bufnr)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Parse imports into logical statements, handling multi-line imports
  local import_statements = {} -- each entry is a single-line version of the import
  local import_end = 0
  local in_import = false
  local current_parts = {}

  for i, line in ipairs(lines) do
    if in_import then
      table.insert(current_parts, vim.trim(line))
      if line:match("from%s+['\"]") or line:match("^}.*from%s+['\"]") then
        -- End of multi-line import
        local joined = table.concat(current_parts, " ")
        -- Normalize whitespace: collapse "{ foo ,  bar }" style
        joined = joined:gsub("%s+", " ")
        table.insert(import_statements, joined)
        current_parts = {}
        in_import = false
        import_end = i
      end
    elseif is_import_line(line) then
      -- Check if the import is complete on one line (has `from`)
      if line:match("from%s+['\"]") then
        table.insert(import_statements, line)
        import_end = i
      else
        -- Multi-line import starts here
        in_import = true
        current_parts = { line }
      end
    elseif line:match("^%s*$") and import_end > 0 then
      -- Allow blank lines within import block
    else
      if import_end > 0 then
        break
      end
    end
  end

  if #import_statements == 0 then
    return
  end

  -- Classify imports into groups
  local react_imports = {}
  local external_imports = {}
  local alias_imports = {}
  local relative_imports = {}

  for _, stmt in ipairs(import_statements) do
    if is_react_import(stmt) then
      table.insert(react_imports, stmt)
    elseif is_alias_import(stmt) then
      table.insert(alias_imports, stmt)
    elseif is_relative_import(stmt) then
      table.insert(relative_imports, stmt)
    else
      table.insert(external_imports, stmt)
    end
  end

  -- Sort named imports within {} alphabetically
  local function sort_named_imports(stmt)
    local before, names, after = stmt:match("^(import%s+{)(.+)(}%s+from.+)$")
    if not names then
      -- Try `import type {`
      before, names, after = stmt:match("^(import%s+type%s+{)(.+)(}%s+from.+)$")
    end
    if not names then
      return stmt
    end
    local name_list = {}
    for name in names:gmatch("[^,]+") do
      local trimmed = vim.trim(name)
      if trimmed ~= "" then
        table.insert(name_list, trimmed)
      end
    end
    table.sort(name_list)
    return before .. " " .. table.concat(name_list, ", ") .. " " .. after
  end

  for i, stmt in ipairs(import_statements) do
    import_statements[i] = sort_named_imports(stmt)
  end

  -- Sort by module path (the `from '...'` part), not by imported names
  local function get_module_path(stmt)
    return stmt:match("from%s+['\"]([^'\"]+)['\"]") or ""
  end

  local function sort_by_path(a, b)
    return get_module_path(a) < get_module_path(b)
  end

  table.sort(react_imports, sort_by_path)
  table.sort(external_imports, sort_by_path)
  table.sort(alias_imports, sort_by_path)

  -- Sort relative imports: more ../ first, then by path
  local function count_parent_dirs(stmt)
    local count = 0
    for _ in get_module_path(stmt):gmatch("%.%./") do
      count = count + 1
    end
    return count
  end

  table.sort(relative_imports, function(a, b)
    local da, db = count_parent_dirs(a), count_parent_dirs(b)
    if da ~= db then
      return da > db
    end
    return get_module_path(a) < get_module_path(b)
  end)

  -- Build new import block
  local new_lines = {}
  local function add_group(group)
    if #group > 0 then
      if #new_lines > 0 then
        table.insert(new_lines, "")
      end
      for _, l in ipairs(group) do
        table.insert(new_lines, l)
      end
    end
  end

  add_group(react_imports)
  add_group(external_imports)

  -- @/ alias and relative imports share one group, alias first
  local internal_imports = {}
  vim.list_extend(internal_imports, alias_imports)
  vim.list_extend(internal_imports, relative_imports)
  add_group(internal_imports)

  -- Append the rest of the file (skip old import block)
  local rest_start = import_end + 1
  while rest_start <= #lines and lines[rest_start]:match("^%s*$") do
    rest_start = rest_start + 1
  end

  if rest_start <= #lines then
    table.insert(new_lines, "")
  end

  for i = rest_start, #lines do
    table.insert(new_lines, lines[i])
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
end

local function organize_imports(bufnr)
  sort_imports_custom(bufnr)
  deferred_format()
end

local function remove_unused()
  vim.lsp.buf.code_action({
    apply = true,
    context = {
      only = { "source.removeUnused.ts" },
      diagnostics = {},
    },
  })
end

local function fix_imports_sequential()
  -- Remove unused imports first (async LSP action)
  remove_unused()

  -- Wait for LSP to apply the removal, then sort
  vim.defer_fn(function()
    sort_imports_custom()
    deferred_format(100)
  end, 500)
end

-- Export the function for use in keymaps
M.fix_imports_sequential = fix_imports_sequential

vim.api.nvim_create_user_command("SortImports", function()
  organize_imports()
end, { desc = "Sort/Organize TypeScript imports" })

vim.api.nvim_create_user_command("RemoveUnused", function()
  remove_unused()
end, { desc = "Remove unused TypeScript imports" })

vim.api.nvim_create_user_command("FixImports", function()
  fix_imports_sequential()
end, { desc = "Sort and remove unused imports" })

vim.api.nvim_create_user_command("FixImportsAll", function()
  local cwd = vim.fn.getcwd()
  local files = vim.fn.globpath(cwd, "**/*.ts", false, true)
  vim.list_extend(files, vim.fn.globpath(cwd, "**/*.tsx", false, true))

  -- Filter out node_modules/dist
  files = vim.tbl_filter(function(f)
    return not f:match("node_modules") and not f:match("/dist/") and not f:match("/build/")
  end, files)

  local count = 0
  for _, file in ipairs(files) do
    vim.cmd("edit " .. vim.fn.fnameescape(file))
    local bufnr = vim.api.nvim_get_current_buf()
    sort_imports_custom(bufnr)
    -- Only write if modified
    if vim.bo[bufnr].modified then
      vim.cmd("write")
      count = count + 1
    end
  end

  print("Fixed imports in " .. count .. " files")
end, { desc = "Fix imports in all ts/tsx files in the project" })

return M
