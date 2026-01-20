local M = {}
local target_dir = require('hugo.utils.target-dir')

-- Use shared helper function to determine target directory
local get_target_directory = target_dir.get_target_directory

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
  local target_dir = M.get_target_directory()
  local dir = target_dir .. "/" .. name
  local component_file = dir .. "/" .. name .. ".component.tsx"
  local index_file = dir .. "/index.ts"
  local files = {}

  if with_types then
    local types_file = dir .. "/" .. name .. ".types.ts"
    local prop_type = name .. "Props"

    files[types_file] = {
      "export type " .. prop_type .. " = {",
      "  // Add your props here",
      "};"
    }

    files[component_file] = {
      'import { ' .. prop_type .. ' } from "./' .. name .. '.types";',
      "",
      "export const " .. name .. " = ({}: " .. prop_type .. ") => {",
      "  return (",
      "    <div>",
      "      " .. name,
      "    </div>",
      "  );",
      "};"
    }

    files[index_file] = {
      'export { ' .. name .. ' } from "./' .. name .. '.component";',
      'export type { ' .. prop_type .. ' } from "./' .. name .. '.types";'
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
  local target_dir = M.get_target_directory()
  local dir = target_dir .. "/" .. full_name
  local hook_file = dir .. "/" .. full_name .. ".hook." .. extension
  local index_file = dir .. "/index.ts"
  local files = {}

  if with_types then
    local types_file = dir .. "/" .. full_name .. ".types.ts"
    local pascal_name = full_name:gsub("^%l", string.upper)
    local props_type = pascal_name .. "Props"
    local return_type = pascal_name .. "Return"

    files[types_file] = {
      "export type " .. props_type .. " = {",
      "  // Add your options here",
      "};",
      "",
      "export type " .. return_type .. " = {",
      "  // Add your return type here",
      "};"
    }

    files[hook_file] = {
      'import { ' .. props_type .. ', ' .. return_type .. ' } from "./' .. full_name .. '.types";',
      "",
      "export const " .. full_name .. " = (options?: " .. props_type .. "): " .. return_type .. " => {",
      "  // Your hook logic here",
      "  ",
      "  return {};",
      "};"
    }

    files[index_file] = {
      'export { ' .. full_name .. ' } from "./' .. full_name .. '.hook";',
      'export type { ' .. props_type .. ', ' .. return_type .. ' } from "./' .. full_name .. '.types";'
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
      'export { ' .. full_name .. ' } from "./' .. full_name .. '.hook";'
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

-- Generate or update barrel export file (index.ts)
function M.generate_barrel_export()
  local target_dir = M.get_target_directory()
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
