-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.g.maploacalleader = "\\"

vim.o.swapfile = false

vim.keymap.set("n", "<leader>fd", function()
  require("telescope.builtin").find_files({
    find_command = { "fd", "--type", "d" },
    attach_mappings = function(prompt_bufnr, map)
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")

      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        require("neo-tree.command").execute({
          action = "focus",
          source = "filesystem",
          dir = selection.path,
        })
      end)
      return true
    end,
  })
end, { desc = "fd-find" })
