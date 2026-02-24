local M = {}
local api = vim.api
local fn = vim.fn
local floor, min, max = math.floor, math.min, math.max

local DEFAULT_DEPTHS = 3
local dim_cache = {}

local state = {
  active = false,
  orig_buf = nil,
  orig_win = nil,
  render_buf = nil,
  layers = {},
  focus = 0,
  filepath = nil,
  cur_ft = nil,
  ns = api.nvim_create_namespace("depth3d"),
  rain = false,
  rain_tick = 0,
  rain_timer = nil,
  visible_depths = DEFAULT_DEPTHS,
}

local function setup_hl()
  api.nvim_set_hl(0, "D3dHeader", { fg = "#00e5ff", italic = true })
  local n = state.visible_depths
  for d = 1, n do
    local v = max(0x10, floor(0x88 - (d - 1) * (0x88 - 0x10) / max(n - 1, 1)))
    api.nvim_set_hl(0, "D3d" .. d, { fg = ("#%02x%02x%02x"):format(v, v, v) })
  end
  dim_cache = {}
end

local function hl_for_depth(d)
  if d <= 0 then return nil end
  if d <= state.visible_depths then return "D3d" .. d end
  return nil
end

local function dim_hl(hl_name, depth)
  if not hl_name then return hl_for_depth(depth) end
  local key = hl_name .. "_" .. depth
  if dim_cache[key] then return dim_cache[key] end

  local ok, resolved = pcall(api.nvim_get_hl, 0, { name = hl_name, link = false })
  if not ok or not resolved or not resolved.fg then
    dim_cache[key] = hl_for_depth(depth)
    return dim_cache[key]
  end

  local fg = resolved.fg
  local r = floor(fg / 65536) % 256
  local g = floor(fg / 256) % 256
  local b = fg % 256

  local f = max(0.15, 0.75 - (depth - 1) * 0.032)

  r, g, b = floor(r * f), floor(g * f), floor(b * f)

  local name = ("D3dS_%d_%02x%02x%02x"):format(depth, r, g, b)
  api.nvim_set_hl(0, name, { fg = ("#%02x%02x%02x"):format(r, g, b) })
  dim_cache[key] = name
  return name
end

local function get_hl_map(buf, start_line, end_line)
  local map = {}

  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then return map end
  pcall(function() parser:parse() end)

  local lang = parser:lang()
  local qok, query = pcall(vim.treesitter.query.get, lang, "highlights")
  if not qok or not query then return map end

  local trees = parser:trees()
  if not trees or #trees == 0 then return map end

  for id, node in query:iter_captures(trees[1]:root(), buf, start_line, end_line + 1) do
    local sr, sc, er, ec = node:range()
    local name = "@" .. query.captures[id]
    for line = max(sr, start_line), min(er, end_line) do
      if not map[line] then map[line] = {} end
      local lsc = (line == sr) and sc or 0
      local lec = (line == er) and ec or 500
      for col = lsc, lec - 1 do
        map[line][col] = name
      end
    end
  end

  return map
end

local function ensure_hl_buf(layer, ft)
  if layer.hl_buf and api.nvim_buf_is_valid(layer.hl_buf) then
    return layer.hl_buf
  end
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].buftype = "nofile"
  api.nvim_buf_set_lines(buf, 0, -1, false, layer.lines)
  vim.bo[buf].filetype = ft
  layer.hl_buf = buf
  return buf
end

local function get_all_versions(filepath)
  local rel = fn.fnamemodify(filepath, ":.")
  local hashes = fn.systemlist("git log --format=%H -- " .. fn.shellescape(rel))
  if vim.v.shell_error ~= 0 then return {} end
  local versions = {}
  for _, hash in ipairs(hashes) do
    local info = fn.systemlist("git log --format=%h\\ %s -1 " .. hash)[1] or hash:sub(1, 7)
    if #info > 50 then info = info:sub(1, 50) .. "..." end
    versions[#versions + 1] = { hash = hash, label = info, lines = nil }
  end
  return versions
end

local function load_lines(layer, filepath)
  if layer.lines then return layer.lines end
  local rel = fn.fnamemodify(filepath, ":.")
  local content = fn.systemlist("git show " .. layer.hash .. ":" .. rel .. " 2>/dev/null")
  if vim.v.shell_error ~= 0 then content = {} end
  layer.lines = content
  return content
end

local function expand_tabs(s, ts)
  return s:gsub("\t", string.rep(" ", ts))
end

-- Perspective indent for back layers: more at top (receding), less at bottom
local function indent_at(y, h, d)
  local t = (h - 1 - y) / max(h - 1, 1)
  return floor(t * (2 + d * 1.5) + d * 3)
end

local function set_render_buf_keymaps(buf)
  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "]", function() M.next_layer() end, opts)
  vim.keymap.set("n", "[", function() M.prev_layer() end, opts)
  vim.keymap.set("n", "R", function() M.toggle_rain() end, opts)
  vim.keymap.set("n", "+", function() M.change_depths(1) end, opts)
  vim.keymap.set("n", "-", function() M.change_depths(-1) end, opts)
  vim.keymap.set("n", "Q", function() M.close() end, opts)
end

local function ensure_render_buf()
  if state.render_buf and api.nvim_buf_is_valid(state.render_buf) then
    return state.render_buf
  end
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = state.cur_ft
  set_render_buf_keymaps(buf)
  state.render_buf = buf
  return buf
end

local function cleanup_render_buf()
  if state.render_buf and api.nvim_buf_is_valid(state.render_buf) then
    api.nvim_buf_clear_namespace(state.render_buf, state.ns, 0, -1)
    api.nvim_buf_delete(state.render_buf, { force = true })
  end
  state.render_buf = nil
end

-- Get the buffer currently being displayed (orig_buf or render_buf)
local function display_buf()
  if state.focus == 0 then return state.orig_buf end
  return ensure_render_buf()
end

local function render()
  if not state.active then return end
  if not state.orig_win or not api.nvim_win_is_valid(state.orig_win) then return end
  if not state.orig_buf or not api.nvim_buf_is_valid(state.orig_buf) then return end

  local width = api.nvim_win_get_width(state.orig_win)
  local height = api.nvim_win_get_height(state.orig_win)
  local ts = vim.bo[state.orig_buf].tabstop or 2

  local dbuf = display_buf()

  -- When viewing a historical layer, populate the render buffer
  if state.focus > 0 then
    local focused = state.layers[state.focus + 1]
    if not focused then return end
    local focused_lines = load_lines(focused, state.filepath)
    vim.bo[dbuf].modifiable = true
    api.nvim_buf_set_lines(dbuf, 0, -1, false, focused_lines)
    vim.bo[dbuf].modifiable = false
    if api.nvim_win_get_buf(state.orig_win) ~= dbuf then
      api.nvim_win_set_buf(state.orig_win, dbuf)
    end
  else
    -- Ensure we're showing the original buffer
    if api.nvim_win_get_buf(state.orig_win) ~= state.orig_buf then
      api.nvim_win_set_buf(state.orig_win, state.orig_buf)
    end
    cleanup_render_buf()
  end

  -- Get visible range from the window's actual scroll position
  local win_top = api.nvim_win_call(state.orig_win, function()
    return fn.line("w0")
  end) - 1
  local buf_line_count = api.nvim_buf_line_count(dbuf)
  local visible_end = min(win_top + height, buf_line_count)
  local buf_lines = api.nvim_buf_get_lines(dbuf, win_top, visible_end, false)

  -- Expand tabs for collision detection against the focused layer
  local output = {}
  for i = 1, #buf_lines do
    output[i] = expand_tabs(buf_lines[i] or "", ts)
  end

  -- Clear previous overlay extmarks
  api.nvim_buf_clear_namespace(dbuf, state.ns, 0, -1)

  -- Overlay back layers with dimmed syntax highlighting + optional rain
  for depth = 1, state.visible_depths do
    local layer_idx = state.focus + depth + 1
    local layer = state.layers[layer_idx]
    if not layer then break end

    local fallback = hl_for_depth(depth)
    if not fallback then break end

    local back_lines = load_lines(layer, state.filepath)
    local total = #back_lines
    if total == 0 then goto continue_depth end

    if not layer.expanded then
      layer.expanded = {}
      for idx = 1, total do
        layer.expanded[idx] = expand_tabs(back_lines[idx], ts)
      end
    end
    local expanded = layer.expanded

    local hl_map = {}
    if depth <= 6 and state.cur_ft and state.cur_ft ~= "" then
      local hl_buf = ensure_hl_buf(layer, state.cur_ft)
      hl_map = get_hl_map(hl_buf, 0, total - 1)
    end

    for row = 0, #buf_lines - 1 do
      local buf_line_idx = win_top + row
      local back_indent = indent_at(row, height, depth)
      local output_line = output[row + 1] or ""
      local orig_idx = (buf_line_idx % total) + 1
      local orig_src = expanded[orig_idx]

      if state.rain then
        local max_src_col = width - back_indent
        if max_src_col <= 0 then goto continue_row end

        for i = 1, max_src_col do
          local orig_ch = orig_src and orig_src:sub(i, i) or ""
          if orig_ch == "" or orig_ch == " " then goto continue_col end

          local col_speed = 0.4 + ((i * 7 + depth * 3) % 11) / 11 * 1.2
          local rain_off = floor(state.rain_tick * col_speed)
          local src_idx = ((buf_line_idx - rain_off) % total + total) % total + 1

          local back_src = expanded[src_idx]
          local ch = back_src and back_src:sub(i, i) or ""
          if ch == "" or ch == " " then ch = orig_ch end

          local win_col = back_indent + i - 1
          if win_col >= 0 and win_col < width then
            local focused_ch = output_line:sub(win_col + 1, win_col + 1)
            if focused_ch == "" or focused_ch == " " then
              local ts_line = hl_map[src_idx - 1] or {}
              local ts_hl = ts_line[i - 1]
              local hl = ts_hl and dim_hl(ts_hl, depth) or fallback
              pcall(api.nvim_buf_set_extmark, dbuf, state.ns, buf_line_idx, 0, {
                virt_text = { { ch, hl } },
                virt_text_win_col = win_col,
              })
            end
          end
          ::continue_col::
        end
      else
        local back_src = orig_src
        local ts_line = hl_map[orig_idx - 1] or {}
        for i = 1, #(back_src or "") do
          local ch = back_src:sub(i, i)
          if ch ~= " " and ch ~= "" then
            local win_col = back_indent + i - 1
            if win_col >= 0 and win_col < width then
              local focused_ch = output_line:sub(win_col + 1, win_col + 1)
              if focused_ch == "" or focused_ch == " " then
                local ts_hl = ts_line[i - 1]
                local hl = ts_hl and dim_hl(ts_hl, depth) or fallback
                pcall(api.nvim_buf_set_extmark, dbuf, state.ns, buf_line_idx, 0, {
                  virt_text = { { ch, hl } },
                  virt_text_win_col = win_col,
                })
              end
            end
          end
        end
      end
      ::continue_row::
    end
    ::continue_depth::
  end
end

local function start_rain_timer()
  if state.rain_timer then
    state.rain_timer:stop(); state.rain_timer:close()
  end
  local uv = vim.uv or vim.loop
  state.rain_timer = uv.new_timer()
  state.rain_tick = 0
  state.rain_timer:start(150, 150, vim.schedule_wrap(function()
    if not state.active or not state.rain then return end
    state.rain_tick = state.rain_tick + 1
    render()
  end))
end

local function stop_rain_timer()
  if state.rain_timer then
    state.rain_timer:stop()
    state.rain_timer:close()
    state.rain_timer = nil
  end
end

local function cleanup_buf()
  if state.orig_buf and api.nvim_buf_is_valid(state.orig_buf) then
    api.nvim_buf_clear_namespace(state.orig_buf, state.ns, 0, -1)
    pcall(vim.keymap.del, "n", "]", { buffer = state.orig_buf })
    pcall(vim.keymap.del, "n", "[", { buffer = state.orig_buf })
    pcall(vim.keymap.del, "n", "R", { buffer = state.orig_buf })
    pcall(vim.keymap.del, "n", "+", { buffer = state.orig_buf })
    pcall(vim.keymap.del, "n", "-", { buffer = state.orig_buf })
    pcall(vim.keymap.del, "n", "Q", { buffer = state.orig_buf })
  end
  for _, layer in ipairs(state.layers) do
    if layer.hl_buf and api.nvim_buf_is_valid(layer.hl_buf) then
      api.nvim_buf_delete(layer.hl_buf, { force = true })
      layer.hl_buf = nil
    end
  end
end

function M.close()
  if not state.active then return end
  state.active = false
  state.rain = false
  stop_rain_timer()
  -- Restore original buffer in window before cleanup
  if state.orig_win and api.nvim_win_is_valid(state.orig_win)
      and state.orig_buf and api.nvim_buf_is_valid(state.orig_buf) then
    if api.nvim_win_get_buf(state.orig_win) ~= state.orig_buf then
      api.nvim_win_set_buf(state.orig_win, state.orig_buf)
    end
  end
  cleanup_render_buf()
  cleanup_buf()
  pcall(api.nvim_del_augroup_by_name, "depth3d")
end

local function init_buf()
  cleanup_buf()

  local filepath = fn.expand("%:p")
  if filepath == "" then return false end

  state.orig_buf = api.nvim_get_current_buf()
  state.orig_win = api.nvim_get_current_win()
  state.filepath = filepath
  state.cur_ft = vim.bo.filetype

  local cur_lines = api.nvim_buf_get_lines(0, 0, -1, false)
  local versions = get_all_versions(filepath)
  if #versions == 0 then return false end

  state.layers = {}
  state.layers[1] = { hash = "HEAD", label = "HEAD (current)", lines = cur_lines }
  for i, v in ipairs(versions) do
    state.layers[i + 1] = v
  end

  state.focus = 0
  state.rain_tick = 0

  -- Buffer-local keymaps
  local opts = { buffer = state.orig_buf, nowait = true, silent = true }
  vim.keymap.set("n", "]", function() M.next_layer() end, opts)
  vim.keymap.set("n", "[", function() M.prev_layer() end, opts)
  vim.keymap.set("n", "R", function() M.toggle_rain() end, opts)
  vim.keymap.set("n", "+", function() M.change_depths(1) end, opts)
  vim.keymap.set("n", "-", function() M.change_depths(-1) end, opts)
  vim.keymap.set("n", "Q", function() M.close() end, opts)

  return true
end

function M.open()
  if state.active then M.close() end

  setup_hl()

  if not init_buf() then
    vim.notify("No file or no git history", vim.log.levels.WARN)
    return
  end

  state.active = true
  render()

  -- Re-render on scroll and text changes
  local augroup = api.nvim_create_augroup("depth3d", { clear = true })
  api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "CursorMoved" }, {
    group = augroup,
    callback = function()
      if not state.active then return end
      local buf = api.nvim_get_current_buf()
      if buf == state.orig_buf or buf == state.render_buf then
        render()
      end
    end,
  })
  api.nvim_create_autocmd("WinScrolled", {
    group = augroup,
    callback = function()
      if state.active and api.nvim_get_current_win() == state.orig_win then
        render()
      end
    end,
  })
  api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function()
      if not state.active then return end
      local buf = api.nvim_get_current_buf()
      if buf == state.orig_buf or buf == state.render_buf then return end
      if vim.bo[buf].buftype ~= "" then return end
      -- Switching files: reset to editable mode
      cleanup_render_buf()
      state.focus = 0
      if not init_buf() then return end
      render()
    end,
  })
end

function M.next_layer()
  if not state.active then return end
  state.focus = min(state.focus + 1, #state.layers - 1)
  render()
end

function M.prev_layer()
  if not state.active then return end
  state.focus = max(state.focus - 1, 0)
  render()
end

function M.toggle_rain()
  if not state.active then return end
  state.rain = not state.rain
  if state.rain then
    state.visible_depths = 3
    setup_hl()
    start_rain_timer()
  else
    stop_rain_timer()
  end
  render()
  vim.notify("Rain " .. (state.rain and "ON" or "OFF") .. " | Depths: " .. state.visible_depths)
end

function M.change_depths(delta)
  if not state.active then return end
  state.visible_depths = max(1, min(state.visible_depths + delta, 20))
  setup_hl()
  render()
  vim.notify("Visible depths: " .. state.visible_depths)
end

function M.toggle()
  if state.active then M.close() else M.open() end
end

return M
