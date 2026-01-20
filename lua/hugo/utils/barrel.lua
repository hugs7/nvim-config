local M = {}
local td = require('hugo.utils.target-dir')

-- Generate or update barrel export file (index.ts)
function M.generate_barrel_export()
  local target_dir = td.get_target_directory()
  local index_file = target_dir .. "/index.ts"

  -- Get all files in the directory
  local files = vim.fn.readdir(target_dir, function(item)
    local full_path = target_dir .. "/" .. item
    -- Include only files (not directories) and exclude index.ts
    return vim.fn.isdirectory(full_path) == 0 and item ~= "index.ts"
  end)

  if #files == 0 then
    print("No files found in directory: " .. target_dir)
    return
  end

  -- Generate export statements
  local exports = {}
  for _, file in ipairs(files) do
    -- Match TypeScript/JavaScript files
    local name_without_ext = file:match("^(.+)%.[tj]sx?$")
    if name_without_ext then
      table.insert(exports, 'export * from "./' .. name_without_ext .. '";')
    end
  end

  if #exports == 0 then
    print("No TypeScript/JavaScript files found in: " .. target_dir)
    return
  end

  -- Sort exports alphabetically
  table.sort(exports)

  -- Write to index.ts
  vim.fn.writefile(exports, index_file)

  -- Open the file
  vim.cmd("edit " .. index_file)

  -- Sort imports using the organize imports command
  vim.defer_fn(function()
    vim.lsp.buf.code_action({
      context = { only = { "source.organizeImports" } },
      apply = true,
    })
  end, 100)

  print("Generated barrel export with " .. #exports .. " exports in: " .. vim.fn.fnamemodify(target_dir, ":~:."))
end

return M
