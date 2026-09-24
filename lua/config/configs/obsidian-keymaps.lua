require("which-key").add({
  { "<leader>o", group = "Obsidian" },
})
vim.keymap.set("n", "<leader>os", ":ObsidianQuickSwitch<CR>", { desc = "Search Rapida" })
vim.keymap.set("n", "<leader>on", ":ObsidianNew<CR>", { desc = "New Nota" })
vim.keymap.set("n", "<leader>ow", ":ObsidianWorkspace<CR>", { desc = "Cambio de WorkSpace" })
