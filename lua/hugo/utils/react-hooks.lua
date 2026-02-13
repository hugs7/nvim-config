local M = {}
local td = require("hugo.utils.target-dir")
local input = require("hugo.utils.input")
local f = require("hugo.utils.file")

-- Helper function to generate hook content
local function generate_hook_content(name, extension, with_types)
  local full_name = "use" .. name
  local target_dir = td.get_target_directory()
  local dir = target_dir .. "/" .. full_name
  local hook_file = dir .. "/" .. full_name .. ".hook." .. extension
  local index_file = dir .. "/index.ts"
  local files = {}

  if with_types then
    local types_file = dir .. "/" .. full_name .. ".types.ts"
    local pascal_name = full_name:gsub("^%l", string.upper)
    local props_type = pascal_name .. "Props"
    local return_type = pascal_name .. "Return"

    files[types_file] = { "export type " .. props_type .. " = {", "  // Add your options here", "};", "",
      "export type " .. return_type .. " = {", "  // Add your return type here", "};" }

    files[hook_file] =
    { 'import { ' .. props_type .. ', ' .. return_type .. ' } from "./' .. full_name .. '.types";', "",
      "export const " .. full_name .. " = ({}: " .. props_type .. "): " .. return_type .. " => {",
      "  // Your hook logic here", "  ", "  return {};", "};" }

    files[index_file] = { 'export { ' .. full_name .. ' } from "./' .. full_name .. '.hook";',
      'export type { ' .. props_type .. ', ' .. return_type .. ' } from "./' .. full_name ..
      '.types";' }
  else
    files[hook_file] = { "export const " .. full_name .. " = () => {", "  // Your hook logic here", "  ",
      "  return {};", "};" }

    files[index_file] = { 'export { ' .. full_name .. ' } from "./' .. full_name .. '.hook";' }
  end

  return dir, files, hook_file, full_name
end

-- Create basic hook
function M.create_hook()
  local name = vim.fn.input("Hook name (without 'use' prefix): ")
  if name == "" then
    return
  end

  local extension = input.get_extension()

  local dir, files, main_file, full_name = generate_hook_content(name, extension, false)
  f.create_files(dir, files, main_file, "Created hook: " .. full_name)
end

-- Create hook with types
function M.create_hook_with_types()
  local name = vim.fn.input("Hook name (without 'use' prefix): ")
  if name == "" then
    return
  end

  local extension = input.get_extension()

  local dir, files, main_file, full_name = generate_hook_content(name, extension, true)
  f.create_files(dir, files, main_file, "Created hook with types: " .. full_name)
end

return M
