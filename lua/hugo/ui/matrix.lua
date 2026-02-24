local M = {}
local api = vim.api
local uv = vim.uv or vim.loop
local floor, random = math.floor, math.random

local ns = api.nvim_create_namespace("matrix_rain")

local state = {
  active = false,
  buf = nil,
  win = nil,
  timer = nil,
  idle_timer = nil,
  tick = 0,
  columns = {},     -- per-column state
  idle_ms = 120000, -- 2 minutes idle before rain starts
}

-- Matrix character set (katakana-inspired + digits)
local chars = {
  "ア", "イ", "ウ", "エ", "オ", "カ", "キ", "ク", "ケ", "コ",
  "サ", "シ", "ス", "セ", "ソ", "タ", "チ", "ツ", "テ", "ト",
  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
  "A", "B", "C", "D", "E", "F",
  ":", ".", "<", ">", "=", "+", "-", "*", "/",
}

local trail_hls = {}

local function setup_hl()
  -- 12-step green trail from bright to black
  local greens = {
    "#00ff41", "#00e03a", "#00c233", "#00a32c",
    "#008525", "#00661e", "#004817", "#003310",
    "#002209", "#001505", "#000a02", "#000500",
  }
  for i, c in ipairs(greens) do
    api.nvim_set_hl(0, "Matrix" .. i, { fg = c, bg = "#000000" })
    trail_hls[i] = "Matrix" .. i
  end
  -- Head char is bright white-green
  api.nvim_set_hl(0, "MatrixHead", { fg = "#ffffff", bg = "#000000", bold = true })
  api.nvim_set_hl(0, "MatrixBg", { bg = "#000000" })
end

local function rand_char()
  return chars[random(1, #chars)]
end

local function init_columns(width, height)
  state.columns = {}
  for c = 1, width do
    state.columns[c] = {
      y = random(0, height * 2), -- start position (can be above screen)
      speed = random(1, 3),
      length = random(4, 12),
      chars = {},
    }
    -- Pre-fill chars
    for i = 1, state.columns[c].length do
      state.columns[c].chars[i] = rand_char()
    end
  end
end

local function render()
  if not state.active or not state.buf or not api.nvim_buf_is_valid(state.buf) then return end
  if not state.win or not api.nvim_win_is_valid(state.win) then return end

  local width = api.nvim_win_get_width(state.win)
  local height = api.nvim_win_get_height(state.win)

  -- Build empty lines
  local lines = {}
  for _ = 1, height do
    lines[#lines + 1] = string.rep(" ", width)
  end

  vim.bo[state.buf].modifiable = true
  api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)

  -- Render each column
  for c = 1, math.min(width, #state.columns) do
    local col = state.columns[c]
    col.y = col.y + col.speed
    local head = col.y

    -- Occasionally mutate a char
    if random(1, 10) == 1 then
      local idx = random(1, #col.chars)
      col.chars[idx] = rand_char()
    end

    for i = 0, col.length - 1 do
      local row = head - i
      if row >= 0 and row < height then
        local ch = col.chars[(i % #col.chars) + 1]
        local hl
        if i == 0 then
          hl = "MatrixHead"
        else
          local trail_idx = floor(i / col.length * #trail_hls) + 1
          hl = trail_hls[math.min(trail_idx, #trail_hls)]
        end

        pcall(api.nvim_buf_set_extmark, state.buf, ns, row, 0, {
          virt_text = { { ch, hl } },
          virt_text_win_col = c - 1,
        })
      end
    end

    -- Reset column when fully off screen
    if head - col.length > height then
      col.y = random(-10, -1)
      col.speed = random(1, 3)
      col.length = random(4, 12)
      for i = 1, col.length do
        col.chars[i] = rand_char()
      end
    end
  end
end

function M.show()
  if state.active then return end
  setup_hl()

  local ui = api.nvim_list_uis()[1]
  if not ui then return end

  state.buf = api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].buftype = "nofile"

  state.win = api.nvim_open_win(state.buf, false, {
    relative = "editor",
    row = 0,
    col = 0,
    width = ui.width,
    height = ui.height - 1,
    style = "minimal",
    border = "none",
    focusable = false,
    zindex = 1, -- behind everything
  })
  vim.wo[state.win].winblend = 30
  vim.wo[state.win].winhighlight = "Normal:MatrixBg"

  local width = ui.width
  local height = ui.height - 1
  init_columns(width, height)

  state.active = true
  state.tick = 0

  state.timer = uv.new_timer()
  state.timer:start(0, 60, vim.schedule_wrap(function()
    if not state.active then return end
    state.tick = state.tick + 1
    render()
  end))
end

function M.hide()
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
  if state.active then M.hide() else M.show() end
end

-- Auto-activate after idle period
function M.setup_idle(idle_ms)
  state.idle_ms = idle_ms or state.idle_ms

  local function reset_idle()
    if state.idle_timer then
      state.idle_timer:stop()
      state.idle_timer:close()
    end

    -- If rain is showing, dismiss it on any key
    if state.active then
      M.hide()
    end

    state.idle_timer = uv.new_timer()
    state.idle_timer:start(state.idle_ms, 0, vim.schedule_wrap(function()
      if not state.active then
        M.show()
      end
    end))
  end

  local aug = api.nvim_create_augroup("MatrixIdle", { clear = true })
  api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertEnter", "TextChanged", "FocusGained" }, {
    group = aug,
    callback = reset_idle,
  })

  -- Start the idle timer immediately
  reset_idle()
end

return M
