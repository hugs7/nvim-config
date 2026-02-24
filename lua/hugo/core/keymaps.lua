-- =========================
-- Pane Navigation Shortcuts
-- =========================
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-l>", "<C-w>l")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-j>", "<C-w>j")

-- =========================
-- Quality of life keymaps
-- =========================

-- Ctrl+Backspace → delete previous word
vim.keymap.set("i", "<C-H>", "<C-w>", {
  noremap = true
})

-- Ctrl+Delete → delete next word
vim.keymap.set("i", "<C-Del>", "<C-o>de", {
  noremap = true
})

-- Focus editor
vim.keymap.set("n", "<leader>ee", "<C-w>l", {
  noremap = true,
  silent = true,
  desc = "Focus editor"
})

-- Find file by name
vim.keymap.set("n", "<C-p>", ":Telescope find_files<CR>", {
  noremap = true,
  silent = true,
  desc = "Quick Open"
})

-- Adjust Nvim Tree Width
vim.keymap.set("n", "<leader>=", "<cmd>vertical resize +5<CR>", {
  desc = "Increase NvimTree width"
})
vim.keymap.set("n", "<leader>-", "<cmd>vertical resize -5<CR>", {
  desc = "Decrease NvimTree width"
})

-- Adjust pane height
vim.keymap.set("n", "<leader>+", "<cmd>resize +5<CR>", {
  desc = "Increase pane height"
})
vim.keymap.set("n", "<leader>_", "<cmd>resize -5<CR>", {
  desc = "Decrease pane height"
})

-- =========================
-- Tab (Buffer) Navigation
-- =========================
vim.keymap.set("n", "<Tab>", "<cmd>BufferLineCycleNext<CR>", { desc = "Next tab" })
vim.keymap.set("n", "<S-Tab>", "<cmd>BufferLineCyclePrev<CR>", { desc = "Previous tab" })
vim.keymap.set("n", "<leader>x", "<cmd>bdelete<CR>", { desc = "Close tab" })
vim.keymap.set("n", "<leader>bp", "<cmd>BufferLineTogglePin<CR>", { desc = "Pin tab" })

-- Copy open file path
vim.keymap.set('n', '<leader>cp', function()
  local abs = vim.fn.expand('%:p')
  local rel = vim.fn.fnamemodify(abs, ':.')
  vim.fn.setreg('+', rel)
  print("Copied path: " .. rel)
end)

vim.keymap.set("n", "<leader>rr", function()
  vim.cmd("restart")
end, {
  desc = "Restart Neovim and restore buffers"
})

-- 3D depth view (git history layers)
vim.keymap.set("n", "<leader>3d", function()
  require("hugo.ui.depth").toggle()
end, {
  desc = "Toggle 3D git depth view"
})
vim.keymap.set("n", "<leader>]", function()
  require("hugo.ui.depth").next_layer()
end, {
  desc = "3D: focus deeper layer"
})
vim.keymap.set("n", "<leader>[", function()
  require("hugo.ui.depth").prev_layer()
end, {
  desc = "3D: focus shallower layer"
})

-- Radar minimap
vim.keymap.set("n", "<leader>mr", function()
  require("hugo.ui.radar").toggle()
end, {
  desc = "Toggle radar minimap"
})

-- HUD widget
vim.keymap.set("n", "<leader>mh", function()
  require("hugo.ui.hud").toggle()
end, {
  desc = "Toggle Jarvis HUD"
})

-- Holographic border pulse
vim.keymap.set("n", "<leader>mg", function()
  require("hugo.ui.holo_borders").toggle_pulse()
end, {
  desc = "Toggle holographic border glow"
})

-- Cursor trail
vim.keymap.set("n", "<leader>mt", function()
  require("hugo.ui.cursor_trail").toggle()
end, {
  desc = "Toggle cursor trail"
})

-- Sound effects
vim.keymap.set("n", "<leader>ms", function()
  require("hugo.ui.sounds").toggle()
end, {
  desc = "Toggle Jarvis sound effects"
})

-- Matrix rain
vim.keymap.set("n", "<leader>mx", function()
  require("hugo.ui.matrix").toggle()
end, {
  desc = "Toggle Matrix rain"
})

-- Braile--
local is_braille_active = false

vim.keymap.set("n", "<leader>br", function()
  local braille = require("hugo.ui.braille")

  if is_braille_active then
    braille.clear()
  else
    braille.overlay()
  end

  is_braille_active = not is_braille_active
end, {
  desc = "Toggle Braille overlay"
})

-- =========================
-- TypeScript Keymaps
-- =========================
local typescript = require("hugo.langs.typescript")
vim.keymap.set("n", "<leader>fi", typescript.fix_imports_sequential, {
  desc = "Fix imports (remove unused + organize)"
})

-- =============
-- React Keymaps
-- =============
local react_components = require("hugo.utils.react-components")
local react_component_test = require("hugo.utils.react-component-test")
local react_hooks = require('hugo.utils.react-hooks')
local react_providers = require('hugo.utils.react-providers')
local barrel = require('hugo.utils.barrel')

vim.keymap.set("n", "<leader>rafc", react_components.insert_afc, {
  desc = "Insert React function component"
})
vim.keymap.set("n", "<leader>rafct", react_components.insert_afc_with_types, {
  desc = "Insert React function component with types"
})
vim.keymap.set("n", "<leader>rc", react_components.create_component, {
  desc = "Create React component"
})
vim.keymap.set("n", "<leader>rct", react_components.create_component_with_types, {
  desc = "Create React component with types"
})

vim.keymap.set("n", "<leader>rcv", react_component_test.generate_react_test, {
  desc = "Create React component test"
})

vim.keymap.set("n", "<leader>rh", react_hooks.create_hook, {
  desc = "Create React hook"
})
vim.keymap.set("n", "<leader>rht", react_hooks.create_hook_with_types, {
  desc = "Create React hook with types"
})

vim.keymap.set("n", "<leader>rp", react_providers.create_provider, {
  desc = "Create React Provider"
})

vim.keymap.set("n", "<leader>bf", barrel.generate_barrel_export, {
  desc = "Generate barrel file"
})
