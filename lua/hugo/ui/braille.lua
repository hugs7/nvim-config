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

local function get_syntax_or_ts_highlight(bufnr, row, col)
  -- 1. Try Treesitter
  local highlighter = require("vim.treesitter.highlighter")
  local active = highlighter.active[bufnr]
  if active then
    local ok, result = pcall(function()
      local highlights = {}
      active.tree:for_each_tree(function(tstree, ltree)
        local ts = vim.treesitter
        local lang = ltree:lang()
        local query = ts.query.get(lang, "highlights")
        if not query then return end
        local root = tstree:root()
        if not root then return end

        for id, node in query:iter_captures(root, bufnr, row, row + 1) do
          local sr, sc, er, ec = node:range()
          if row >= sr and row <= er and col >= sc and col < ec then
            local name = query.captures[id]
            if name then
              table.insert(highlights, "@" .. name)
            end
          end
        end
      end)
      return highlights[#highlights]
    end)

    if ok and result then
      return result
    end
  end

  -- 2. Fallback: use legacy syntax group
  local id = vim.fn.synIDtrans(vim.fn.synID(row + 1, col + 1, true))
  local name = vim.fn.synIDattr(id, "name")
  return name ~= "" and name or "Normal"
end

function M.overlay()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for row, line in ipairs(lines) do
    local chars = vim.fn.split(line, '\\zs')
    for col, char in ipairs(chars) do
      local braille = toBraille(char)

      local hl_group = get_syntax_or_ts_highlight(bufnr, row - 1, col - 1)

      -- Guard fallback if invalid
      if type(hl_group) ~= "string" or hl_group == "" or hl_group == "0" then
        hl_group = "Normal"
      end

      if type(braille) ~= "string" then
        braille = "⠿"
      end

      local ok, err = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row - 1, col - 1, {
        virt_text = { { braille, hl_group } },
        virt_text_pos = "overlay",
      })

      if not ok then
        vim.schedule(function()
          vim.notify(
            string.format("💥 extmark failed at [%d:%d] — virt_text = { %q, %q }", row, col, braille, hl_group),
            vim.log.levels.ERROR
          )
        end)
      end
    end
  end

  if M._auto_group then
    vim.api.nvim_del_autocmd(M._auto_group)
  end

  M._auto_group = vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = bufnr,
    callback = function()
      vim.schedule(M.overlay) -- re-render overlay on buffer changes
    end,
    desc = "Live Braille overlay",
  })
end

function M.clear()
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
  if M._auto_group then
    vim.api.nvim_del_autocmd(M._auto_group)
    M._auto_group = nil
  end
end

return M
