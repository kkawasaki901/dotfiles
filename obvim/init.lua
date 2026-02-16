-- =========================================================
-- Obsidian-focused Neovim config (single init.lua)
-- - obsidian.nvim
-- - which-key.nvim
-- - neo-tree.nvim
-- - render-markdown.nvim (better markdown view)
-- =========================================================

-- Leaders
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Basic UI / editing
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.termguicolors = true
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 200
vim.opt.clipboard = "unnamedplus"

vim.g.clipboard = {
  name = "win32yank-wsl",
  copy = {
    ["+"] = { "win32yank.exe", "-i", "--crlf" },
    ["*"] = { "win32yank.exe", "-i", "--crlf" },
  },
  paste = {
    ["+"] = { "win32yank.exe", "-o", "--lf" },
    ["*"] = { "win32yank.exe", "-o", "--lf" },
  },
  cache_enabled = 0,
}

-- Obsidian.nvim recommended
vim.opt.conceallevel = 1
vim.opt.concealcursor = "nc"

-- Lazy.nvim bootstrap
-- =========================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- =========================================================
-- Plugins
-- =========================================================

require("lazy").setup({
  spec = {
    -- add LazyVim and import its plugins
    -- import/override with your plugins
    { import = "plugins" },
  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = {
    enabled = false, -- check for plugin updates periodically
    notify = false, -- notify on update
  }, -- automatically check for plugin updates
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
-- =========================================================
-- Keymaps
-- =========================================================
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Neo-tree
map("n", "<leader>e", "<cmd>Neotree toggle<cr>", opts)
-- map("n", "<leader>o", "<cmd>Neotree focus<cr>", opts)

-- Obsidian commands (leader o ...)
map("n", "<leader>oo", "<cmd>ObsidianOpen<cr>", opts)
map("n", "<leader>oq", "<cmd>ObsidianQuickSwitch<cr>", opts)
map("n", "<leader>of", "<cmd>ObsidianSearch<cr>", opts)
map("n", "<leader>on", "<cmd>ObsidianNew<cr>", opts)
map("n", "<leader>ot", "<cmd>ObsidianToday<cr>", opts)
map("n", "<leader>oy", "<cmd>ObsidianYesterday<cr>", opts)
map("n", "<leader>om", "<cmd>ObsidianTomorrow<cr>", opts)
map("n", "<leader>ol", "<cmd>ObsidianLinks<cr>", opts)
map("n", "<leader>ob", "<cmd>ObsidianBacklinks<cr>", opts)

-- Markdown render toggle (render-markdown)
-- plugin provides :RenderMarkdown (toggle)
map("n", "<leader>mr", "<cmd>RenderMarkdown toggle<cr>", opts)

-- =========================================================
-- which-key registrations (optional but nice)
-- =========================================================
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    local ok, wk = pcall(require, "which-key")
    if not ok then return end

    wk.add({
      { "<leader>e", desc = "Neo-tree: Toggle" },
      -- { "<leader>o", desc = "Neo-tree: Focus" },
      { "<leader>m", group = "Markdown" },
      { "<leader>mr", desc = "Markdown: Render toggle" },
      { "<leader>l", group = "Links" },
      { "<leader>lf", desc = "Link: Follow" },
      { "<leader>ld", desc = "Link: Destroy" },
      { "<leader>ll", desc = "Link: Create (existing)" },
      { "<leader>ln", desc = "Link: Create (new)" },
      { "<leader>lt", desc = "Link: Toggle checkbox" },
      { "<leader>lr", desc = "Link: Rename note" },
      { "<leader>lb", desc = "Link: Backlinks" },
      { "<leader>t", group = "Table" },
      { "<leader>tr", desc = "Table: New row below" },
      { "<leader>tR", desc = "Table: New row above" },
      { "<leader>tc", desc = "Table: New col after" },
      { "<leader>tC", desc = "Table: New col before" },
      { "<leader>ta", desc = "Table: Align" },
      { "<leader>tf", desc = "Table: Format" },
      { "<leader>o", group = "Obsidian" },
      { "<leader>oo", desc = "Obsidian: Open" },
      { "<leader>oq", desc = "Obsidian: Quick switch" },
      { "<leader>of", desc = "Obsidian: Search" },
      { "<leader>on", desc = "Obsidian: New note" },
      { "<leader>ot", desc = "Obsidian: Today" },
      { "<leader>oy", desc = "Obsidian: Yesterday" },
      { "<leader>om", desc = "Obsidian: Tomorrow" },
      { "<leader>ol", desc = "Obsidian: Links" },
      { "<leader>ob", desc = "Obsidian: Backlinks" },
    })
  end,
})

-- =========================================================
-- Quality-of-life: ensure *.md is markdown
-- =========================================================
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.md",
  callback = function()
    if vim.bo.filetype == "" then vim.bo.filetype = "markdown" end
  end,
})

-- Markdown-specific QoL tweaks
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.conceallevel = 2
    vim.opt_local.spell = false
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true

    -- Link-editing leader keymaps (mkdnflow preferred; obsidian/gf fallback)
    local map = vim.keymap.set
    local bopts = { noremap = true, silent = true, buffer = true }

    -- Follow link under cursor
    map("n", "<leader>lf", function()
      if vim.fn.exists(":MkdnFollowLink") == 2 then
        vim.cmd("MkdnFollowLink")
      else
        -- fall back to normal gf (obsidian overrides gf in md buffers)
        vim.cmd("normal gf")
      end
    end, bopts)

    -- Destroy link under cursor (mkdnflow)
    map("n", "<leader>ld", function()
      if vim.fn.exists(":MkdnDestroyLink") == 2 then
        vim.cmd("MkdnDestroyLink")
      else
        vim.notify("MkdnDestroyLink not available", vim.log.levels.WARN)
      end
    end, bopts)

    -- Create link from selection (existing note)
    map({ "x", "n" }, "<leader>ll", function()
      if vim.fn.mode() == "n" then
        vim.cmd("ObsidianLink")
      else
        vim.cmd("'<,'>ObsidianLink")
      end
    end, bopts)

    -- Create link from selection (new note)
    map({ "x", "n" }, "<leader>ln", function()
      if vim.fn.mode() == "n" then
        vim.cmd("ObsidianLinkNew")
      else
        vim.cmd("'<,'>ObsidianLinkNew")
      end
    end, bopts)

    -- Alias for checkbox toggle
    map("n", "<leader>lt", function()
      local ok, util = pcall(require, "obsidian.util")
      if ok then util.toggle_checkbox() end
    end, bopts)

    -- Links: rename current note updating refs (Obsidian)
    map("n", "<leader>lr", "<cmd>ObsidianRename<cr>", bopts)
    -- Links: show backlinks and jump via picker
    map("n", "<leader>lb", "<cmd>ObsidianBacklinks<cr>", bopts)

    -- Table navigation with Tab / Shift-Tab (mkdnflow if available; else keep cmp behavior)
    local function in_table_line()
      local line = vim.api.nvim_get_current_line()
      return line:find("|", 1, true) ~= nil
    end

    map("i", "<Tab>", function()
      local ok_cmp, cmp = pcall(require, "cmp")
      if vim.fn.exists(":MkdnTableNextCell") == 2 and in_table_line() then
        vim.cmd("MkdnTableNextCell")
        return ""
      elseif ok_cmp and cmp.visible() then
        cmp.select_next_item()
        return ""
      else
        return "\t"
      end
    end, vim.tbl_extend("force", bopts, { expr = true }))

    map("i", "<S-Tab>", function()
      local ok_cmp, cmp = pcall(require, "cmp")
      if vim.fn.exists(":MkdnTablePrevCell") == 2 and in_table_line() then
        vim.cmd("MkdnTablePrevCell")
        return ""
      elseif ok_cmp and cmp.visible() then
        cmp.select_prev_item()
        return ""
      else
        return "\t"
      end
    end, vim.tbl_extend("force", bopts, { expr = true }))

    -- Table management helpers (mkdnflow)
    local function cmd_or_warn(cmd, msg)
      if vim.fn.exists(":" .. cmd) == 2 then
        vim.cmd(cmd)
      else
        vim.notify(msg .. " (" .. cmd .. ")", vim.log.levels.WARN)
      end
    end

    map(
      "n",
      "<leader>tr",
      function()
        cmd_or_warn(
          "MkdnTableNewRowBelow",
          "mkdnflow not available for new row below"
        )
      end,
      bopts
    )
    map(
      "n",
      "<leader>tR",
      function()
        cmd_or_warn(
          "MkdnTableNewRowAbove",
          "mkdnflow not available for new row above"
        )
      end,
      bopts
    )
    map(
      "n",
      "<leader>tc",
      function()
        cmd_or_warn(
          "MkdnTableNewColAfter",
          "mkdnflow not available for new col after"
        )
      end,
      bopts
    )
    map(
      "n",
      "<leader>tC",
      function()
        cmd_or_warn(
          "MkdnTableNewColBefore",
          "mkdnflow not available for new col before"
        )
      end,
      bopts
    )
    map(
      "n",
      "<leader>ta",
      function()
        cmd_or_warn("MkdnTableAlign", "mkdnflow not available for align")
      end,
      bopts
    )
    map(
      "n",
      "<leader>tf",
      function()
        cmd_or_warn("MkdnTableFormat", "mkdnflow not available for format")
      end,
      bopts
    )
  end,
})
