local M = {}
local api = vim.api
local fn = vim.fn
local floor, min, max = math.floor, math.min, math.max

local VISIBLE_DEPTHS = 20
local dim_cache = {}

local state = {
  active = false,
  orig_buf = nil,
  orig_win = nil,
  render_buf = nil,
  layers = {},
  focus = 0,
  scroll_top = 0,
  filepath = nil,
  cur_ft = nil,
  ns = api.nvim_create_namespace("depth3d"),
  rain_tick = 0,
  rain_timer = nil,
}

local function setup_hl()
  api.nvim_set_hl(0, "D3dHeader", { fg = "#00e5ff", italic = true })
  for d = 1, VISIBLE_DEPTHS do
    local v = max(0x10, floor(0x88 - (d - 1) * (0x88 - 0x10) / (VISIBLE_DEPTHS - 1)))
    api.nvim_set_hl(0, "D3d" .. d, { fg = ("#%02x%02x%02x"):format(v, v, v) })
  end
  dim_cache = {}
end

local function hl_for_depth(d)
  if d <= 0 then return nil end
  if d <= VISIBLE_DEPTHS then return "D3d" .. d end
  return nil
end

-- Dim a treesitter highlight's fg color by depth factor
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

-- Get treesitter highlights for a line range from a buffer
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

-- Create/cache a hidden buffer for treesitter parsing of a back layer
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

-- Expand tabs to spaces
local function expand_tabs(s, ts)
  return s:gsub("\t", string.rep(" ", ts))
end

-- Perspective indent: more at top (receding), less at bottom (closer)
local function indent_at(y, h, d)
  local t = (h - 1 - y) / max(h - 1, 1)
  return floor(t * (2 + d * 1.5) + d * 3)
end

local function render()
  if not state.active or not state.render_buf or not api.nvim_buf_is_valid(state.render_buf) then return end
  if not state.orig_win or not api.nvim_win_is_valid(state.orig_win) then return end

  local width = api.nvim_win_get_width(state.orig_win)
  local height = api.nvim_win_get_height(state.orig_win)
  local ts = vim.bo[state.orig_buf].tabstop or 2

  -- Build focused layer content with perspective indent
  local focused = state.layers[state.focus + 1]
  if not focused then return end
  local focused_lines = load_lines(focused, state.filepath)

  local output = {}
  for row = 0, height - 1 do
    local src_idx = row + state.scroll_top + 1
    local src = expand_tabs(focused_lines[src_idx] or "", ts)
    local indent = indent_at(row, height, 0)
    local line = string.rep(" ", indent) .. src
    -- Pad to exact width to prevent wrapping and allow overlays
    if #line < width then
      line = line .. string.rep(" ", width - #line)
    elseif #line > width then
      line = line:sub(1, width)
    end
    output[row + 1] = line
  end

  -- Set buffer content — treesitter highlights this via filetype
  vim.bo[state.render_buf].modifiable = true
  api.nvim_buf_set_lines(state.render_buf, 0, -1, false, output)
  vim.bo[state.render_buf].modifiable = false

  -- Clear previous overlay extmarks
  api.nvim_buf_clear_namespace(state.render_buf, state.ns, 0, -1)

  -- Overlay back layers with dimmed syntax highlighting + rain effect
  for depth = 1, VISIBLE_DEPTHS do
    local layer_idx = state.focus + depth + 1
    local layer = state.layers[layer_idx]
    if not layer then break end

    local fallback = hl_for_depth(depth)
    if not fallback then break end

    local back_lines = load_lines(layer, state.filepath)
    local total = #back_lines
    if total == 0 then goto continue_depth end

    -- Precompute expanded lines for this layer
    if not layer.expanded then
      layer.expanded = {}
      for idx = 1, total do
        layer.expanded[idx] = expand_tabs(back_lines[idx], ts)
      end
    end
    local expanded = layer.expanded

    -- Get syntax highlights across the full file for rain wrapping
    local hl_map = {}
    if depth <= 6 and state.cur_ft and state.cur_ft ~= "" then
      local hl_buf = ensure_hl_buf(layer, state.cur_ft)
      hl_map = get_hl_map(hl_buf, 0, total - 1)
    end

    for row = 0, height - 1 do
      local back_indent = indent_at(row, height, depth)
      local output_line = output[row + 1]
      local max_src_col = width - back_indent
      if max_src_col <= 0 then goto continue_row end

      for i = 1, max_src_col do
        -- Each column falls at a different speed based on column + depth
        local col_speed = 0.4 + ((i * 7 + depth * 3) % 11) / 11 * 1.2
        local rain_off = floor(state.rain_tick * col_speed)
        local src_idx = ((row + state.scroll_top - rain_off) % total + total) % total + 1

        local back_src = expanded[src_idx]
        local ch = back_src and back_src:sub(i, i) or ""
        if ch ~= "" and ch ~= " " then
          local col = back_indent + i - 1
          if col >= 0 and col < width then
            local focused_ch = output_line:sub(col + 1, col + 1)
            if focused_ch == " " then
              local ts_line = hl_map[src_idx - 1] or {}
              local ts_hl = ts_line[i - 1]
              local hl = ts_hl and dim_hl(ts_hl, depth) or fallback
              pcall(api.nvim_buf_set_extmark, state.render_buf, state.ns, row, col, {
                virt_text = { { ch, hl } },
                virt_text_pos = "overlay",
              })
            end
          end
        end
      end
      ::continue_row::
    end
    ::continue_depth::
  end

  -- Status in buffer name (shows in bufferline)
  local label = focused.label or "?"
  pcall(api.nvim_buf_set_name, state.render_buf,
    ("[3D] Layer " .. (state.focus + 1) .. "/" .. #state.layers .. " | " .. label))
end

function M.scroll(delta)
  if not state.active then return end
  local layer = state.layers[state.focus + 1]
  if not layer or not layer.lines then return end
  local max_scroll = max(0, #layer.lines - 10)
  state.scroll_top = max(0, min(state.scroll_top + delta, max_scroll))
  render()
end

function M.close()
  if not state.active then return end
  state.active = false
  if state.rain_timer then
    state.rain_timer:stop()
    state.rain_timer:close()
    state.rain_timer = nil
  end
  if state.orig_win and api.nvim_win_is_valid(state.orig_win) then
    if state.orig_buf and api.nvim_buf_is_valid(state.orig_buf) then
      api.nvim_win_set_buf(state.orig_win, state.orig_buf)
    end
  end
  if state.render_buf and api.nvim_buf_is_valid(state.render_buf) then
    api.nvim_buf_delete(state.render_buf, { force = true })
  end
  -- Clean up hidden treesitter buffers
  for _, layer in ipairs(state.layers) do
    if layer.hl_buf and api.nvim_buf_is_valid(layer.hl_buf) then
      api.nvim_buf_delete(layer.hl_buf, { force = true })
      layer.hl_buf = nil
    end
  end
  state.render_buf = nil
end

function M.open()
  if state.active then M.close() end

  local filepath = fn.expand("%:p")
  if filepath == "" then vim.notify("No file open", vim.log.levels.WARN); return end

  setup_hl()

  state.orig_buf = api.nvim_get_current_buf()
  state.orig_win = api.nvim_get_current_win()
  state.filepath = filepath
  state.cur_ft = vim.bo.filetype

  local cur_lines = api.nvim_buf_get_lines(0, 0, -1, false)
  local versions = get_all_versions(filepath)
  if #versions == 0 then vim.notify("No git history", vim.log.levels.WARN); return end

  state.layers = {}
  state.layers[1] = { hash = "HEAD", label = "HEAD (current)", lines = cur_lines }
  for i, v in ipairs(versions) do
    state.layers[i + 1] = v
  end

  state.render_buf = api.nvim_create_buf(false, true)
  vim.bo[state.render_buf].bufhidden = "wipe"
  vim.bo[state.render_buf].buftype = "nofile"
  vim.bo[state.render_buf].swapfile = false
  vim.bo[state.render_buf].filetype = state.cur_ft

  api.nvim_win_set_buf(state.orig_win, state.render_buf)
  vim.wo[state.orig_win].wrap = false

  state.focus = 0
  state.scroll_top = 0
  state.rain_tick = 0
  state.active = true

  render()

  -- Start rain timer for back-layer animation
  if state.rain_timer then state.rain_timer:stop(); state.rain_timer:close() end
  local uv = vim.uv or vim.loop
  state.rain_timer = uv.new_timer()
  state.rain_timer:start(150, 150, vim.schedule_wrap(function()
    if not state.active then return end
    state.rain_tick = state.rain_tick + 1
    render()
  end))

  -- Buffer-local keymaps
  local opts = { buffer = state.render_buf, nowait = true, silent = true }
  vim.keymap.set("n", "j", function() M.scroll(1) end, opts)
  vim.keymap.set("n", "k", function() M.scroll(-1) end, opts)
  vim.keymap.set("n", "<C-d>", function() M.scroll(floor(api.nvim_win_get_height(0) / 2)) end, opts)
  vim.keymap.set("n", "<C-u>", function() M.scroll(-floor(api.nvim_win_get_height(0) / 2)) end, opts)
  vim.keymap.set("n", "G", function()
    local layer = state.layers[state.focus + 1]
    if layer and layer.lines then
      state.scroll_top = max(0, #layer.lines - 10)
      render()
    end
  end, opts)
  vim.keymap.set("n", "gg", function() state.scroll_top = 0; render() end, opts)
  vim.keymap.set("n", "]", function() M.next_layer() end, opts)
  vim.keymap.set("n", "[", function() M.prev_layer() end, opts)
  vim.keymap.set("n", "q", function() M.close() end, opts)
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

function M.toggle()
  if state.active then M.close() else M.open() end
end

return M
