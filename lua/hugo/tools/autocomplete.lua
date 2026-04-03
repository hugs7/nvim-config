-- =========================
-- Autocomplete (nvim-cmp)
-- =========================
local cmp = require("cmp")
local luasnip = require("luasnip")
local holo = require("hugo.ui.holo_borders")

-- Tailwind color swatches in completion menu
local tw_hl_cache = {}
local function extract_hex(field)
  if type(field) == "string" then return field:match("#%x%x%x%x%x%x") end
  if type(field) == "table" and field.value then return field.value:match("#%x%x%x%x%x%x") end
  return nil
end

local function tailwind_format(entry, item)
  if entry.source.name == "nvim_lsp"
    and entry.source.source
    and entry.source.source.client
    and entry.source.source.client.name == "tailwindcss" then
    local ci = entry.completion_item
    local hex = extract_hex(ci.documentation) or extract_hex(ci.detail) or extract_hex(ci.labelDetails and ci.labelDetails.description)
    if hex then
      if not tw_hl_cache[hex] then
        local name = "CmpTw_" .. hex:sub(2)
        vim.api.nvim_set_hl(0, name, { fg = hex })
        tw_hl_cache[hex] = name
      end
      item.kind = "██"
      item.kind_hl_group = tw_hl_cache[hex]
    end
  end
  return item
end

-- Debug: run :CmpTailwindDebug while a completion menu is visible
vim.api.nvim_create_user_command("CmpTailwindDebug", function()
  local entries = cmp.get_entries()
  for i, e in ipairs(entries or {}) do
    if i > 5 then break end
    local ci = e.completion_item
    print(string.format("Entry %d: label=%s kind=%s source=%s", i, ci.label, tostring(ci.kind), e.source.name))
    print("  doc: " .. vim.inspect(ci.documentation))
    print("  detail: " .. vim.inspect(ci.detail))
    print("  labelDetails: " .. vim.inspect(ci.labelDetails))
  end
end, {})

cmp.setup({
  snippet = {
    expand = function(args) luasnip.lsp_expand(args.body) end,
  },
  formatting = {
    format = tailwind_format,
  },
  window = {
    completion = cmp.config.window.bordered({
      border = holo.border(),
      winhighlight = holo.winhighlight(),
    }),
    documentation = cmp.config.window.bordered({
      border = holo.border(),
      winhighlight = holo.winhighlight(),
    }),
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { "i", "s" }),
  }),
  sources = {
    { name = "nvim_lsp" },
    { name = "nvim_lsp_signature_help" },
    { name = "buffer" },
    { name = "path" },
    { name = "luasnip" },
  },
})
