local M = {}
local api = vim.api
local floor, sqrt, abs, max, min = math.floor, math.sqrt, math.abs, math.max, math.min
local atan2, pi = math.atan2, math.pi

local H = 21
local W = 41
local CY = floor(H / 2)
local CX = floor(W / 2)
local R = CY - 1

local ns = api.nvim_create_namespace("radar")
local state = { buf = nil, win = nil, timer = nil, sweep = 0, active = false, aug = nil }

local function set_hl()
  local hl = api.nvim_set_hl
  hl(0, "RdrBorder",  { fg = "#00e5ff" })
  hl(0, "RdrCode",    { fg = "#2a5a3a" })
  hl(0, "RdrCursor",  { fg = "#ff4444", bold = true })
  hl(0, "RdrSweep1",  { fg = "#00ff88" })
  hl(0, "RdrSweep2",  { fg = "#00cc66" })
  hl(0, "RdrSweep3",  { fg = "#009944" })
  hl(0, "RdrCenter",  { fg = "#ffffff", bold = true })
  hl(0, "RdrCompass", { fg = "#00e5ff", bold = true })
  hl(0, "RdrBg",      { bg = "#0a150a" })
  hl(0, "RdrRing",    { fg = "#0d2d0d" })
end

local function dist(c, r)
  local dx, dy = (c - CX) / 2, r - CY
  return sqrt(dx * dx + dy * dy)
end

local function render()
  if not state.active or not state.buf or not api.nvim_buf_is_valid(state.buf) then return end

  local sw
  for _, w in ipairs(api.nvim_list_wins()) do
    if w ~= state.win and api.nvim_win_is_valid(w) then
      local b = api.nvim_win_get_buf(w)
      if vim.bo[b].buftype == "" and vim.bo[b].filetype ~= "NvimTree" then sw = w; break end
    end
  end
  if not sw then return end

  local sb = api.nvim_win_get_buf(sw)
  local lines = api.nvim_buf_get_lines(sb, 0, -1, false)
  local total = max(#lines, 1)
  local cur = api.nvim_win_get_cursor(sw)[1]

  local out, hls = {}, {}

  for row = 0, H - 1 do
    local ch, bo = {}, 0
    for col = 0, W - 1 do
      local d = dist(col, row)
      local c, g = " ", nil

      if row == 0 and col == CX then         c, g = "N", "RdrCompass"
      elseif row == H - 1 and col == CX then c, g = "S", "RdrCompass"
      elseif row == CY and col == 1 then     c, g = "W", "RdrCompass"
      elseif row == CY and col == W - 2 then c, g = "E", "RdrCompass"
      elseif d > R + 0.5 then
        -- outside
      elseif d > R - 0.5 then
        c, g = ".", "RdrBorder"
      elseif abs(d - R / 2) < 0.5 then
        c, g = ".", "RdrRing"
      elseif row == CY and col == CX then
        c, g = "+", "RdrCenter"
      else
        local a = atan2(row - CY, (col - CX) / 2)
        local sd = a - state.sweep
        while sd > pi do sd = sd - 2 * pi end
        while sd < -pi do sd = sd + 2 * pi end

        local si = min(max(floor((row / H) * total) + 1, 1), total)
        local dy = abs(row - CY)
        local hw = sqrt(max(0, (R - 1) ^ 2 - dy ^ 2)) * 2
        local t = hw > 0 and ((col - (CX - hw)) / (2 * hw)) or 0.5
        local sc = floor(t * 80) + 1
        local sl = lines[si] or ""
        local has = sc >= 1 and sc <= #sl and sl:sub(sc, sc):match("%S") ~= nil

        -- Map cursor line to radar row and highlight nearby rows
        local cur_radar_row = floor(((cur - 1) / total) * H)
        local near_cursor = abs(row - cur_radar_row) <= 1

        if near_cursor then
          c = has and "#" or "="
          g = "RdrCursor"
        elseif sd >= 0 and sd < 0.15 then
          c = has and "#" or ":"
          g = "RdrSweep1"
        elseif sd >= 0.15 and sd < 0.4 then
          c = has and ":" or "."
          g = "RdrSweep2"
        elseif sd >= 0.4 and sd < 0.8 then
          c = has and "." or " "
          g = "RdrSweep3"
        elseif has then
          c = "."
          g = "RdrCode"
        end
      end

      local n = #c
      if g then hls[#hls + 1] = { row, bo, bo + n, g } end
      bo = bo + n
      ch[#ch + 1] = c
    end
    out[#out + 1] = table.concat(ch)
  end

  vim.bo[state.buf].modifiable = true
  api.nvim_buf_set_lines(state.buf, 0, -1, false, out)
  vim.bo[state.buf].modifiable = false

  api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  for _, h in ipairs(hls) do
    pcall(api.nvim_buf_add_highlight, state.buf, ns, h[4], h[1], h[2], h[3])
  end
end

function M.close()
  state.active = false
  if state.timer then state.timer:stop(); state.timer:close(); state.timer = nil end
  if state.aug then pcall(api.nvim_del_augroup_by_id, state.aug); state.aug = nil end
  if state.win and api.nvim_win_is_valid(state.win) then api.nvim_win_close(state.win, true) end
  state.win, state.buf = nil, nil
end

function M.open()
  if state.active then return end
  set_hl()

  state.buf = api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"

  local ui = api.nvim_list_uis()[1]
  state.win = api.nvim_open_win(state.buf, false, {
    relative = "editor",
    row = ui.height - H - 4,
    col = ui.width - W - 3,
    width = W, height = H,
    style = "minimal",
    border = "rounded",
    focusable = false,
    zindex = 50,
  })
  vim.wo[state.win].winblend = 15
  vim.wo[state.win].winhighlight = "Normal:RdrBg,FloatBorder:RdrBorder"

  state.active = true
  render()

  state.timer = vim.loop.new_timer()
  state.timer:start(0, 80, vim.schedule_wrap(function()
    state.sweep = state.sweep + 0.1
    if state.sweep > pi then state.sweep = state.sweep - 2 * pi end
    render()
  end))

  state.aug = api.nvim_create_augroup("Radar", { clear = true })
  api.nvim_create_autocmd({ "CursorMoved", "TextChanged" }, {
    group = state.aug,
    callback = function() if state.active then render() end end,
  })
end

function M.toggle()
  if state.active then M.close() else M.open() end
end

return M
