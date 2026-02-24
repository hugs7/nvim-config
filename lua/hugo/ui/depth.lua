local M = {}
local api = vim.api
local fn = vim.fn
local floor, min, max = math.floor, math.min, math.max

local VISIBLE_LAYERS = 5 -- how many layers visible at once
local ANIM_FRAMES = 12
local ANIM_MS = 25

local state = {
  layers = {},     -- all loaded layers: { buf, lines, label, depth }
  windows = {},    -- currently visible windows: { win, layer_idx }
  active = false,
  timer = nil,
  focus = 0,       -- 0 = current, 1 = one commit back, etc.
  scroll_top = 1,  -- saved scroll position (topline)
  cursor_pos = { 1, 0 }, -- saved cursor position
  w = 0, h = 0,
  br = 1, bc = 2,
}

local function setup_hl()
  -- Matrix green: all layers get green tint, intensity varies by distance from focus
  for d = 0, 20 do
    local g = max(0x22, 0xff - d * 0x20)
    local bg_g = max(0x00, 0x0a - d * 0x02)
    api.nvim_set_hl(0, ("Depth%dN"):format(d), {
      fg = ("#00%02x%02x"):format(g, floor(g * 0.2)),
      bg = ("#00%02x00"):format(bg_g),
    })
    api.nvim_set_hl(0, ("Depth%dB"):format(d), {
      fg = ("#00%02x%02x"):format(g, floor(g * 0.2)),
    })
  end
  api.nvim_set_hl(0, "DepthFocusN", { fg = "#00ff66", bg = "#001a00" })
  api.nvim_set_hl(0, "DepthFocusB", { fg = "#00ff88" })
end

local function get_all_versions(filepath)
  local rel = fn.fnamemodify(filepath, ":.")
  local hashes = fn.systemlist("git log --format=%H -- " .. fn.shellescape(rel))
  if vim.v.shell_error ~= 0 then return {} end

  local versions = {}
  for i, hash in ipairs(hashes) do
    local info = fn.systemlist("git log --format=%h\\ %s -1 " .. hash)[1] or hash:sub(1, 7)
    if #info > 45 then info = info:sub(1, 45) .. "..." end
    -- Lazy-load content: only store hash, load lines on demand
    versions[#versions + 1] = { hash = hash, label = info, lines = nil }
  end
  return versions
end

local function load_layer_lines(version, filepath)
  if version.lines then return version.lines end
  local rel = fn.fnamemodify(filepath, ":.")
  local content = fn.systemlist("git show " .. version.hash .. ":" .. rel .. " 2>/dev/null")
  if vim.v.shell_error ~= 0 then content = { "(file did not exist at this commit)" } end
  version.lines = content
  return content
end

local function apply_skew(lines, depth, height)
  if depth == 0 then return lines end
  local out = {}
  local max_pad = min(depth * 2, 10)
  for i, line in ipairs(lines) do
    local t = 1 - ((i - 1) / max(height - 1, 1))
    out[i] = string.rep(" ", floor(t * max_pad)) .. line
  end
  return out
end

local function save_scroll()
  -- Save scroll position from the currently focused window
  for _, wl in ipairs(state.windows) do
    if wl.layer_idx == state.focus and wl.win and api.nvim_win_is_valid(wl.win) then
      state.scroll_top = fn.getwininfo(wl.win)[1].topline or 1
      local ok, pos = pcall(api.nvim_win_get_cursor, wl.win)
      if ok then state.cursor_pos = pos end
      break
    end
  end
end

local function close_windows()
  for _, wl in ipairs(state.windows) do
    if wl.win and api.nvim_win_is_valid(wl.win) then
      api.nvim_win_close(wl.win, true)
    end
  end
  state.windows = {}
end

local function rebuild_visible(animate)
  close_windows()

  local n_total = #state.layers
  if n_total == 0 then return end

  -- Determine which layers to show (centered around focus)
  local visible = {}
  local half = floor(VISIBLE_LAYERS / 2)
  local start_idx = max(0, state.focus - half)
  local end_idx = min(n_total - 1, start_idx + VISIBLE_LAYERS - 1)
  start_idx = max(0, end_idx - VISIBLE_LAYERS + 1)

  for i = start_idx, end_idx do
    visible[#visible + 1] = i
  end

  -- Create windows: furthest from focus at bottom, focused on top
  -- Sort so focused is last (highest zindex)
  table.sort(visible, function(a, b)
    return math.abs(a - state.focus) > math.abs(b - state.focus)
  end)

  for slot, layer_idx in ipairs(visible) do
    local layer = state.layers[layer_idx + 1] -- 1-indexed
    if not layer then goto continue end

    -- Load lines if needed
    local lines = load_layer_lines(layer, state.filepath)
    local skewed = apply_skew(lines, math.abs(layer_idx - state.focus), state.h)

    local buf = api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    api.nvim_buf_set_lines(buf, 0, -1, false, skewed)

    local dist = math.abs(layer_idx - state.focus)
    local is_focused = (layer_idx == state.focus)

    -- Position: focused at base, others offset by distance
    local offset_row = dist * 2
    local offset_col = dist * 3

    local blend = is_focused and 20 or min(30 + dist * 15, 80)

    local label = layer_idx == 0 and "HEAD (current)" or layer.label
    local title = (" %s [%d/%d] "):format(label, layer_idx + 1, n_total)

    -- When animating, all start at base position
    local initial_row = animate and state.br or (state.br + offset_row)
    local initial_col = animate and state.bc or (state.bc + offset_col)

    local win = api.nvim_open_win(buf, is_focused, {
      relative = "editor",
      row = initial_row,
      col = initial_col,
      width = state.w, height = state.h,
      style = "minimal",
      border = "rounded",
      focusable = is_focused,
      zindex = 20 + (VISIBLE_LAYERS - dist),
      title = title,
      title_pos = "center",
    })

    vim.wo[win].winblend = blend
    if is_focused then
      vim.wo[win].winhighlight = "Normal:DepthFocusN,FloatBorder:DepthFocusB"
      -- Set filetype for syntax highlighting on current version
      if layer_idx == 0 and state.cur_ft then
        vim.bo[buf].filetype = state.cur_ft
      end
    else
      local hl_d = min(dist, 20)
      vim.wo[win].winhighlight = ("Normal:Depth%dN,FloatBorder:Depth%dB"):format(hl_d, hl_d)
    end

    -- Restore scroll position on focused window
    if is_focused then
      vim.schedule(function()
        if not win or not api.nvim_win_is_valid(win) then return end
        local line_count = api.nvim_buf_line_count(buf)
        local cur_row = min(state.cursor_pos[1], line_count)
        local cur_col = min(state.cursor_pos[2], 0)
        pcall(api.nvim_win_set_cursor, win, { cur_row, cur_col })
        local top = min(state.scroll_top, line_count)
        pcall(api.nvim_win_call, win, function()
          fn.winrestview({ topline = top })
        end)
      end)
    end

    state.windows[#state.windows + 1] = {
      win = win, buf = buf, layer_idx = layer_idx,
      target_row = state.br + offset_row,
      target_col = state.bc + offset_col,
    }
    ::continue::
  end

  -- Fan-out animation on open
  if animate then
    if state.timer then state.timer:stop(); state.timer:close(); state.timer = nil end
    local frame = 0
    state.timer = vim.loop.new_timer()
    state.timer:start(30, ANIM_MS, vim.schedule_wrap(function()
      frame = frame + 1
      local t = min(frame / ANIM_FRAMES, 1)
      t = 1 - (1 - t) ^ 2 -- ease-out

      for _, wl in ipairs(state.windows) do
        if wl.win and api.nvim_win_is_valid(wl.win) then
          pcall(api.nvim_win_set_config, wl.win, {
            relative = "editor",
            row = state.br + (wl.target_row - state.br) * t,
            col = state.bc + (wl.target_col - state.bc) * t,
            width = state.w, height = state.h,
          })
        end
      end

      if frame >= ANIM_FRAMES then
        state.timer:stop()
        state.timer:close()
        state.timer = nil
      end
    end))
  end
end

function M.close()
  if state.timer then state.timer:stop(); state.timer:close(); state.timer = nil end
  close_windows()
  state.layers = {}
  state.active = false
  state.focus = 0
end

function M.open()
  if state.active then M.close() end

  local filepath = fn.expand("%:p")
  if filepath == "" then vim.notify("No file open", vim.log.levels.WARN); return end

  setup_hl()

  state.filepath = filepath
  state.cur_ft = vim.bo.filetype
  local cur_lines = api.nvim_buf_get_lines(0, 0, -1, false)

  -- Load all commit hashes (lines loaded lazily)
  local versions = get_all_versions(filepath)
  if #versions == 0 then vim.notify("No git history for this file", vim.log.levels.WARN); return end

  -- Layer 0 = current (HEAD), layer 1 = first commit, etc.
  state.layers = {}
  state.layers[1] = { hash = "HEAD", label = "HEAD (current)", lines = cur_lines }
  for i, v in ipairs(versions) do
    state.layers[i + 1] = v
  end

  local ui = api.nvim_list_uis()[1]
  state.w = floor(ui.width * 0.7)
  state.h = floor(ui.height * 0.7)
  state.br = 1
  state.bc = 2
  state.focus = 0
  state.scroll_top = 1
  state.cursor_pos = { 1, 0 }
  state.active = true

  rebuild_visible(true)
end

local function animate_slide(direction)
  -- Slide all windows briefly in the direction, then rebuild at final positions
  if state.timer then state.timer:stop(); state.timer:close(); state.timer = nil end

  -- direction: 1 = going deeper (slide up-left), -1 = going shallower (slide down-right)
  local slide_offset_row = direction * -2
  local slide_offset_col = direction * -3
  local frames = 6
  local frame = 0

  -- Capture current window positions
  local orig = {}
  for _, wl in ipairs(state.windows) do
    if wl.win and api.nvim_win_is_valid(wl.win) then
      local cfg = api.nvim_win_get_config(wl.win)
      orig[wl.win] = { row = cfg.row, col = cfg.col }
    end
  end

  state.timer = vim.loop.new_timer()
  state.timer:start(0, 20, vim.schedule_wrap(function()
    frame = frame + 1
    local t = min(frame / frames, 1)

    for _, wl in ipairs(state.windows) do
      local o = orig[wl.win]
      if o and wl.win and api.nvim_win_is_valid(wl.win) then
        pcall(api.nvim_win_set_config, wl.win, {
          relative = "editor",
          row = o.row + slide_offset_row * t,
          col = o.col + slide_offset_col * t,
          width = state.w, height = state.h,
        })
      end
    end

    if frame >= frames then
      state.timer:stop()
      state.timer:close()
      state.timer = nil
      rebuild_visible()
    end
  end))
end

function M.next_layer()
  if not state.active then return end
  local old = state.focus
  state.focus = min(state.focus + 1, #state.layers - 1)
  if state.focus ~= old then
    save_scroll()
    animate_slide(1)
  end
end

function M.prev_layer()
  if not state.active then return end
  local old = state.focus
  state.focus = max(state.focus - 1, 0)
  if state.focus ~= old then
    save_scroll()
    animate_slide(-1)
  end
end

function M.toggle()
  if state.active then M.close() else M.open() end
end

return M
