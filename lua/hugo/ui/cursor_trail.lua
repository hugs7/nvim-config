local M = {}
local api = vim.api

local ns = api.nvim_create_namespace("cursor_trail")

local state = {
  active = false,
  aug = nil,
  trail = {}, -- list of { buf, row, col, tick }
  max_trail = 8,
  fade_ms = 40, -- ms between fade steps
}

-- Trail colors from bright to dim
local trail_colors = {
  "#00e5ff",
  "#00c8e0",
  "#00a0b8",
  "#007890",
  "#005068",
  "#003848",
  "#002030",
  "#001018",
}

local function setup_hl()
  for i, color in ipairs(trail_colors) do
    api.nvim_set_hl(0, "CursorTrail" .. i, { bg = color })
  end
  -- Bright glow on current position
  api.nvim_set_hl(0, "CursorGlow", { bg = "#00e5ff", fg = "#0a0e14", bold = true })
end

local function clear_trail()
  for _, entry in ipairs(state.trail) do
    if api.nvim_buf_is_valid(entry.buf) then
      pcall(api.nvim_buf_del_extmark, entry.buf, ns, entry.id)
    end
  end
  state.trail = {}
end

local function add_trail_point(buf, row, col)
  if not api.nvim_buf_is_valid(buf) then return end

  -- Don't trail in special buffers
  if vim.bo[buf].buftype ~= "" then return end

  local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  if not line or col >= #line then return end

  -- Create extmark for this trail point
  local ok, id = pcall(api.nvim_buf_set_extmark, buf, ns, row, col, {
    end_col = col + 1,
    hl_group = "CursorTrail1",
    priority = 200,
  })

  if ok then
    table.insert(state.trail, 1, { buf = buf, row = row, col = col, id = id, step = 1 })
  end

  -- Trim trail to max length
  while #state.trail > state.max_trail do
    local old = table.remove(state.trail)
    if api.nvim_buf_is_valid(old.buf) then
      pcall(api.nvim_buf_del_extmark, old.buf, ns, old.id)
    end
  end

  -- Update trail colors (older = dimmer)
  for i, entry in ipairs(state.trail) do
    if api.nvim_buf_is_valid(entry.buf) then
      local hl_idx = math.min(i, #trail_colors)
      pcall(api.nvim_buf_set_extmark, entry.buf, ns, entry.row, entry.col, {
        id = entry.id,
        end_col = entry.col + 1,
        hl_group = "CursorTrail" .. hl_idx,
        priority = 200 - i,
      })
    end
  end

  -- Schedule fade-out of oldest entries
  vim.defer_fn(function()
    if not state.active then return end
    -- Remove trail points that have aged out
    local new_trail = {}
    for i, entry in ipairs(state.trail) do
      if i <= state.max_trail - 2 then
        new_trail[#new_trail + 1] = entry
      else
        if api.nvim_buf_is_valid(entry.buf) then
          pcall(api.nvim_buf_del_extmark, entry.buf, ns, entry.id)
        end
      end
    end
    state.trail = new_trail
  end, state.fade_ms * state.max_trail)
end

local last_pos = { 0, 0 }

local function on_cursor_move()
  if not state.active then return end
  local buf = api.nvim_get_current_buf()
  local pos = api.nvim_win_get_cursor(0)
  local row, col = pos[1] - 1, pos[2]

  -- Only trail if we actually moved
  if row == last_pos[1] and col == last_pos[2] then return end

  add_trail_point(buf, last_pos[1], last_pos[2])
  last_pos = { row, col }
end

function M.open()
  if state.active then return end
  setup_hl()
  state.active = true

  local pos = api.nvim_win_get_cursor(0)
  last_pos = { pos[1] - 1, pos[2] }

  state.aug = api.nvim_create_augroup("CursorTrail", { clear = true })
  api.nvim_create_autocmd("CursorMoved", {
    group = state.aug,
    callback = on_cursor_move,
  })
end

function M.close()
  state.active = false
  if state.aug then
    pcall(api.nvim_del_augroup_by_id, state.aug)
    state.aug = nil
  end
  clear_trail()
end

function M.toggle()
  if state.active then M.close() else M.open() end
end

return M
