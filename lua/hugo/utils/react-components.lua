local M = {}

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
  local dir = name
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
      "export const " .. name .. " = (props: " .. name .. "Props) => {",
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
  local dir = full_name
  local hook_file = dir .. "/" .. full_name .. "." .. extension
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
  
  local extension = vim.fn.input("File extension (.ts/.tsx): ", "ts")
  if extension ~= "ts" and extension ~= "tsx" then
    print("Invalid extension. Using .ts")
    extension = "ts"
  end
  
  local dir, files, main_file, full_name = generate_hook_content(name, extension, false)
  create_files(dir, files, main_file, "Created hook: " .. full_name)
end

-- Create hook with types
function M.create_hook_with_types()
  local name = vim.fn.input("Hook name (without 'use' prefix): ")
  if name == "" then return end
  
  local extension = vim.fn.input("File extension (.ts/.tsx): ", "ts")
  if extension ~= "ts" and extension ~= "tsx" then
    print("Invalid extension. Using .ts")
    extension = "ts"
  end
  
  local dir, files, main_file, full_name = generate_hook_content(name, extension, true)
  create_files(dir, files, main_file, "Created hook with types: " .. full_name)
end

return M