-- Arc reactor animation frames
local arc_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local arc_idx = 1
local arc_timer = (vim.uv or vim.loop).new_timer()
arc_timer:start(100, 100, vim.schedule_wrap(function()
  arc_idx = (arc_idx % #arc_frames) + 1
end))

local function arc_reactor()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  local icon = arc_frames[arc_idx]
  if #clients == 0 then
    return icon .. " STANDBY"
  end
  -- Show spinning reactor with first LSP name
  return icon .. " " .. clients[1].name
end

-- Diagnostic count component
local function diag_summary()
  local e = #vim.diagnostic.get(nil, { severity = 1 })
  local w = #vim.diagnostic.get(nil, { severity = 2 })
  if e > 0 then
    return "▲ " .. e .. "E " .. w .. "W"
  elseif w > 0 then
    return "● " .. w .. "W"
  end
  return "◆ CLEAR"
end

local function diag_color()
  local e = #vim.diagnostic.get(nil, { severity = 1 })
  local w = #vim.diagnostic.get(nil, { severity = 2 })
  if e > 0 then return { fg = "#ff4444", gui = "bold" } end
  if w > 0 then return { fg = "#ff9e64" } end
  return { fg = "#00ff88" }
end

vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
  callback = function()
    vim.schedule(function() require("lualine").refresh() end)
  end,
})

require("lualine").setup({
  options = {
    theme = "auto",
    globalstatus = true,
    icons_enabled = true,
    component_separators = { left = "", right = "" },
    section_separators = { left = "", right = "" },
    disabled_filetypes = { "NvimTree", "dashboard" },
  },
  sections = {
    lualine_a = {
      {
        "mode",
        color = { fg = "#0f111a", bg = "#00e5ff", gui = "bold" },
        separator = { left = "", right = "" },
      },
    },
    lualine_b = {
      { "branch", icon = "", color = { fg = "#00e5ff" } },
      {
        diag_summary,
        color = diag_color,
      },
    },
    lualine_c = {
      {
        "filename",
        path = 1,
        color = { fg = "#c5c8c6" },
      },
    },
    lualine_x = {
      {
        function() return "recording @" .. vim.fn.reg_recording() end,
        cond = function() return vim.fn.reg_recording() ~= "" end,
        color = { fg = "#ff9e64", gui = "bold" },
      },
      {
        arc_reactor,
        color = { fg = "#00e5ff" },
      },
      { "encoding",   color = { fg = "#5c6370" } },
      { "fileformat", color = { fg = "#5c6370" } },
      { "filetype",   color = { fg = "#00e5ff" } },
    },
    lualine_y = {
      {
        "progress",
        color = { fg = "#0f111a", bg = "#00e5ff", gui = "bold" },
        separator = { left = "", right = "" },
      },
    },
    lualine_z = {
      {
        "location",
        color = { fg = "#0f111a", bg = "#00e5ff", gui = "bold" },
      },
    },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { { "filename", color = { fg = "#5c6370" } } },
    lualine_x = { { "location", color = { fg = "#5c6370" } } },
    lualine_y = {},
    lualine_z = {},
  },
})
