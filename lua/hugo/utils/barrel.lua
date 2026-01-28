local M = {}
local td = require('hugo.utils.target-dir')

local function get_export_files(target_dir)
  local files = {}
  for _, item in ipairs(vim.fn.readdir(target_dir)) do
    local full_path = target_dir .. "/" .. item
    if vim.fn.isdirectory(full_path) == 0 and item ~= "index.ts" then
      local name_without_ext = item:match("^(.+)%.[tj]sx?$")
      if name_without_ext then
        table.insert(files, name_without_ext)
      end
    end
  end
  return files
end

local function get_export_folders(target_dir)
  local folders = {}
  for _, item in ipairs(vim.fn.readdir(target_dir)) do
    local full_path = target_dir .. "/" .. item
    if vim.fn.isdirectory(full_path) == 1 then
      table.insert(folders, item)
    end
  end
  return folders
end

local function generate_exports(target_dir)
  local exports = {}
  for _, file in ipairs(get_export_files(target_dir)) do
    table.insert(exports, 'export * from \'./' .. file .. '\';')
  end
  for _, folder in ipairs(get_export_folders(target_dir)) do
    table.insert(exports, 'export * from \'./' .. folder .. '\';')
  end
  table.sort(exports)
  return exports
end

-- Generate or update barrel export file (index.ts)
function M.generate_barrel_export()
  local target_dir = td.get_target_directory()
  print("target_dir", target_dir)
  local index_file = target_dir .. "/index.ts"

  local exports = generate_exports(target_dir)
  if not exports or #exports == 0 then
    print("No exportable files or folders found in: " .. target_dir)
    return
  end

  -- Write to index.ts even if open, then reload buffer
  vim.fn.writefile(exports, index_file)
  local bufnr = vim.fn.bufnr(index_file, false)
  if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("edit!")
    end)
  else
    vim.cmd("edit " .. index_file)
  end

  -- Sort imports using the organize imports command
  vim.defer_fn(function()
    vim.lsp.buf.code_action({
      context = {
        only = { "source.organizeImports" }
      },
      apply = true
    })
  end, 100)

  print("Generated barrel export with " .. #exports .. " exports in: " .. vim.fn.fnamemodify(target_dir, ":~:."))
end

return M
