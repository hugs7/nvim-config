local M = {}
local api = vim.api
local uv = vim.uv or vim.loop

-- Jarvis boot sequence lines with delays (ms)
local boot_lines = {
  { text = "", delay = 0 },
  { text = "  ╔══════════════════════════════════════════════════╗", delay = 0, hl = "JarvisBorder" },
  { text = "  ║                                                  ║", delay = 0, hl = "JarvisBorder" },
  { text = "  ║        ██╗ █████╗ ██████╗ ██╗   ██╗██╗███████╗   ║", delay = 60, hl = "JarvisTitle" },
  { text = "  ║        ██║██╔══██╗██╔══██╗██║   ██║██║██╔════╝   ║", delay = 60, hl = "JarvisTitle" },
  { text = "  ║        ██║███████║██████╔╝██║   ██║██║███████╗   ║", delay = 60, hl = "JarvisTitle" },
  { text = "  ║   ██   ██║██╔══██║██╔══██╗╚██╗ ██╔╝██║╚════██║   ║", delay = 60, hl = "JarvisTitle" },
  { text = "  ║   ╚█████╔╝██║  ██║██║  ██║ ╚████╔╝ ██║███████║   ║", delay = 60, hl = "JarvisTitle" },
  { text = "  ║    ╚════╝ ╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚══════╝   ║", delay = 60, hl = "JarvisTitle" },
  { text = "  ║                                                  ║", delay = 0, hl = "JarvisBorder" },
  { text = "  ║     Just A Rather Very Intelligent System        ║", delay = 200, hl = "JarvisSubtitle" },
  { text = "  ║                                                  ║", delay = 0, hl = "JarvisBorder" },
  { text = "  ╚══════════════════════════════════════════════════╝", delay = 0, hl = "JarvisBorder" },
  { text = "", delay = 100 },
  { text = "  ▸ Initializing core systems.............. ██████████", delay = 80, hl = "JarvisProgress" },
  { text = "  ▸ Loading neural interface............... ██████████", delay = 80, hl = "JarvisProgress" },
  { text = "  ▸ Treesitter parsers..................... ██████████", delay = 80, hl = "JarvisProgress" },
  { text = "  ▸ LSP engines online..................... ██████████", delay = 80, hl = "JarvisProgress" },
  { text = "  ▸ Diagnostics array...................... ██████████", delay = 80, hl = "JarvisProgress" },
  { text = "  ▸ Git telemetry.......................... ██████████", delay = 80, hl = "JarvisProgress" },
  { text = "  ▸ HUD overlay systems................... ██████████", delay = 80, hl = "JarvisProgress" },
  { text = "  ▸ Radar sweep calibrated................. ██████████", delay = 80, hl = "JarvisProgress" },
  { text = "", delay = 100 },
  { text = "  ┌──────────────────────────────────────────────────┐", delay = 0, hl = "JarvisDim" },
  { text = "  │  STATUS: ALL SYSTEMS OPERATIONAL                 │", delay = 200, hl = "JarvisOnline" },
  { text = "  └──────────────────────────────────────────────────┘", delay = 0, hl = "JarvisDim" },
  { text = "", delay = 0 },
  { text = "             Good evening, Hugo.", delay = 400, hl = "JarvisGreeting" },
  { text = "", delay = 0 },
}

local ns = api.nvim_create_namespace("jarvis_boot")

local function setup_hl()
  api.nvim_set_hl(0, "JarvisBorder", { fg = "#005f7a" })
  api.nvim_set_hl(0, "JarvisTitle", { fg = "#00e5ff", bold = true })
  api.nvim_set_hl(0, "JarvisSubtitle", { fg = "#00b3cc", italic = true })
  api.nvim_set_hl(0, "JarvisProgress", { fg = "#00e5ff" })
  api.nvim_set_hl(0, "JarvisDim", { fg = "#1a3a4a" })
  api.nvim_set_hl(0, "JarvisOnline", { fg = "#00ff88", bold = true })
  api.nvim_set_hl(0, "JarvisGreeting", { fg = "#00e5ff", italic = true })
  api.nvim_set_hl(0, "JarvisBg", { bg = "#0a0e14" })
  api.nvim_set_hl(0, "JarvisBootBorder", { fg = "#00e5ff", bg = "#0a0e14" })
end

function M.show()
  setup_hl()

  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"

  local ui = api.nvim_list_uis()[1]
  if not ui then return end

  local width = 56
  local height = #boot_lines
  local row = math.floor((ui.height - height) / 2)
  local col = math.floor((ui.width - width) / 2)

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "none",
    zindex = 100,
  })
  vim.wo[win].winhighlight = "Normal:JarvisBg"
  vim.wo[win].winblend = 0

  -- Fill buffer with empty lines first
  local empty = {}
  for _ = 1, height do
    empty[#empty + 1] = ""
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, empty)

  -- Animate lines appearing one by one
  local line_idx = 0
  local total_delay = 0

  for i, entry in ipairs(boot_lines) do
    total_delay = total_delay + entry.delay
    local delay = total_delay

    vim.defer_fn(function()
      if not api.nvim_buf_is_valid(buf) then return end
      vim.bo[buf].modifiable = true
      api.nvim_buf_set_lines(buf, i - 1, i, false, { entry.text })
      vim.bo[buf].modifiable = false

      if entry.hl then
        api.nvim_buf_add_highlight(buf, ns, entry.hl, i - 1, 0, -1)
      end
    end, delay)
  end

  -- Auto-close after animation + pause
  local close_delay = total_delay + 1200
  vim.defer_fn(function()
    if api.nvim_win_is_valid(win) then
      -- Fade out by clearing lines quickly
      for j = #boot_lines, 1, -1 do
        vim.defer_fn(function()
          if not api.nvim_buf_is_valid(buf) then return end
          vim.bo[buf].modifiable = true
          pcall(api.nvim_buf_set_lines, buf, j - 1, j, false, { "" })
          vim.bo[buf].modifiable = false
        end, (#boot_lines - j) * 15)
      end

      vim.defer_fn(function()
        if api.nvim_win_is_valid(win) then
          api.nvim_win_close(win, true)
        end
      end, #boot_lines * 15 + 100)
    end
  end, close_delay)

  -- Allow any key to dismiss early
  vim.keymap.set("n", "<CR>", function()
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
    pcall(vim.keymap.del, "n", "<CR>", { buffer = buf })
  end, { buffer = buf, nowait = true })

  vim.keymap.set("n", "<Esc>", function()
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
    pcall(vim.keymap.del, "n", "<Esc>", { buffer = buf })
  end, { buffer = buf, nowait = true })

  vim.keymap.set("n", "q", function()
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
    pcall(vim.keymap.del, "n", "q", { buffer = buf })
  end, { buffer = buf, nowait = true })
end

-- Auto-show on startup when no files are passed
function M.setup()
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      -- Only show when opening nvim with no files
      if vim.fn.argc() == 0 then
        -- Small delay so UI is ready
        vim.defer_fn(function()
          M.show()
        end, 50)
      end
    end,
    once = true,
  })
end

return M
