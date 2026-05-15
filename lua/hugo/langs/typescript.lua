-- =========================
-- TypeScript Import Helpers
-- =========================
local M = {}

local function deferred_format(delay)
  vim.defer_fn(function()
    require("hugo.plugins.format").format_buffer()
  end, delay or 100)
end

local function get_module_path(stmt)
  return stmt:match("from%s+['\"]([^'\"]+)['\"]") or ""
end

local function is_react_import(stmt)
  local path = get_module_path(stmt)
  return path == "react" or path:match("^react/") ~= nil
end

local function is_alias_import(stmt)
  return get_module_path(stmt):match("^@/") ~= nil
end

local function is_relative_import(stmt)
  return get_module_path(stmt):match("^%.") ~= nil
end

local function is_module_line(line)
  return line:match("^import%s")
    or line:match("^export%s+.+%s+from%s")
    or line:match("^export%s+[%*{]")
end

local function sort_imports_custom(bufnr)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Parse imports/exports into logical statements, handling multi-line statements
  local import_statements = {} -- each entry has a single-line version of the statement and attached comments
  local import_end = 0
  local prefix_lines = {}
  local pending_leading = {}
  local i = 1

  while i <= #lines do
    local line = lines[i]
    if line:match("^%s*$") or line:match("^%s*//") then
      table.insert(pending_leading, line)
      i = i + 1
    elseif is_module_line(line) then
      if import_end == 0 then
        prefix_lines = pending_leading
        pending_leading = {}
      end

      local leading = pending_leading
      pending_leading = {}
      local current_parts = { line }
      local statement_end = i

      local function is_statement_complete()
        local joined = table.concat(current_parts, " ")
        return joined:match("from%s+['\"]") or vim.trim(current_parts[1]):match("^import%s+['\"]")
      end

      while statement_end < #lines and not is_statement_complete() do
        statement_end = statement_end + 1
        table.insert(current_parts, vim.trim(lines[statement_end]))
      end

      if not is_statement_complete() then
        break
      end

      local joined = table.concat(current_parts, " ")
      -- Normalize whitespace: collapse "{ foo ,  bar }" style
      joined = joined:gsub("%s+", " ")
      table.insert(import_statements, { stmt = joined, leading = leading })
      import_end = statement_end
      i = statement_end + 1
    else
      break
    end
  end

  if #import_statements == 0 then
    return
  end

  -- Trim trailing slashes from import paths
  for i, entry in ipairs(import_statements) do
    import_statements[i].stmt = entry.stmt:gsub("(from%s+['\"])(.-)(['\"])", function(prefix, path, suffix)
      return prefix .. path:gsub("/+$", "") .. suffix
    end)
  end

  -- Merge imports that share the same module path
  local function get_path(stmt)
    return get_module_path(stmt)
  end

  local function extract_names(stmt)
    local names = stmt:match("^import%s+type%s+{(.-)}")
      or stmt:match("^import%s+{(.-)}")
    if not names then
      return nil, nil
    end
    local is_type = stmt:match("^import%s+type%s+{") ~= nil
    local list = {}
    for name in names:gmatch("[^,]+") do
      local trimmed = vim.trim(name)
      if trimmed ~= "" then
        table.insert(list, trimmed)
      end
    end
    return list, is_type
  end

  local merged = {}
  local path_index = {} -- path -> index in merged

  for _, entry in ipairs(import_statements) do
    local stmt = entry.stmt
    local path = get_path(stmt)
    local names, is_type = extract_names(stmt)
    local existing_idx = path_index[path]

    if names and existing_idx and #entry.leading == 0 then
      -- Merge into existing import with same path
      local existing = merged[existing_idx]
      local existing_names, existing_is_type = extract_names(existing.stmt)
      if existing_names and existing_is_type == is_type then
        -- Combine name lists, dedup
        local seen = {}
        for _, n in ipairs(existing_names) do
          seen[n] = true
        end
        for _, n in ipairs(names) do
          if not seen[n] then
            table.insert(existing_names, n)
            seen[n] = true
          end
        end
        -- Reconstruct the import
        local keyword = is_type and "import type" or "import"
        local quote = existing.stmt:match("from%s+(['\"])") or "'"
        merged[existing_idx].stmt = keyword
          .. " { "
          .. table.concat(existing_names, ", ")
          .. " } from "
          .. quote
          .. path
          .. quote
      else
        table.insert(merged, entry)
      end
    else
      table.insert(merged, entry)
      if names then
        path_index[path] = #merged
      end
    end
  end
  import_statements = merged

  -- Sort named imports within {} alphabetically
  local function sort_named_imports(stmt)
    local before, names, after = stmt:match("^(import%s+{)(.-)(}%s+from.+)$")
    if not names then
      -- Try `import type {`
      before, names, after = stmt:match("^(import%s+type%s+{)(.-)(}%s+from.+)$")
    end
    if not names then
      -- Try `export {` / `export type {`
      before, names, after = stmt:match("^(export%s+{)(.-)(}%s+from.+)$")
    end
    if not names then
      before, names, after = stmt:match("^(export%s+type%s+{)(.-)(}%s+from.+)$")
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

  for i, entry in ipairs(import_statements) do
    import_statements[i].stmt = sort_named_imports(entry.stmt)
  end

  -- Classify imports into groups
  local react_imports = {}
  local external_imports = {}
  local alias_imports = {}
  local relative_imports = {}

  for _, entry in ipairs(import_statements) do
    if is_react_import(entry.stmt) then
      table.insert(react_imports, entry)
    elseif is_alias_import(entry.stmt) then
      table.insert(alias_imports, entry)
    elseif is_relative_import(entry.stmt) then
      table.insert(relative_imports, entry)
    else
      table.insert(external_imports, entry)
    end
  end

  -- Sort by module path (the `from '...'` part), not by imported names
  local function sort_by_path(a, b)
    return get_module_path(a.stmt) < get_module_path(b.stmt)
  end

  table.sort(react_imports, sort_by_path)
  table.sort(external_imports, sort_by_path)
  table.sort(alias_imports, sort_by_path)

  -- Sort relative imports: more ../ first, then by path
  local function count_parent_dirs(entry)
    local count = 0
    for _ in get_module_path(entry.stmt):gmatch("%.%./") do
      count = count + 1
    end
    return count
  end

  table.sort(relative_imports, function(a, b)
    local da, db = count_parent_dirs(a), count_parent_dirs(b)
    if da ~= db then
      return da > db
    end
    return get_module_path(a.stmt) < get_module_path(b.stmt)
  end)

  -- Build new import/export block, preserving lines before imports (e.g. /// <reference>)
  local new_lines = {}
  for _, line in ipairs(prefix_lines) do
    table.insert(new_lines, line)
  end

  local function add_group(group)
    if #group > 0 then
      if #new_lines > 0 then
        table.insert(new_lines, "")
      end
      for _, entry in ipairs(group) do
        for _, l in ipairs(entry.leading) do
          if #new_lines > 0 or not l:match("^%s*$") then
            table.insert(new_lines, l)
          end
        end
        table.insert(new_lines, entry.stmt)
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

vim.api.nvim_create_user_command("SortImportsAll", function(opts)
  local path = opts.args ~= "" and opts.args or nil
  local cmd = path
    and string.format("git ls-files '%s/**/*.ts' '%s/**/*.tsx'", path, path)
    or "git ls-files '*.ts' '*.tsx'"
  local output = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    print("Not a git repository or git not available")
    return
  end

  local cwd = vim.fn.getcwd() .. "/"
  local count = 0
  local original_buf = vim.api.nvim_get_current_buf()

  for _, rel in ipairs(output) do
    local file = cwd .. rel
    if vim.fn.filereadable(file) == 1 then
      vim.cmd("edit " .. vim.fn.fnameescape(file))
      local bufnr = vim.api.nvim_get_current_buf()
      sort_imports_custom(bufnr)
      if vim.bo[bufnr].modified then
        vim.cmd("write")
        count = count + 1
      end
      if bufnr ~= original_buf then
        vim.api.nvim_buf_delete(bufnr, {})
      end
    end
  end

  vim.api.nvim_set_current_buf(original_buf)
  print("Sorted imports in " .. count .. " files")
end, { nargs = "?", complete = "dir", desc = "Sort imports in all git-tracked ts/tsx files" })

vim.api.nvim_create_user_command("FixImportsAll", function(opts)
  local path = opts.args ~= "" and opts.args or nil
  local cmd = path
    and string.format("git ls-files '%s/**/*.ts' '%s/**/*.tsx'", path, path)
    or "git ls-files '*.ts' '*.tsx'"
  local output = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    print("Not a git repository or git not available")
    return
  end

  local cwd = vim.fn.getcwd() .. "/"
  local files = {}
  for _, rel in ipairs(output) do
    local file = cwd .. rel
    if vim.fn.filereadable(file) == 1 then
      table.insert(files, file)
    end
  end

  local total = #files
  local count = 0
  local idx = 0
  local original_buf = vim.api.nvim_get_current_buf()

  local function process_next()
    idx = idx + 1
    if idx > total then
      vim.api.nvim_set_current_buf(original_buf)
      print("Fixed imports in " .. count .. "/" .. total .. " files")
      return
    end

    print(string.format("FixImportsAll: [%d/%d] %s", idx, total, files[idx]:sub(#cwd + 1)))
    vim.cmd("edit " .. vim.fn.fnameescape(files[idx]))
    local bufnr = vim.api.nvim_get_current_buf()

    -- Remove unused imports via LSP, then sort
    vim.lsp.buf.code_action({
      apply = true,
      context = {
        only = { "source.removeUnused.ts" },
        diagnostics = {},
      },
    })

    vim.defer_fn(function()
      sort_imports_custom(bufnr)
      if vim.bo[bufnr].modified then
        vim.cmd("write")
        count = count + 1
      end
      if bufnr ~= original_buf then
        vim.api.nvim_buf_delete(bufnr, {})
      end
      process_next()
    end, 500)
  end

  process_next()
end, { nargs = "?", complete = "dir", desc = "Fix imports in all git-tracked ts/tsx files" })

-- =========================
-- Tailwind Canonical Classes
-- =========================

local function fix_tailwind_canonical(bufnr)
  bufnr = bufnr or 0
  local diagnostics = vim.diagnostic.get(bufnr)
  local replacements = {}

  for _, d in ipairs(diagnostics) do
    local code = type(d.code) == "string" and d.code or (d.user_data and d.user_data.code) or ""
    if code == "suggestCanonicalClasses" then
      local original, replacement = d.message:match("`([^`]+)` can be written as `([^`]+)`")
      if original and replacement then
        -- Skip width arbitrary values (w-[...], min-w-[...], max-w-[...])
        if not original:match("w%-?%[") then
          replacements[original] = replacement
        end
      end
    end
  end

  if vim.tbl_isempty(replacements) then
    return 0
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local count = 0
  for i, line in ipairs(lines) do
    local new_line = line
    for original, replacement in pairs(replacements) do
      local escaped = original:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
      new_line = new_line:gsub(escaped, replacement)
    end
    if new_line ~= line then
      lines[i] = new_line
      count = count + 1
    end
  end

  if count > 0 then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end
  return count
end

vim.api.nvim_create_user_command("FixTailwindClasses", function()
  local count = fix_tailwind_canonical()
  print("Fixed tailwind classes on " .. count .. " lines")
end, { desc = "Replace arbitrary Tailwind values with canonical classes" })

vim.api.nvim_create_user_command("FixTailwindClassesAll", function(opts)
  local path = opts.args ~= "" and opts.args or nil
  local cmd = path
    and string.format("git ls-files '%s/**/*.tsx' '%s/**/*.ts'", path, path)
    or "git ls-files '*.tsx' '*.ts'"
  local output = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    print("Not a git repository or git not available")
    return
  end

  local cwd = vim.fn.getcwd() .. "/"
  local files = {}
  for _, rel in ipairs(output) do
    local file = cwd .. rel
    if vim.fn.filereadable(file) == 1 then
      table.insert(files, file)
    end
  end

  local total = #files
  local fixed = 0
  local idx = 0
  local original_buf = vim.api.nvim_get_current_buf()

  local function process_next()
    idx = idx + 1
    if idx > total then
      vim.api.nvim_set_current_buf(original_buf)
      print("FixTailwindClassesAll: fixed " .. fixed .. "/" .. total .. " files")
      return
    end

    print(string.format("FixTailwindClassesAll: [%d/%d] %s", idx, total, files[idx]:sub(#cwd + 1)))
    vim.cmd("edit " .. vim.fn.fnameescape(files[idx]))
    local bufnr = vim.api.nvim_get_current_buf()

    -- Wait for Tailwind LSP to produce diagnostics
    vim.defer_fn(function()
      local count = fix_tailwind_canonical(bufnr)
      if count > 0 and vim.bo[bufnr].modified then
        vim.cmd("write")
        fixed = fixed + 1
      end
      if bufnr ~= original_buf then
        vim.api.nvim_buf_delete(bufnr, {})
      end
      process_next()
    end, 1000)
  end

  process_next()
end, { nargs = "?", complete = "dir", desc = "Replace arbitrary Tailwind values with canonical classes in all files" })

return M
