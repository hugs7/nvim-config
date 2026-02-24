local M = {}
local api = vim.api
local fn = vim.fn
local floor, min, max = math.floor, math.min, math.max

local VISIBLE_DEPTHS = 5

local state = {
  active = false,
  orig_buf = nil,
  orig_win = nil,
  render_buf = nil,
  layers = {},
  focus = 0,
  scroll_top = 0,
  filepath = nil,
  ns = api.nvim_create_namespace("depth3d"),
}

local function setup_hl()
  -- Active layer: full brightness
  api.nvim_set_hl(0, "D3dFocus", { fg = "#e0e0e0" })
  -- Subsequent layers: 20%, 15%, 10%, 5% opacity
  api.nvim_set_hl(0, "D3d1", { fg = "#444444" })
  api.nvim_set_hl(0, "D3d2", { fg = "#363636" })
  api.nvim_set_hl(0, "D3d3", { fg = "#282828" })
  api.nvim_set_hl(0, "D3d4", { fg = "#1e1e1e" })
  api.nvim_set_hl(0, "D3dHeader", { fg = "#00e5ff", italic = true })
end

local function hl_for_depth(d)
  if d == 0 then return "D3dFocus" end
  if d <= 4 then return "D3d" .. d end
  return nil
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

-- Perspective: more indent at top (receding), less at bottom (closer)
-- Deeper layers get more aggressive skew + base offset
local function indent_at(y, h, d)
  local t = (h - 1 - y) / max(h - 1, 1) -- 1 at top, 0 at bottom
  return floor(t * (2 + d * 1.5) + d * 3)
end

local function render()
  if not state.active or not state.render_buf or not api.nvim_buf_is_valid(state.render_buf) then return end
  if not state.orig_win or not api.nvim_win_is_valid(state.orig_win) then return end

  local width = api.nvim_win_get_width(state.orig_win)
  local height = api.nvim_win_get_height(state.orig_win) - 1 -- leave room for header

  local output = {}
  local all_hls = {}

  for row = 1, height do
    -- Initialize cells
    local cells = {}
    local cell_hls = {}
    for col = 1, width do
      cells[col] = " "
      cell_hls[col] = nil
    end

    -- Composite layers: back to front
    for depth = VISIBLE_DEPTHS, 0, -1 do
      local layer_idx = state.focus + depth + 1
      local layer = state.layers[layer_idx]
      if not layer then goto next end

      local hl = hl_for_depth(depth)
      if not hl then goto next end

      local lines = load_lines(layer, state.filepath)
      local src_idx = (row - 1) + state.scroll_top + 1
      local src = lines[src_idx] or ""

      local indent = indent_at(row - 1, height, depth)

      -- Only place non-whitespace chars so back layers show through gaps
      for i = 1, #src do
        local ch = src:sub(i, i)
        if ch:match("%S") then
          local col = indent + i
          if col >= 1 and col <= width then
            cells[col] = ch
            cell_hls[col] = hl
          end
        end
      end

      ::next::
    end

    -- Build output line tracking byte offsets for highlights
    local parts = {}
    local row_hls = {}
    local byte_pos = 0
    local run_start, run_hl = 0, nil

    for col = 1, width do
      local ch = cells[col]
      local h = cell_hls[col]
      local ch_len = #ch

      if h ~= run_hl then
        if run_hl then
          row_hls[#row_hls + 1] = { run_start, byte_pos, run_hl }
        end
        run_start = byte_pos
        run_hl = h
      end

      byte_pos = byte_pos + ch_len
      parts[col] = ch
    end
    if run_hl then
      row_hls[#row_hls + 1] = { run_start, byte_pos, run_hl }
    end

    output[row] = table.concat(parts)
    all_hls[row] = row_hls
  end

  -- Update buffer
  vim.bo[state.render_buf].modifiable = true
  api.nvim_buf_set_lines(state.render_buf, 0, -1, false, output)
  vim.bo[state.render_buf].modifiable = false

  -- Apply highlights
  api.nvim_buf_clear_namespace(state.render_buf, state.ns, 0, -1)
  for row, row_hls in ipairs(all_hls) do
    for _, h in ipairs(row_hls) do
      pcall(api.nvim_buf_add_highlight, state.render_buf, state.ns, h[3], row - 1, h[1], h[2])
    end
  end

  -- Header showing layer info
  local layer = state.layers[state.focus + 1]
  local label = layer and layer.label or "?"
  local header = ("── Layer %d/%d ── %s ── [q] close  [j/k] scroll  []/[] layers ──"):format(
    state.focus + 1, #state.layers, label
  )
  api.nvim_buf_set_extmark(state.render_buf, state.ns, 0, 0, {
    virt_lines_above = true,
    virt_lines = { { { header, "D3dHeader" } } },
  })
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
  if state.orig_win and api.nvim_win_is_valid(state.orig_win) then
    if state.orig_buf and api.nvim_buf_is_valid(state.orig_buf) then
      api.nvim_win_set_buf(state.orig_win, state.orig_buf)
    end
  end
  if state.render_buf and api.nvim_buf_is_valid(state.render_buf) then
    api.nvim_buf_delete(state.render_buf, { force = true })
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

  api.nvim_win_set_buf(state.orig_win, state.render_buf)

  state.focus = 0
  state.scroll_top = 0
  state.active = true

  render()

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
  vim.keymap.set("n", "gg", function()
    state.scroll_top = 0
    render()
  end, opts)
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
