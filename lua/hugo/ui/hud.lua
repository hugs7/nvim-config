local M = {}
local api = vim.api
local uv = vim.uv or vim.loop
local floor = math.floor

local state = {
  buf = nil,
  win = nil,
  timer = nil,
  active = false,
  start_time = uv.hrtime(),
}

local ns = api.nvim_create_namespace("jarvis_hud")

local function setup_hl()
  api.nvim_set_hl(0, "HudBg", { bg = "#0a0e14" })
  api.nvim_set_hl(0, "HudBorder", { fg = "#00e5ff", bg = "#0a0e14" })
  api.nvim_set_hl(0, "HudLabel", { fg = "#005f7a" })
  api.nvim_set_hl(0, "HudValue", { fg = "#00e5ff" })
  api.nvim_set_hl(0, "HudOk", { fg = "#00ff88" })
  api.nvim_set_hl(0, "HudWarn", { fg = "#ff9e64" })
  api.nvim_set_hl(0, "HudErr", { fg = "#ff4444" })
  api.nvim_set_hl(0, "HudDim", { fg = "#1a3a4a" })
  api.nvim_set_hl(0, "HudTitle", { fg = "#00e5ff", bold = true })
end

local function format_uptime()
  local elapsed = (uv.hrtime() - state.start_time) / 1e9
  local h = floor(elapsed / 3600)
  local m = floor((elapsed % 3600) / 60)
  local s = floor(elapsed % 60)
  return string.format("%02d:%02d:%02d", h, m, s)
end

local function get_git_branch()
  local branch = vim.fn.systemlist("git branch --show-current 2>/dev/null")
  if vim.v.shell_error ~= 0 or #branch == 0 then return "N/A" end
  return branch[1]
end

local function get_lsp_status()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then return "OFFLINE", "HudDim" end
  local names = {}
  for _, c in ipairs(clients) do
    names[#names + 1] = c.name
  end
  return table.concat(names, ", "), "HudOk"
end

local function get_diagnostics_summary()
  local d = vim.diagnostic.get(nil)
  local e, w, i, h = 0, 0, 0, 0
  for _, diag in ipairs(d) do
    local s = diag.severity
    if s == 1 then
      e = e + 1
    elseif s == 2 then
      w = w + 1
    elseif s == 3 then
      i = i + 1
    else
      h = h + 1
    end
  end
  return e, w, i, h
end

local function get_buf_count()
  local count = 0
  for _, b in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted then
      count = count + 1
    end
  end
  return count
end

local W = 26

local function render()
  if not state.active or not state.buf or not api.nvim_buf_is_valid(state.buf) then return end

  local time = os.date("%H:%M:%S")
  local date = os.date("%Y-%m-%d")
  local uptime = format_uptime()
  local branch = get_git_branch():sub(1, 16)
  local lsp_name, lsp_hl = get_lsp_status()
  local errs, warns, infos, _ = get_diagnostics_summary()
  local bufs = get_buf_count()

  local lines = {
    " ▸ HUD",
    "",
    "  TIME     " .. time,
    "  DATE     " .. date,
    "  UPTIME   " .. uptime,
    "",
    "  BRANCH   " .. branch,
    "  BUFFERS  " .. bufs,
    "  LSP      " .. lsp_name:sub(1, 14),
    "",
    "  ERR " .. errs .. "  WRN " .. warns .. "  INF " .. infos,
  }

  vim.bo[state.buf].modifiable = true
  api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)

  -- Title
  api.nvim_buf_add_highlight(state.buf, ns, "HudTitle", 0, 0, -1)
  -- Values
  for _, row in ipairs({ 2, 3, 4, 6, 7 }) do
    api.nvim_buf_add_highlight(state.buf, ns, "HudValue", row, 0, -1)
  end
  api.nvim_buf_add_highlight(state.buf, ns, lsp_hl, 8, 0, -1)

  -- Diagnostics coloring
  if errs > 0 then
    api.nvim_buf_add_highlight(state.buf, ns, "HudErr", 10, 0, -1)
  elseif warns > 0 then
    api.nvim_buf_add_highlight(state.buf, ns, "HudWarn", 10, 0, -1)
  else
    api.nvim_buf_add_highlight(state.buf, ns, "HudOk", 10, 0, -1)
  end
end

function M.open()
  if state.active then return end
  setup_hl()

  state.buf = api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].buftype = "nofile"

  local ui = api.nvim_list_uis()[1]
  if not ui then return end

  local holo = require("hugo.ui.holo_borders")
  state.win = api.nvim_open_win(state.buf, false, {
    relative = "editor",
    row = 1,
    col = ui.width - W - 4,
    width = W,
    height = 11,
    style = "minimal",
    border = holo.border(),
    focusable = false,
    zindex = 45,
  })
  vim.wo[state.win].winblend = 20
  vim.wo[state.win].winhighlight = "Normal:HudBg,FloatBorder:HoloBorder1"

  state.active = true
  render()

  -- Update every second
  state.timer = uv.new_timer()
  state.timer:start(1000, 1000, vim.schedule_wrap(function()
    if not state.active then return end
    render()
  end))
end

function M.close()
  state.active = false
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_win_close(state.win, true)
  end
  state.win = nil
  state.buf = nil
end

function M.toggle()
  if state.active then M.close() else M.open() end
end

return M
