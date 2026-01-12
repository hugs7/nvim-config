local M = {}

-- Create basic component structure
function M.create_component()
  local component_name = vim.fn.input("Component name: ")
  if component_name == "" then return end
  
  local dir = component_name
  local component_file = dir .. "/" .. component_name .. ".component.tsx"
  local index_file = dir .. "/index.ts"
  
  -- Create directory
  vim.fn.mkdir(dir, "p")
  
  -- Component file content
  local component_content = {
    "export const " .. component_name .. " = () => {",
    "  return (",
    "    <div>",
    "      " .. component_name,
    "    </div>",
    "  );",
    "};"
  }
  
  -- Index file content
  local index_content = {
    'export { ' .. component_name .. ' } from "./' .. component_name .. '.component";'
  }
  
  -- Write files
  vim.fn.writefile(component_content, component_file)
  vim.fn.writefile(index_content, index_file)
  
  -- Open component file
  vim.cmd("edit " .. component_file)
  
  print("Created component: " .. component_name)
end

-- Create component with types
function M.create_component_with_types()
  local component_name = vim.fn.input("Component name: ")
  if component_name == "" then return end
  
  local dir = component_name
  local component_file = dir .. "/" .. component_name .. ".component.tsx"
  local types_file = dir .. "/" .. component_name .. ".types.ts"
  local index_file = dir .. "/index.ts"
  
  -- Create directory
  vim.fn.mkdir(dir, "p")
  
  -- Types file content
  local types_content = {
    "export type " .. component_name .. "Props = {",
    "  // Add your props here",
    "};"
  }
  
  -- Component file content
  local component_content = {
    'import { ' .. component_name .. 'Props } from "./' .. component_name .. '.types";',
    "",
    "export const " .. component_name .. " = (props: " .. component_name .. "Props) => {",
    "  return (",
    "    <div>",
    "      " .. component_name,
    "    </div>",
    "  );",
    "};"
  }
  
  -- Index file content
  local index_content = {
    'export { ' .. component_name .. ' } from "./' .. component_name .. '.component";',
    'export type { ' .. component_name .. 'Props } from "./' .. component_name .. '.types";'
  }
  
  -- Write files
  vim.fn.writefile(types_content, types_file)
  vim.fn.writefile(component_content, component_file)
  vim.fn.writefile(index_content, index_file)
  
  -- Open component file
  vim.cmd("edit " .. component_file)
  
  print("Created component with types: " .. component_name)
end

-- Create basic hook
function M.create_hook()
  local hook_name = vim.fn.input("Hook name (without 'use' prefix): ")
  if hook_name == "" then return end
  
  local extension = vim.fn.input("File extension (.ts/.tsx): ", "ts")
  if extension ~= "ts" and extension ~= "tsx" then
    print("Invalid extension. Using .ts")
    extension = "ts"
  end
  
  local full_hook_name = "use" .. hook_name
  local dir = full_hook_name
  local hook_file = dir .. "/" .. full_hook_name .. "." .. extension
  local index_file = dir .. "/index.ts"
  
  -- Create directory
  vim.fn.mkdir(dir, "p")
  
  -- Hook file content
  local hook_content = {
    "export const " .. full_hook_name .. " = () => {",
    "  // Your hook logic here",
    "  ",
    "  return {};",
    "};"
  }
  
  -- Index file content
  local index_content = {
    'export { ' .. full_hook_name .. ' } from "./' .. full_hook_name .. '";'
  }
  
  -- Write files
  vim.fn.writefile(hook_content, hook_file)
  vim.fn.writefile(index_content, index_file)
  
  -- Open hook file
  vim.cmd("edit " .. hook_file)
  
  print("Created hook: " .. full_hook_name)
end

-- Create hook with types
function M.create_hook_with_types()
  local hook_name = vim.fn.input("Hook name (without 'use' prefix): ")
  if hook_name == "" then return end
  
  local extension = vim.fn.input("File extension (.ts/.tsx): ", "ts")
  if extension ~= "ts" and extension ~= "tsx" then
    print("Invalid extension. Using .ts")
    extension = "ts"
  end
  
  local full_hook_name = "use" .. hook_name
  local dir = full_hook_name
  local hook_file = dir .. "/" .. full_hook_name .. "." .. extension
  local types_file = dir .. "/" .. full_hook_name .. ".types.ts"
  local index_file = dir .. "/index.ts"
  
  -- Create directory
  vim.fn.mkdir(dir, "p")
  
  -- Types file content
  local types_content = {
    "export type " .. full_hook_name .. "Options = {",
    "  // Add your options here",
    "};",
    "",
    "export type " .. full_hook_name .. "Return = {",
    "  // Add your return type here",
    "};"
  }
  
  -- Hook file content
  local hook_content = {
    'import { ' .. full_hook_name .. 'Options, ' .. full_hook_name .. 'Return } from "./' .. full_hook_name .. '.types";',
    "",
    "export const " .. full_hook_name .. " = (options?: " .. full_hook_name .. "Options): " .. full_hook_name .. "Return => {",
    "  // Your hook logic here",
    "  ",
    "  return {};",
    "};"
  }
  
  -- Index file content
  local index_content = {
    'export { ' .. full_hook_name .. ' } from "./' .. full_hook_name .. '";',
    'export type { ' .. full_hook_name .. 'Options, ' .. full_hook_name .. 'Return } from "./' .. full_hook_name .. '.types";'
  }
  
  -- Write files
  vim.fn.writefile(types_content, types_file)
  vim.fn.writefile(hook_content, hook_file)
  vim.fn.writefile(index_content, index_file)
  
  -- Open hook file
  vim.cmd("edit " .. hook_file)
  
  print("Created hook with types: " .. full_hook_name)
end

return M