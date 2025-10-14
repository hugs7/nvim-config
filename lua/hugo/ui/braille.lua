local M = {}
local ns = vim.api.nvim_create_namespace("braille")
local base_braille = 0x2800

-- Same UTF-8 encoder as before
local function uchar(code)
  if code < 0x80 then
    return string.char(code)
  elseif code < 0x800 then
    return string.char(0xC0 + math.floor(code / 0x40), 0x80 + (code % 0x40))
  elseif code < 0x10000 then
    return string.char(
      0xE0 + math.floor(code / 0x1000),
      0x80 + (math.floor(code / 0x40) % 0x40),
      0x80 + (code % 0x40)
    )
  else
    return string.char(
      0xF0 + math.floor(code / 0x40000),
      0x80 + (math.floor(code / 0x1000) % 0x40),
      0x80 + (math.floor(code / 0x40) % 0x40),
      0x80 + (code % 0x40)
    )
  end
end

local function toBraille(char)
  local byte = string.byte(char)
  if not byte then return char end

  if byte >= 65 and byte <= 90 then      -- A-Z
    return uchar(base_braille + (byte - 65))
  elseif byte >= 97 and byte <= 122 then -- a-z
    return uchar(base_braille + (byte - 97))
  elseif byte >= 48 and byte <= 57 then  -- 0–9
    return uchar(base_braille + (byte - 48))
  else
    return char
  end
end

function M.overlay()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for row, line in ipairs(lines) do
    local chars = vim.fn.split(line, '\\zs')
    for col, char in ipairs(chars) do
      local braille = toBraille(char)
      vim.api.nvim_buf_set_extmark(bufnr, ns, row - 1, col - 1, {
        virt_text = { { braille, "Normal" } },
        virt_text_pos = "overlay",
      })
    end
  end

  vim.notify("🧿 Braille overlay applied (non-destructive)")
end

function M.clear()
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
  vim.notify("🔓 Braille overlay cleared")
end

return M
