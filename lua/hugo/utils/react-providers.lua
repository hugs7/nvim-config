local M = {}
local td = require('hugo.utils.target-dir')
local f = require('hugo.utils.file')

-- Helper function to generate provider content
local function generate_provider_content(name)
    local target_dir = td.get_target_directory()
    local dir = target_dir .. "/" .. name
    local provider_file = dir .. "/" .. name .. ".tsx"
    local types_file = dir .. "/" .. name .. ".types.ts"
    local index_file = dir .. "/index.ts"
    local prop_type = name .. "Props"
    local files = {}

    files[types_file] = {'import { PropsWithChildren } from "react";', '',
                         'export type ' .. prop_type .. ' = PropsWithChildren<{', '  // Add your provider props here',
                         '}>;'}

    files[provider_file] = {'import type { ' .. prop_type .. ' } from "./' .. name .. '.types";', '',
                            'export const ' .. name .. ' = ({ children }: ' .. prop_type .. ') => {',
                            '  return children;', '};'}

    files[index_file] = {'export { ' .. name .. ' } from "./' .. name .. '";',
                         'export type { ' .. prop_type .. ' } from "./' .. name .. '.types";'}

    return dir, files, provider_file
end

-- Create provider structure
function M.create_provider()
    local name = vim.fn.input("Provider name: ")
    if name == "" then
        return
    end

    local dir, files, main_file = generate_provider_content(name)
    f.create_files(dir, files, main_file, "Created provider: " .. name)
end

return M

