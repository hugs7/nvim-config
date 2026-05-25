-- =========================
-- Core (must load before plugins)
-- =========================
require("hugo.core.options")
require("hugo.core.bigfile")

-- =========================
-- Plugin manager
-- =========================
require("hugo.lazy")

-- =========================
-- Keymaps
-- =========================
require("hugo.core.keymaps")

-- =========================
-- UI
-- =========================
require('hugo.ui.holo_borders').setup()
require('hugo.ui.diagnostic')
require('hugo.ui.lualine')
require('hugo.ui.nvim_tree')
require('hugo.ui.telescope')

-- =========================
-- Tools
-- =========================
-- gitsigns is configured via lazy.nvim (lua/hugo/lazy.lua); do not call
-- require("gitsigns").setup() here or it loads before lazy's opts apply and
-- causes "attempt to index field 'repo' (a nil value)" in current_line_blame.
require('hugo.tools.autocomplete')
require('hugo.tools.debug')
require('hugo.tools.lsp')
require("hugo.tools.mason")
require("hugo.tools.tailwind_colors")

-- =========================
-- Languages
-- =========================
require("hugo.langs.typescript")
