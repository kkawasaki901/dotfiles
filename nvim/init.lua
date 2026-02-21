-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.g.maploacalleader = "\\"

vim.o.swapfile = false

vim.opt.tabstop = 4 -- タブが占めるスペースの数
vim.opt.softtabstop = 4 -- ソフトタブの数
vim.opt.shiftwidth = 4 -- シフト（<<や>>）時のスペースの数
vim.opt.expandtab = true -- タブをスペースに変換する
vim.opt.autoindent = true -- 新しい行のインデントを前行に合わせる
vim.opt.smartindent = true -- スマートインデントを有効にする

vim.keymap.set("n", "<leader>fd", function()
    require("telescope.builtin").find_files({
        find_command = {"fd", "--type", "d"},
        attach_mappings = function(prompt_bufnr, map)
            local actions = require("telescope.actions")
            local action_state = require("telescope.actions.state")

            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                require("neo-tree.command").execute({
                    action = "focus",
                    source = "filesystem",
                    dir = selection.path
                })
            end)
            return true
        end
    })
end, {desc = "fd-find"})
