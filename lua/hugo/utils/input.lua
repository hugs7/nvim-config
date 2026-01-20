local M = {}

-- Helper function to get and validate file extension
function M.get_extension()
  local extension = vim.fn.input("File extension (.ts/.tsx): ", "ts")
  if extension ~= "ts" and extension ~= "tsx" then
    print("Invalid extension. Using .ts")
    extension = "ts"
  end
  return extension
end

return M
