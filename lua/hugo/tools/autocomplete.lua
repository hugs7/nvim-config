-- =========================
-- Autocomplete (nvim-cmp)
-- =========================
local cmp = require("cmp")
local luasnip = require("luasnip")
local holo = require("hugo.ui.holo_borders")

cmp.setup({
  snippet = {
    expand = function(args) luasnip.lsp_expand(args.body) end,
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
