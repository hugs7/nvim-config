local M = {}

-- Helper: check if a string is PascalCase
local function is_pascal_case(str)
  return str:match("^[A-Z][A-Za-z0-9]*$") ~= nil
end

-- Helper: parse import statements from a file
local function parse_imports(lines)
  local imports = {}
  for _, line in ipairs(lines) do
    local from_path = line:match('import%s+.-%s+from%s+["\'](.-)["\']')
    local curly = line:match('import%s+{(.-)}%s+from')
    local default = line:match('import%s+([%w_]+)%s+from')
    if from_path then
      local names = {}
      if curly then
        for name in curly:gmatch('[%w_]+') do
          table.insert(names, vim.trim(name))
        end
      elseif default then
        table.insert(names, default)
      end
      table.insert(imports, {
        from = from_path,
        names = names
      })
    end
  end
  return imports
end

-- Helper: generate vi.mock for an import
local ignore_patterns = { "@/common/constants", "@/constants" }

local function should_ignore(import_from)
  for _, pat in ipairs(ignore_patterns) do
    if import_from:find(pat, 1, true) then
      return true
    end
  end
  return false
end

local function generate_vi_mock(import)
  if should_ignore(import.from) then
    return nil
  end
  local lines = {}
  table.insert(lines, 'vi.mock("' .. import.from .. '", () => ({')
  for _, name in ipairs(import.names) do
    if is_pascal_case(name) then
      table.insert(lines, '  ' .. name .. ': () => <div data-testid="' .. name:lower() .. '" />,')
    else
      table.insert(lines, '  ' .. name .. ': vi.fn(),')
    end
  end
  table.insert(lines, '}))')
  return table.concat(lines, "\n")
end

-- Main function: generate test file for current buffer
function M.generate_react_test()
  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)
  if not path:match("%.component%.tsx?$") then
    print("Not a React component file (.component.tsx)")
    return
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local imports = parse_imports(lines)

  -- Find component name and relative import
  local component_name = path:match("([^/]+)%.component%.tsx?$") or "Component"
  local test_file = path:gsub("%.component%.tsx?$", ".test.tsx")
  local rel_import = "./" .. component_name .. ".component"

  local test_lines = {}
  table.insert(test_lines, "import { fireEvent, render, screen } from '@testing-library/react';")
  table.insert(test_lines, "")
  table.insert(test_lines, "import { " .. component_name .. " } from '" .. rel_import .. "';")
  table.insert(test_lines, "")

  -- vi.mock blocks
  for _, imp in ipairs(imports) do
    local mock = generate_vi_mock(imp)
    if mock then
      table.insert(test_lines, mock)
      table.insert(test_lines, "")
    end
  end

  table.insert(test_lines, "describe('<" .. component_name .. " />', () => {")
  table.insert(test_lines, "  beforeEach(() => {")
  table.insert(test_lines, "    vi.clearAllMocks();")
  table.insert(test_lines, "  })\n")
  table.insert(test_lines, "  it('should first', () => {")
  table.insert(test_lines, "    // Write your test here.")
  table.insert(test_lines, "  })")
  table.insert(test_lines, "})")

  vim.fn.writefile(test_lines, test_file)
  vim.cmd("edit " .. test_file)
  print("Generated test file: " .. test_file)
end

return M
