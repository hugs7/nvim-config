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
  typescriptreact = true,
  javascriptreact = true,
  typescript = true,
  javascript = true,
  html = true,
  css = true,
  svelte = true,
  vue = true,
}

local project_colors = {} -- root → color_map
local hl_groups = {}      -- hex → hl_group_name
local active_bufs = {}    -- buf → true
local timers = {}         -- buf → timer

--- Find the project root containing .nvim/tailwind-theme.json
local function find_root(buf)
  local res = vim.fs.find(".nvim", {
    upward = true,
    path = vim.api.nvim_buf_get_name(buf),
    type = "directory",
  })
  if res and #res > 0 then
    return vim.fn.fnamemodify(res[1], ":h")
  end
  return nil
end

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

--- Recursively read a CSS file, inlining any @import url("...") or @import "..." statements.
--- Already-visited paths are skipped to avoid cycles.
local function read_css_recursive(path, visited)
  visited = visited or {}
  local abs = vim.fn.resolve(path)
  if visited[abs] then return "" end
  visited[abs] = true

  local content = read_file(abs)
  if not content then return "" end

  local dir = vim.fn.fnamemodify(abs, ":h")
  -- Replace each @import with the contents of the imported file
  return content:gsub('@import%s+url%(%s*["\']([^"\']+)["\']%s*%)', function(rel)
    return read_css_recursive(dir .. "/" .. rel, visited)
  end):gsub('@import%s+["\']([^"\']+)["\']', function(rel)
    return read_css_recursive(dir .. "/" .. rel, visited)
  end)
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

local function load_colors(root, brand, mode)
  local colors_css = read_css_recursive(root .. "/" .. STYLE_PKG .. "/shared/colors.css")
  local theme_css = read_css_recursive(root .. "/" .. STYLE_PKG .. "/themes/theme-" .. brand .. ".css")
  if colors_css == "" or theme_css == "" then return nil end

  -- @theme block: --color-{name} → var(--semantic)
  local theme_map = {}
  for _, v in ipairs(extract_vars(colors_css, "@theme", nil)) do
    local cn = v.name:match("^%-%-color%-(.+)$")
    if cn then
      local sv = v.value:match("var%((%-%-[%w%-]+)%)")
      if sv then theme_map[cn] = sv end
    end
  end

  -- Variable lookup: reserved + brand primitives (light mode base)
  local lookup = {}
  for _, v in ipairs(extract_vars(colors_css, ":root", nil)) do
    lookup[v.name] = v.value
  end
  for _, v in ipairs(extract_vars(theme_css, "%[data%-brand=", "data%-theme")) do
    lookup[v.name] = v.value
  end

  -- Override with dark mode semantics if requested
  if mode == "dark" then
    for _, v in ipairs(extract_vars(theme_css, "data%-theme", nil)) do
      lookup[v.name] = v.value
    end
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

local function blend(hex, opacity)
  if not opacity or opacity >= 100 then return hex end
  local a = opacity / 100
  -- Blend against editor background (fallback to #1e1e2e)
  local bg_hl = vim.api.nvim_get_hl(0, { name = "Normal" })
  local bg = bg_hl.bg or 0x1e1e2e
  local bg_r, bg_g, bg_b = math.floor(bg / 65536) % 256, math.floor(bg / 256) % 256, bg % 256
  local r = tonumber(hex:sub(2, 3), 16) or 0
  local g = tonumber(hex:sub(4, 5), 16) or 0
  local b = tonumber(hex:sub(6, 7), 16) or 0
  local nr = math.floor(r * a + bg_r * (1 - a) + 0.5)
  local ng = math.floor(g * a + bg_g * (1 - a) + 0.5)
  local nb = math.floor(b * a + bg_b * (1 - a) + 0.5)
  return string.format("#%02x%02x%02x", nr, ng, nb)
end

local function get_hl(hex, opacity)
  local key = hex .. "/" .. (opacity or 100)
  if hl_groups[key] then return hl_groups[key] end
  local h = blend(hex:match("^(#%x%x%x%x%x%x)") or hex, opacity)
  local name = "TwCol_" .. h:sub(2) .. "_" .. (opacity or 100)
  vim.api.nvim_set_hl(0, name, { bg = h, fg = contrast_fg(h) })
  hl_groups[key] = name
  return name
end

local function highlight(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local root = find_root(buf)
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
      -- Extract opacity modifier (/50)
      local base_class, opacity_str = class:match("^([^/]+)/(%d+)$")
      if not base_class then base_class = class end
      local opacity = opacity_str and tonumber(opacity_str) or nil

      for _, pfx in ipairs(PREFIXES) do
        local plen = #pfx + 1
        if base_class:sub(1, plen) == pfx .. "-" then
          local hex = cmap[base_class:sub(plen + 1)]
          if hex then
            local off = word:find(base_class, 1, true)
            local col = ws - 1 + (off and off - 1 or 0)
            local end_col = col + #class -- highlight includes /opacity
            vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, col, {
              end_col = end_col,
              hl_group = get_hl(hex, opacity),
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
  if timers[buf] then
    timers[buf]:stop()
  else
    timers[buf] = vim.uv.new_timer()
  end
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

  local cmap = load_colors(root, cfg.brand, cfg.mode or "light")
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

    local root = find_root(ev.buf)
    if not root then return end
    if not ensure_loaded(root) then return end

    active_bufs[ev.buf] = true
    schedule(ev.buf)
  end,
})

-- Debug command: check what the plugin sees
vim.api.nvim_create_user_command("TailwindColorsInit", function()
  local root = vim.fn.getcwd()
  local dir = root .. "/.nvim"
  local path = dir .. "/" .. THEME_JSON:match("[^/]+$")
  if not vim.uv.fs_stat(dir) then vim.fn.mkdir(dir, "p") end
  local f = io.open(path, "w")
  if not f then
    vim.notify("Failed to write " .. path, vim.log.levels.ERROR)
    return
  end
  f:write('{\n  "brand": "wbc",\n  "mode": "light"\n}\n')
  f:close()
  -- Clear cache so it reloads with the new config
  project_colors[root] = nil
  vim.notify("Created " .. path, vim.log.levels.INFO)
  -- Trigger highlight for current buffer
  local buf = vim.api.nvim_get_current_buf()
  if FILETYPES[vim.bo[buf].filetype] and ensure_loaded(root) then
    active_bufs[buf] = true
    schedule(buf)
  end
end, {})

vim.api.nvim_create_user_command("TailwindColorsDebug", function()
  local buf = vim.api.nvim_get_current_buf()
  local ft = vim.bo[buf].filetype
  print("Filetype: " .. ft .. " (tracked: " .. tostring(FILETYPES[ft] or false) .. ")")

  local root = find_root(buf)
  print("Project root: " .. (root or "NOT FOUND"))
  if not root then return end

  print("Theme config: " .. root .. "/" .. THEME_JSON)
  print("  exists: " .. tostring(vim.uv.fs_stat(root .. "/" .. THEME_JSON) ~= nil))

  print("Style pkg: " .. root .. "/" .. STYLE_PKG)
  print("  exists: " .. tostring(vim.uv.fs_stat(root .. "/" .. STYLE_PKG) ~= nil))

  local cfg_raw = read_file(root .. "/" .. THEME_JSON)
  if cfg_raw then
    local ok, cfg = pcall(vim.json.decode, cfg_raw)
    print("  brand: " .. (ok and cfg.brand or "PARSE ERROR"))
  end

  if project_colors[root] then
    local count = 0
    for _ in pairs(project_colors[root]) do count = count + 1 end
    print("Cached colors: " .. count)
    -- Show a few examples
    local i = 0
    for name, hex in pairs(project_colors[root]) do
      print("  " .. name .. " → " .. hex)
      i = i + 1
      if i >= 5 then break end
    end
  else
    print("Cached colors: NONE (not loaded)")
    -- Try loading now
    if ensure_loaded(root) then
      local count = 0
      for _ in pairs(project_colors[root]) do count = count + 1 end
      print("After manual load: " .. count .. " colors")
    else
      print("Manual load FAILED")
    end
  end

  print("Buffer active: " .. tostring(active_bufs[buf] or false))
end, {})

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
