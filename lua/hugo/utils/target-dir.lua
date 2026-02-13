local M = {}

function M.get_nvim_tree_target_directory()
  local api = require('nvim-tree.api')
  local node = api.tree.get_node_under_cursor()
  if node then
    if node.type == 'directory' then
      return node.absolute_path
    else
      -- If it's a file, use its parent directory
      return vim.fn.fnamemodify(node.absolute_path, ':h')
    end
  end
  return nil
end

function M.get_sibling_path_of_current_file()
  local current_file = vim.fn.expand('%:p')
  if current_file ~= '' and vim.fn.filereadable(current_file) == 1 then
    local file_dir = vim.fn.expand('%:p:h')

    -- Check if current directory contains component or hook files
    local component_pattern = file_dir .. '/*.component.{ts,tsx}'
    local hook_pattern = file_dir .. '/*.hook.{ts,tsx}'

    local component_files = vim.fn.glob(component_pattern, 1, 1)
    local hook_files = vim.fn.glob(hook_pattern, 1, 1)

    -- If we find component/hook files in current dir, go up one level
    if #component_files > 0 or #hook_files > 0 then
      return vim.fn.expand('%:p:h:h') -- Go up one level
    else
      return vim.fn.expand('%:p:h')   -- Use current file's directory
    end
  else
    -- Fall back to current working directory
    return vim.fn.getcwd()
  end
end

-- Helper function to determine target directory
function M.get_target_directory()
  -- Check if we're in NvimTree
  if vim.bo.filetype == 'NvimTree' then
    return M.get_nvim_tree_target_directory()
  end

  return M.get_sibling_path_of_current_file()
end

return M
