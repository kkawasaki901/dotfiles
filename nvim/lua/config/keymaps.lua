-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "<localleader>e", ":Neotree left <CR>", {desc = "neotree"})

vim.keymap.set("n", "<F1>", "<nop>")

vim.keymap.set("n", "<F1>d", function()
    vim.cmd("Neotree reveal dir=" .. vim.fn.fnameescape(vim.fn.stdpath("data")))
end, {desc = "Neotree @ data"})

vim.keymap.set("n", "<F1>c", function()
    vim.cmd("Neotree reveal dir=" ..
                vim.fn.fnameescape(vim.fn.stdpath("config")))
end, {desc = "Neotree @ config"})

vim.keymap.set("n", "<F3>l", "<cmd>SessionManager load_session<CR>")
vim.keymap.set("n", "<F3>s", "<cmd>SessionManager save_current_session<CR>")

vim.keymap.set("n", "<localleader>qq", function()
    vim.cmd(":SessionManager save_current_session")
    vim.cmd(":qa!")
end, {desc = "close all"})
