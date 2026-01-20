local M = {}

-- Helper function to create files and directories
function M.create_files(dir, files, main_file, success_message)
  vim.fn.mkdir(dir, "p")

  for file_path, content in pairs(files) do
    vim.fn.writefile(content, file_path)
  end

  vim.cmd("edit " .. main_file)
  print(success_message)
end

return M
