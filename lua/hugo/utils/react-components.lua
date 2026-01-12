local M = {}

-- Helper function to determine target directory
local function get_target_directory()
  local current_file = vim.fn.expand('%:p')
  
  -- Check if we're in NvimTree
  if vim.bo.filetype == 'NvimTree' then
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
  end
  
  if current_file ~= '' and vim.fn.filereadable(current_file) == 1 then
    local file_dir = vim.fn.expand('%:p:h')
    
    -- Check if current directory contains component or hook files
    local component_pattern = file_dir .. '/*.component.{ts,tsx}'
    local hook_pattern = file_dir .. '/*.hook.{ts,tsx}'
    
    local component_files = vim.fn.glob(component_pattern, 1, 1)
    local hook_files = vim.fn.glob(hook_pattern, 1, 1)
    
    -- If we find component/hook files in current dir, go up one level
    if #component_files > 0 or #hook_files > 0 then
      return vim.fn.expand('%:p:h:h')  -- Go up one level
    else
      return vim.fn.expand('%:p:h')    -- Use current file's directory
    end
  else
    -- Fall back to current working directory
    return vim.fn.getcwd()
  end
end

-- Helper function to get and validate file extension
local function get_extension()
  local extension = vim.fn.input("File extension (.ts/.tsx): ", "ts")
  if extension ~= "ts" and extension ~= "tsx" then
    print("Invalid extension. Using .ts")
    extension = "ts"
  end
  return extension
end

-- Helper function to create files and directories
local function create_files(dir, files, main_file, success_message)
  vim.fn.mkdir(dir, "p")

  for file_path, content in pairs(files) do
    vim.fn.writefile(content, file_path)
  end

  vim.cmd("edit " .. main_file)
  print(success_message)
end

-- Helper function to generate component content
local function generate_component_content(name, with_types)
  local target_dir = get_target_directory()
  local dir = target_dir .. "/" .. name
  local component_file = dir .. "/" .. name .. ".component.tsx"
  local index_file = dir .. "/index.ts"
  local files = {}

  if with_types then
    local types_file = dir .. "/" .. name .. ".types.ts"

    files[types_file] = {
      "export type " .. name .. "Props = {",
      "  // Add your props here",
      "};"
    }

    files[component_file] = {
      'import { ' .. name .. 'Props } from "./' .. name .. '.types";',
      "",
      "export const " .. name .. " = ({}: " .. name .. "Props) => {",
      "  return (",
      "    <div>",
      "      " .. name,
      "    </div>",
      "  );",
      "};"
    }

    files[index_file] = {
      'export { ' .. name .. ' } from "./' .. name .. '.component";',
      'export type { ' .. name .. 'Props } from "./' .. name .. '.types";'
    }
  else
    files[component_file] = {
      "export const " .. name .. " = () => {",
      "  return (",
      "    <div>",
      "      " .. name,
      "    </div>",
      "  );",
      "};"
    }

    files[index_file] = {
      'export { ' .. name .. ' } from "./' .. name .. '.component";'
    }
  end

  return dir, files, component_file
end

-- Helper function to generate hook content
local function generate_hook_content(name, extension, with_types)
  local full_name = "use" .. name
  local target_dir = get_target_directory()
  local dir = target_dir .. "/" .. full_name
  local hook_file = dir .. "/" .. full_name .. ".hook." .. extension
  local index_file = dir .. "/index.ts"
  local files = {}

  if with_types then
    local types_file = dir .. "/" .. full_name .. ".types.ts"

    files[types_file] = {
      "export type " .. full_name .. "Options = {",
      "  // Add your options here",
      "};",
      "",
      "export type " .. full_name .. "Return = {",
      "  // Add your return type here",
      "};"
    }

    files[hook_file] = {
      'import { ' .. full_name .. 'Options, ' .. full_name .. 'Return } from "./' .. full_name .. '.types";',
      "",
      "export const " .. full_name .. " = (options?: " .. full_name .. "Options): " .. full_name .. "Return => {",
      "  // Your hook logic here",
      "  ",
      "  return {};",
      "};"
    }

    files[index_file] = {
      'export { ' .. full_name .. ' } from "./' .. full_name .. '";',
      'export type { ' .. full_name .. 'Options, ' .. full_name .. 'Return } from "./' .. full_name .. '.types";'
    }
  else
    files[hook_file] = {
      "export const " .. full_name .. " = () => {",
      "  // Your hook logic here",
      "  ",
      "  return {};",
      "};"
    }

    files[index_file] = {
      'export { ' .. full_name .. ' } from "./' .. full_name .. '";'
    }
  end

  return dir, files, hook_file, full_name
end

-- Create basic component structure
function M.create_component()
  local name = vim.fn.input("Component name: ")
  if name == "" then return end

  local dir, files, main_file = generate_component_content(name, false)
  create_files(dir, files, main_file, "Created component: " .. name)
end

-- Create component with types
function M.create_component_with_types()
  local name = vim.fn.input("Component name: ")
  if name == "" then return end

  local dir, files, main_file = generate_component_content(name, true)
  create_files(dir, files, main_file, "Created component with types: " .. name)
end

-- Create basic hook
function M.create_hook()
  local name = vim.fn.input("Hook name (without 'use' prefix): ")
  if name == "" then return end

  local extension = get_extension()

  local dir, files, main_file, full_name = generate_hook_content(name, extension, false)
  create_files(dir, files, main_file, "Created hook: " .. full_name)
end

-- Create hook with types
function M.create_hook_with_types()
  local name = vim.fn.input("Hook name (without 'use' prefix): ")
  if name == "" then return end

  local extension = get_extension()

  local dir, files, main_file, full_name = generate_hook_content(name, extension, true)
  create_files(dir, files, main_file, "Created hook with types: " .. full_name)
end

return M

