--- Tailwind color highlighter for @westpac/style-config projects.
--- Automatically parses @theme + brand theme CSS to resolve colors,
--- then decorates Tailwind classes with inline color swatches.
---
--- Per-repo config: .nvim/tailwind-theme.json  e.g. {"brand": "wbc"}

local ns = vim.api.nvim_create_namespace("tailwind_colors")
local THEME_JSON = ".nvim/tailwind-theme.json"
local STYLE_PKG = "node_modules/@westpac/style-config/dist/css"

local PREFIXES = {
  "text", "bg", "border", "ring", "fill", "stroke", "outline",
  "decoration", "accent", "divide", "from", "via", "to", "shadow",
  "placeholder",
}

local FILETYPES = {
  typescriptreact = true, javascriptreact = true,
  typescript = true, javascript = true,
  html = true, css = true, svelte = true, vue = true,
}

local project_colors = {} -- root → color_map
local hl_groups = {}      -- hex → hl_group_name
local active_bufs = {}    -- buf → true
local timers = {}         -- buf → timer

-- ---------------------------------------------------------------------------
-- CSS parsing
-- ---------------------------------------------------------------------------

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local c = f:read("*a")
  f:close()
  return c
end

local function extract_vars(content, sel_pat, stop_pat)
  local vars, inside, depth = {}, false, 0
  for line in content:gmatch("[^\n]+") do
    local t = line:match("^%s*(.-)%s*$")
    if not inside then
      if t:match(sel_pat) and (not stop_pat or not t:match(stop_pat)) then
        inside, depth = true, 1
      end
    else
      if stop_pat and t:match(stop_pat) then break end
      for _ in t:gmatch("{") do depth = depth + 1 end
      for _ in t:gmatch("}") do depth = depth - 1 end
      if depth <= 0 then break end
      local n, v = t:match("^(%-%-[%w%-]+):%s*(.+);$")
      if n then vars[#vars + 1] = { name = n, value = v } end
    end
  end
  return vars
end

local function resolve(val, lookup, d)
  d = d or 0
  if d > 10 then return val end
  return (val:gsub("var%(%-%-([%w%-]+)%)", function(vn)
    local r = lookup["--" .. vn]
    return r and resolve(r, lookup, d + 1) or "var(--" .. vn .. ")"
  end))
end

local function load_colors(root, brand)
  local colors_css = read_file(root .. "/" .. STYLE_PKG .. "/shared/colors.css")
  local theme_css = read_file(root .. "/" .. STYLE_PKG .. "/themes/theme-" .. brand .. ".css")
  if not colors_css or not theme_css then return nil end

  -- @theme block: --color-{name} → var(--semantic)
  local theme_map = {}
  for _, v in ipairs(extract_vars(colors_css, "@theme", nil)) do
    local cn = v.name:match("^%-%-color%-(.+)$")
    if cn then
      local sv = v.value:match("var%((%-%-[%w%-]+)%)")
      if sv then theme_map[cn] = sv end
    end
  end

  -- Variable lookup: reserved + brand
  local lookup = {}
  for _, v in ipairs(extract_vars(colors_css, ":root", nil)) do
    lookup[v.name] = v.value
  end
  for _, v in ipairs(extract_vars(theme_css, "%[data%-brand=", "data%-theme")) do
    lookup[v.name] = v.value
  end

  -- Resolve to hex
  local cmap = {}
  for color_name, semantic_var in pairs(theme_map) do
    local raw = lookup[semantic_var]
    if raw then
      local hex = resolve(raw, lookup)
      if not hex:match("var%(") then
        cmap[color_name] = hex
      end
    end
  end

  return cmap
end

-- ---------------------------------------------------------------------------
-- Highlighting
-- ---------------------------------------------------------------------------

local function contrast_fg(hex)
  local r = tonumber(hex:sub(2, 3), 16) or 0
  local g = tonumber(hex:sub(4, 5), 16) or 0
  local b = tonumber(hex:sub(6, 7), 16) or 0
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.5
      and "#000000" or "#ffffff"
end

local function get_hl(hex)
  if hl_groups[hex] then return hl_groups[hex] end
  local h = hex:match("^(#%x%x%x%x%x%x)") or hex
  local name = "TwCol_" .. h:sub(2)
  vim.api.nvim_set_hl(0, name, { bg = h, fg = contrast_fg(h) })
  hl_groups[hex] = name
  return name
end

local function highlight(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local root = vim.fs.root(buf, "package.json")
  if not root or not project_colors[root] then return end

  local cmap = project_colors[root]
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  for lnum, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local pos = 1
    while pos <= #line do
      local ws, we = line:find("[%w%-:/%.%[%]]+", pos)
      if not ws then break end

      local word = line:sub(ws, we)
      -- Strip variant prefixes (hover:, sm:, etc.)
      local class = word:match(":([^:]+)$") or word
      -- Strip opacity modifier (/50)
      class = class:match("^([^/]+)") or class

      for _, pfx in ipairs(PREFIXES) do
        local plen = #pfx + 1
        if class:sub(1, plen) == pfx .. "-" then
          local hex = cmap[class:sub(plen + 1)]
          if hex then
            local off = word:find(class, 1, true)
            local col = ws - 1 + (off and off - 1 or 0)
            vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, col, {
              end_col = col + #class,
              hl_group = get_hl(hex),
            })
            break
          end
        end
      end

      pos = we + 1
    end
  end
end

local function schedule(buf)
  if timers[buf] then timers[buf]:stop()
  else timers[buf] = vim.uv.new_timer() end
  timers[buf]:start(150, 0, vim.schedule_wrap(function()
    if active_bufs[buf] then highlight(buf) end
  end))
end

--- Try to load colors for a project if not already cached.
local function ensure_loaded(root)
  if project_colors[root] then return true end

  local cfg_raw = read_file(root .. "/" .. THEME_JSON)
  if not cfg_raw then return false end

  local ok, cfg = pcall(vim.json.decode, cfg_raw)
  if not ok or not cfg.brand then return false end

  if not vim.uv.fs_stat(root .. "/" .. STYLE_PKG) then return false end

  local cmap = load_colors(root, cfg.brand)
  if not cmap then return false end

  project_colors[root] = cmap
  return true
end

-- ---------------------------------------------------------------------------
-- Autocommands
-- ---------------------------------------------------------------------------

local group = vim.api.nvim_create_augroup("TailwindColors", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
  group = group,
  callback = function(ev)
    local ft = vim.bo[ev.buf].filetype
    if not FILETYPES[ft] then return end

    local root = vim.fs.root(ev.buf, "package.json")
    if not root then return end
    if not ensure_loaded(root) then return end

    active_bufs[ev.buf] = true
    schedule(ev.buf)
  end,
})

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  group = group,
  callback = function(ev)
    if active_bufs[ev.buf] then schedule(ev.buf) end
  end,
})

vim.api.nvim_create_autocmd("BufDelete", {
  group = group,
  callback = function(ev)
    active_bufs[ev.buf] = nil
    if timers[ev.buf] then
      timers[ev.buf]:stop()
      timers[ev.buf]:close()
      timers[ev.buf] = nil
    end
  end,
})
