-- =========================
-- Plugin manager
-- =========================
require("hugo.lazy")

-- =========================
-- UI
-- =========================
require("hugo.core.options")
require("hugo.core.keymaps")

-- =========================
-- UI
-- =========================
require('hugo.ui.diagnostic')
require('hugo.ui.lualine')
require('hugo.ui.nvim_tree')
require('hugo.ui.telescope')

-- =========================
-- Tools
-- =========================
require("gitsigns").setup()
require('hugo.tools.autocomplete')
require('hugo.tools.debug')
require('hugo.tools.lsp')
require("hugo.tools.mason")

-- =========================
-- Languages
-- =========================
require("hugo.langs.typescript")
