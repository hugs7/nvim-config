local utf8 = vim.uv or vim.loop
local M = {}

-- base Braille block (U+2800)
local base_braille = 0x2800

-- Safe utf8.char() substitute
local function uchar(code)
  -- LuaJIT/Neovim-safe UTF-8 encoder
  if code < 0x80 then
    return string.char(code)
  elseif code < 0x800 then
    return string.char(
      0xC0 + math.floor(code / 0x40),
      0x80 + (code % 0x40)
    )
  elseif code < 0x10000 then
    return string.char(
      0xE0 + math.floor(code / 0x1000),
      0x80 + (math.floor(code / 0x40) % 0x40),
      0x80 + (code % 0x40)
    )
  elseif code < 0x110000 then
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

local function fromBraille(char)
  local code = vim.fn.char2nr(char)
  local diff = code - base_braille
  if diff >= 0 and diff <= 25 then
    return string.char(65 + diff)
  elseif diff >= 0 and diff <= 9 then
    return string.char(48 + diff)
  else
    return char
  end
end

local function mapLine(line, fn)
  local chars = vim.fn.split(line, '\\zs') -- UTF‑8 safe split
  for i, c in ipairs(chars) do
    chars[i] = fn(c)
  end
  return table.concat(chars, "")
end

function M.to_braille()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    lines[i] = mapLine(line, toBraille)
  end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.notify("🔮 Braille mode ON")
end

function M.from_braille()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    lines[i] = mapLine(line, fromBraille)
  end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.notify("🪄 Braille mode OFF")
end

return M
