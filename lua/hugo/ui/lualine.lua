require("lualine").setup({
  options = {
    theme = "auto", -- we'll override colors manually
    globalstatus = true,
    icons_enabled = true,
    component_separators = { left = "", right = "" },
    section_separators = { left = "", right = "" },
    disabled_filetypes = { "NvimTree", "dashboard" },
  },
  sections = {
    lualine_a = {
      {
        "mode",
        color = { fg = "#0f111a", bg = "#00e5ff", gui = "bold" },
        separator = { left = "", right = "" },
      },
    },
    lualine_b = {
      { "branch", icon = "", color = { fg = "#00e5ff" } },
    },
    lualine_c = {
      {
        "filename",
        path = 1,
        color = { fg = "#c5c8c6" },
      },
    },
    lualine_x = {
      { "encoding",   color = { fg = "#5c6370" } },
      { "fileformat", color = { fg = "#5c6370" } },
      { "filetype",   color = { fg = "#00e5ff" } },
    },
    lualine_y = {
      {
        "progress",
        color = { fg = "#0f111a", bg = "#00e5ff", gui = "bold" },
        separator = { left = "", right = "" },
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
