local M = {}
local td = require('hugo.utils.target-dir')
local f = require('hugo.utils.file')

-- Helper function to generate component content
local function generate_component_content(name, with_types)
  local target_dir = td.get_target_directory()
  local dir = target_dir .. "/" .. name
  local component_file = dir .. "/" .. name .. ".component.tsx"
  local index_file = dir .. "/index.ts"
  local files = {}

  if with_types then
    local types_file = dir .. "/" .. name .. ".types.ts"
    local prop_type = name .. "Props"

    files[types_file] = { "export type " .. prop_type .. " = {", "  // Add your props here", "};" }

    files[component_file] = { 'import { ' .. prop_type .. ' } from "./' .. name .. '.types";', "",
      "export const " .. name .. " = ({}: " .. prop_type .. ") => {", "  return (",
      "    <div>", "      " .. name, "    </div>", "  );", "};" }

    files[index_file] = { 'export { ' .. name .. ' } from "./' .. name .. '.component";',
      'export type { ' .. prop_type .. ' } from "./' .. name .. '.types";' }
  else
    files[component_file] = { "export const " .. name .. " = () => {", "  return (", "    <div>", "      " .. name,
      "    </div>", "  );", "};" }

    files[index_file] = { 'export { ' .. name .. ' } from "./' .. name .. '.component";' }
  end

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

-- Create component with types
function M.create_component_with_types()
  local name = vim.fn.input("Component name: ")
  if name == "" then
    return
  end

  local dir, files, main_file = generate_component_content(name, true)
  f.create_files(dir, files, main_file, "Created component with types: " .. name)
end

return M
