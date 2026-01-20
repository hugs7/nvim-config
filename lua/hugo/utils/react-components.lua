local M = {}
local td = require('hugo.utils.target-dir')
local f = require('hugo.utils.file')

local function get_component_files(component_name, with_types)
  local prop_type = component_name .. "Props"
  local types_lines = {"export type " .. prop_type .. " = {", "  // Add your props here", "};"}
  local component_lines
  local index_lines
  local export_component_def = 'export const ' .. component_name .. ' = ('
  local component_barrel_export = 'export { ' .. component_name .. ' } from "./' .. component_name .. '.component";'
  local arrow_part = ") => {"
  local return_lines = {"  return (", "    <div>", "      " .. component_name, "    </div>", "  );", "};"}
  local component_barrel_export = 'export { ' .. component_name .. ' } from "./' .. component_name .. '.component";'
  if with_types then
    local props = "{}: " .. prop_type
    component_lines = {'import { ' .. prop_type .. ' } from "./' .. component_name .. '.types";', "",
                       export_component_def .. props .. arrow_part, unpack(return_lines)}
    index_lines = {component_barrel_export,
                   'export type { ' .. prop_type .. ' } from "./' .. component_name .. '.types";'}
    return types_lines, component_lines, index_lines
  else
    component_lines = {export_component_def .. arrow_part, unpack(return_lines)}
    index_lines = {component_barrel_export}
    return nil, component_lines, index_lines
  end
end

local function generate_component_content(name, with_types)
  local target_dir = td.get_target_directory()
  local dir = target_dir .. "/" .. name
  local component_file = dir .. "/" .. name .. ".component.tsx"
  local types_file = dir .. "/" .. name .. ".types.ts"
  local index_file = dir .. "/index.ts"
  local files = {}
  local types_lines, component_lines, index_lines = get_component_files(name, with_types)
  if types_lines then
    files[types_file] = types_lines
  end
  files[component_file] = component_lines
  files[index_file] = index_lines
  return dir, files, component_file
end

-- Create basic component structure

function M.create_component()
  local name = vim.fn.input("Component name: ")
  if name == "" then
    return
  end
  local dir, files, main_file = generate_component_content(name, false)
  f.create_files(dir, files, main_file, "Created component: " .. name)
end

function M.create_component_with_types()
  local name = vim.fn.input("Component name: ")
  if name == "" then
    return
  end
  local dir, files, main_file = generate_component_content(name, true)
  f.create_files(dir, files, main_file, "Created component with types: " .. name)
end

-- Insert a React function component at the cursor
function M.insert_afc(with_types)
  local filename = vim.fn.expand('%:t')
  local name = filename:match('^(.-)%.') or filename
  if name == "" then
    return
  end
  local pascal_component_name = name:gsub("^%l", string.upper)
  local types_lines, component_lines = get_component_files(pascal_component_name, with_types)
  if types_lines then
    local target_dir = td.get_target_directory()
    local types_filename = target_dir .. "/" .. pascal_component_name .. ".types.ts"
    local uv = vim.loop or vim.uv
    local fd = uv.fs_open(types_filename, "r", 438)
    if not fd then
      vim.fn.writefile(types_lines, types_filename)
    else
      uv.fs_close(fd)
    end
  end
  for _, l in ipairs(component_lines) do
    vim.api.nvim_put({l}, 'l', true, true)
  end
end

function M.insert_afc_with_types()
  M.insert_afc(true)
end

return M
