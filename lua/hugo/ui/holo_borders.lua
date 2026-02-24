local M = {}
local api = vim.api

-- Gradient cyan border colors from bright to dim
local gradient_colors = {
  "#00e5ff",
  "#00c8e0",
  "#00abc2",
  "#008ea3",
  "#007185",
  "#005466",
  "#003748",
  "#001a2a",
}

local function setup_hl()
  for i, color in ipairs(gradient_colors) do
    api.nvim_set_hl(0, "HoloBorder" .. i, { fg = color, bg = "#0a0e14" })
  end
  api.nvim_set_hl(0, "HoloFloat", { bg = "#0a0e14" })
end

-- Custom border chars with gradient highlight groups
-- The border array uses {char, highlight} pairs
-- Pattern: top-left corner is brightest, cycles through gradient
local function make_border()
  return {
    { "╭", "HoloBorder1" },
    { "─", "HoloBorder2" },
    { "╮", "HoloBorder3" },
    { "│", "HoloBorder4" },
    { "╯", "HoloBorder5" },
    { "─", "HoloBorder6" },
    { "╰", "HoloBorder7" },
    { "│", "HoloBorder8" },
  }
end

-- Animated border that cycles the gradient
local state = {
  timer = nil,
  active = false,
  offset = 0,
  interval = 150, -- ms per frame
}

local function make_animated_border(offset)
  local chars = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
  local border = {}
  for i, char in ipairs(chars) do
    local idx = ((i - 1 + offset) % #gradient_colors) + 1
    border[i] = { char, "HoloBorder" .. idx }
  end
  return border
end

-- Override default float border styles
function M.setup()
  setup_hl()

  local border = make_border()

  -- Override LSP hover and signature help borders
  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
    vim.lsp.handlers.hover, {
      border = border,
    }
  )

  vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
    vim.lsp.handlers.signature_help, {
      border = border,
    }
  )

  -- Set diagnostic float border
  vim.diagnostic.config({
    float = {
      border = border,
    },
  })

  -- Override vim.lsp.buf.hover to use our border
  local orig_open_floating_preview = vim.lsp.util.open_floating_preview
  vim.lsp.util.open_floating_preview = function(contents, syntax, opts, ...)
    opts = opts or {}
    if not opts.border then
      opts.border = border
    end
    return orig_open_floating_preview(contents, syntax, opts, ...)
  end
end

-- Animated glow pulse that cycles border colors on all visible float windows
function M.start_pulse()
  if state.active then return end
  setup_hl()
  state.active = true
  state.offset = 0

  local uv = vim.uv or vim.loop
  state.timer = uv.new_timer()
  state.timer:start(0, state.interval, vim.schedule_wrap(function()
    if not state.active then return end
    state.offset = (state.offset + 1) % #gradient_colors

    -- Update highlight groups to create a cycling effect
    for i, _ in ipairs(gradient_colors) do
      local idx = ((i - 1 + state.offset) % #gradient_colors) + 1
      api.nvim_set_hl(0, "HoloBorder" .. i, { fg = gradient_colors[idx], bg = "#0a0e14" })
    end
  end))
end

function M.stop_pulse()
  state.active = false
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
  -- Reset to static gradient
  setup_hl()
end

function M.toggle_pulse()
  if state.active then M.stop_pulse() else M.start_pulse() end
end

return M
