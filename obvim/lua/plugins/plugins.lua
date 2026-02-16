return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      delay = 200,
    },
  },

  -- icons (neo-tree uses it; harmless otherwise)
  { "nvim-tree/nvim-web-devicons", lazy = true },

  -- neo-tree: file explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      close_if_last_window = true,
      popup_border_style = "rounded",
      filesystem = {
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
      },
      window = {
        width = 34,
        mappings = {
          ["<space>"] = "none", -- neo-tree内でspaceを潰したくない場合
        },
      },
    },
  },

  -- treesitter (render-markdown needs it)

  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("nvim-treesitter").setup({
        highlight = { enable = true },
        ensure_installed = { "lua", "markdown", "markdown_inline" },
      })
    end,
  },

  -- nvim-cmp: completion engine + sources
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
    },
    config = function()
      local ok, cmp = pcall(require, "cmp")
      if not ok then return end
      -- helper to decide when to trigger completion with <Tab>
      local has_words_before = function()
        local line, col = unpack(vim.api.nvim_win_get_cursor(0))
        if col == 0 then return false end
        local text =
          vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]
        return text:match("%S") ~= nil
      end

      cmp.setup({
        completion = { completeopt = "menu,menuone,noselect" },
        snippet = { expand = function(_) end },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<C-j>"] = cmp.mapping.select_next_item(),
          ["<C-k>"] = cmp.mapping.select_prev_item(),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif has_words_before() then
              cmp.complete()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "path" },
          { name = "buffer" },
          -- obsidian.nvim registers a source named "obsidian" when enabled below
          { name = "obsidian" },
        }),

        -- enable in markdown as well
        ---@diagnostic disable-next-line: redundant-parameter
        cmp.setup.filetype("markdown", {
          sources = cmp.config.sources({
            { name = "obsidian" },
            { name = "nvim_lsp" },
            { name = "path" },
            { name = "buffer" },
          }),
        }),
      })
    end,
  },

  -- LSP config for Markdown (markdown-oxide if available; fallback to marksman)
  {
    "neovim/nvim-lspconfig",
    config = function()
      local ok, lspconfig = pcall(require, "lspconfig")
      if not ok then return end
      local util = require("lspconfig.util")
      local cmp_ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      if cmp_ok then
        capabilities = cmp_lsp.default_capabilities(capabilities)
      end

      -- define a custom config for markdown-oxide if not present
      local configs = require("lspconfig.configs")
      if not configs.markdown_oxide then
        configs.markdown_oxide = {
          default_config = {
            cmd = { vim.env.MARKDOWN_OXIDE_CMD or "markdown-oxide" },
            filetypes = { "markdown" },
            root_dir = function(fname)
              return util.root_pattern(".obsidian", ".git")(fname)
                or util.path.dirname(fname)
            end,
            single_file_support = true,
          },
        }
      end

      local use_oxide = (
        vim.env.MARKDOWN_OXIDE_CMD and #vim.env.MARKDOWN_OXIDE_CMD > 0
      ) or (vim.fn.executable("markdown-oxide") == 1)

      if use_oxide then
        lspconfig.markdown_oxide.setup({ capabilities = capabilities })
      elseif vim.fn.executable("marksman") == 1 then
        lspconfig.marksman.setup({ capabilities = capabilities })
      end
    end,
  },

  -- mkdnflow: extra Markdown link/navigation helpers (minimal, no default mappings)
  {
    "jakewvincent/mkdnflow.nvim",
    ft = { "markdown" },
    opts = {
      modules = { bib = false, folds = false, cmp = true },
      links = { transform_explicit = false },
      -- keep your existing keymaps (obsidian) and add just completion/textobjs
      mappings = { MkdnEnter = false, MkdnTab = false },
    },
  },

  -- render-markdown: improves markdown rendering in-buffer
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      -- “見やすさ”寄りの無難設定（必要なら後で好みに調整）
      heading = { enabled = true },
      code = { enabled = true },
      bullet = { enabled = true },
      checkbox = { enabled = true },
      quote = { enabled = true },
      pipe_table = { enabled = true },
      link = { enabled = true },
    },
  },

  -- obsidian.nvim
  {
    "epwalsh/obsidian.nvim",
    version = "*",
    -- ft だけにすると「読み込まれない」体験になりがちなので event で確実に読む
    lazy = false,
    -- event = { "BufReadPre *.md", "BufNewFile *.md" },
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function(_, opts)
      local vault_parent_path = "C:/Users/kawasaki/obsidian"
      require("obsidian").setup({

        -- A list of workspace names, paths, and configuration overrides.
        -- If you use the Obsidian app, the 'path' of a workspace should generally be
        -- your vault root (where the `.obsidian` folder is located).
        -- When obsidian.nvim is loaded by your plugin manager, it will automatically set
        -- the workspace to the first workspace in the list whose `path` is a parent of the
        -- current markdown file being edited.
        --
        open = {
          -- WSL上からWindowsの既定ハンドラで obsidian:// を開く
          cmd = { "cmd.exe", "/c", "start", "" },
        },
        workspaces = {
          {
            name = "2026_master",
            path = vault_parent_path .. "/2026_master",
          },
          --[[
					{
						name = "no-vault",
						path = function()
							-- alternatively use the CWD:
							-- return assert(vim.fn.getcwd())
							return assert(vim.fs.dirname(vim.api.nvim_buf_get_name(0)))
						end,
						overrides = {
							notes_subdir = vim.NIL, -- have to use 'vim.NIL' instead of 'nil'
							new_notes_location = "current_dir",
							templates = {
								folder = vim.NIL,
							},
							disable_frontmatter = true,
						},
					},
            -- ]]
        },

        -- Alternatively - and for backwards compatibility - you can set 'dir' to a single path instead of
        -- 'workspaces'. For example:
        -- dir = "~/vaults/work",

        -- Optional, if you keep notes in a specific subdirectory of your vault.
        notes_subdir = "Inbox",

        -- Optional, set the log level for obsidian.nvim. This is an integer corresponding to one of the log
        -- levels defined by "vim.log.levels.*".
        log_level = vim.log.levels.INFO,

        -- Optional, for templates (see below).
        templates = {
          folder = "Templates",
          date_format = "%Y-%m-%d",
          time_format = "%H:%M",
          -- A map for custom variables, the key should be the variable and the value a function
          substitutions = {},
        },

        daily_notes = {
          -- Optional, if you keep daily notes in a separate directory.
          folder = "Daily",
          -- Optional, if you want to change the date format for the ID of daily notes.
          date_format = "%Y-%m-%d",
          -- Optional, if you want to change the date format of the default alias of daily notes.
          alias_format = "%B %-d, %Y",
          -- Optional, default tags to add to each new daily note created.
          default_tags = { "date", "tags", "comment" },
          -- Optional, if you want to automatically insert a template from your template directory like 'daily.md'
          template = vault_parent_path
            .. "/2026_master/Templates/template_normal.md",
        },

        -- Optional, completion of wiki links, local markdown links, and tags using nvim-cmp.
        completion = {
          nvim_cmp = true, -- enable obsidian.nvim completion source for nvim-cmp
          min_chars = 2,
        },

        -- Optional, configure key mappings. These are the defaults. If you don't want to set any keymappings this
        -- way then set 'mappings = {}'.
        mappings = {
          -- Overrides the 'gf' mapping to work on markdown/wiki links within your vault.
          ["gf"] = {
            action = function()
              return require("obsidian").util.gf_passthrough()
            end,
            opts = { noremap = false, expr = true, buffer = true },
          },
          -- Toggle check-boxes.
          ["<leader>ch"] = {
            action = function()
              return require("obsidian").util.toggle_checkbox()
            end,
            opts = { buffer = true },
          },
          -- Smart action depending on context, either follow link or toggle checkbox.
          ["<cr>"] = {
            action = function() return require("obsidian").util.smart_action() end,
            opts = { buffer = true, expr = true },
          },
        },

        -- Where to put new notes. Valid options are
        --  * "current_dir" - put new notes in same directory as the current buffer.
        --  * "notes_subdir" - put new notes in the default notes subdirectory.
        new_notes_location = "current_dir",

        --[[
				-- Optional, customize how note IDs are generated given an optional title.
				---@param title string|?
				---@return string
				note_id_func = function(title)
					-- Create note IDs in a Zettelkasten format with a timestamp and a suffix.
					-- In this case a note with the title 'My new note' will be given an ID that looks
					-- like '1657296016-my-new-note', and therefore the file name '1657296016-my-new-note.md'
					local suffix = ""
					if title ~= nil then
						-- If title is given, transform it into valid file name.
						suffix = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
					else
						-- If title is nil, just add 4 random uppercase letters to the suffix.
						for _ = 1, 4 do
							suffix = suffix .. string.char(math.random(65, 90))
						end
					end
					return tostring(os.time()) .. "-" .. suffix
				end,
				--]]

        -- Optional, customize how note file names are generated given the ID, target directory, and title.
        ---@param spec { id: string, dir: obsidian.Path, title: string|? }
        ---@return string|obsidian.Path The full path to the new note.
        note_path_func = function(spec)
          -- This is equivalent to the default behavior.
          -- local path = spec.dir / tostring(spec.id)
          local path = spec.dir / tostring(spec.title)
          return path:with_suffix(".md")
        end,

        -- Optional, customize how wiki links are formatted. You can set this to one of:
        --  * "use_alias_only", e.g. '[[Foo Bar]]'
        --  * "prepend_note_id", e.g. '[[foo-bar|Foo Bar]]'
        --  * "prepend_note_path", e.g. '[[foo-bar.md|Foo Bar]]'
        --  * "use_path_only", e.g. '[[foo-bar.md]]'
        -- Or you can set it to a function that takes a table of options and returns a string, like this:
        wiki_link_func = function(opts)
          return require("obsidian.util").wiki_link_id_prefix(opts)
        end,

        -- Optional, customize how markdown links are formatted.
        markdown_link_func = function(opts)
          return require("obsidian.util").markdown_link(opts)
        end,

        -- Either 'wiki' or 'markdown'.
        preferred_link_style = "markdown",

        -- Optional, boolean or a function that takes a filename and returns a boolean.
        -- `true` indicates that you don't want obsidian.nvim to manage frontmatter.
        disable_frontmatter = true,

        -- Optional, alternatively you can customize the frontmatter data.
        ---@return table
        note_frontmatter_func = function(note)
          -- Add the title of the note as an alias.
          if note.title then note:add_alias(note.title) end

          local out =
            { id = note.id, aliases = note.aliases, tags = note.tags }

          -- `note.metadata` contains any manually added fields in the frontmatter.
          -- So here we just make sure those fields are kept in the frontmatter.
          if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
            for k, v in pairs(note.metadata) do
              out[k] = v
            end
          end

          return out
        end,

        -- Optional, by default when you use `:ObsidianFollowLink` on a link to an external
        -- URL it will be ignored but you can customize this behavior here.
        ---@param url string
        follow_url_func = function(url)
          -- Open the URL in the default web browser.
          --vim.fn.jobstart({ "open", url }) -- Mac OS
          vim.fn.jobstart({ "xdg-open", url }) -- linux
          -- vim.cmd(':silent exec "!start ' .. url .. '"') -- Windows
          -- vim.ui.open(url) -- need Neovim 0.10.0+
        end,

        -- Optional, by default when you use `:ObsidianFollowLink` on a link to an image
        -- file it will be ignored but you can customize this behavior here.
        ---@param img string
        follow_img_func = function(img)
          -- vim.fn.jobstart({ "qlmanage", "-p", img }) -- Mac OS quick look preview
          vim.fn.jobstart({ "xdg-open", url }) -- linux
          -- vim.cmd(':silent exec "!start ' .. url .. '"') -- Windows
        end,

        -- Optional, set to true if you use the Obsidian Advanced URI plugin.
        -- https://github.com/Vinzent03/obsidian-advanced-uri
        use_advanced_uri = false,

        -- Optional, set to true to force ':ObsidianOpen' to bring the app to the foreground.
        open_app_foreground = false,

        picker = {
          -- Set your preferred picker. Can be one of 'telescope.nvim', 'fzf-lua', or 'mini.pick'.
          name = "telescope.nvim",
          -- Optional, configure key mappings for the picker. These are the defaults.
          -- Not all pickers support all mappings.
          note_mappings = {
            -- Create a new note from your query.
            new = "<C-x>",
            -- Insert a link to the selected note.
            insert_link = "<C-l>",
          },
          tag_mappings = {
            -- Add tag(s) to current note.
            tag_note = "<C-x>",
            -- Insert a tag at the current location.
            insert_tag = "<C-l>",
          },
        },

        -- Optional, sort search results by "path", "modified", "accessed", or "created".
        -- The recommend value is "modified" and `true` for `sort_reversed`, which means, for example,
        -- that `:ObsidianQuickSwitch` will show the notes sorted by latest modified time
        sort_by = "modified",
        sort_reversed = true,

        -- Set the maximum number of lines to read from notes on disk when performing certain searches.
        search_max_lines = 1000,

        -- Optional, determines how certain commands open notes. The valid options are:
        -- 1. "current" (the default) - to always open in the current window
        -- 2. "vsplit" - to open in a vertical split if there's not already a vertical split
        -- 3. "hsplit" - to open in a horizontal split if there's not already a horizontal split
        open_notes_in = "current",

        -- Optional, define your own callbacks to further customize behavior.
        callbacks = {
          -- Runs at the end of `require("obsidian").setup()`.
          ---@param client obsidian.Client
          post_setup = function(client) end,

          -- Runs anytime you enter the buffer for a note.
          ---@param client obsidian.Client
          ---@param note obsidian.Note
          enter_note = function(client, note) end,

          -- Runs anytime you leave the buffer for a note.
          ---@param client obsidian.Client
          ---@param note obsidian.Note
          leave_note = function(client, note) end,

          -- Runs right before writing the buffer for a note.
          ---@param client obsidian.Client
          ---@param note obsidian.Note
          pre_write_note = function(client, note) end,

          -- Runs anytime the workspace is set/changed.
          ---@param client obsidian.Client
          ---@param workspace obsidian.Workspace
          post_set_workspace = function(client, workspace) end,
        },

        -- Optional, configure additional syntax highlighting / extmarks.
        -- This requires you have `conceallevel` set to 1 or 2. See `:help conceallevel` for more details.
        ui = {
          enable = true, -- set to false to disable all additional syntax features
          update_debounce = 200, -- update delay after a text change (in milliseconds)
          max_file_length = 5000, -- disable UI features for files with more than this many lines
          -- Define how various check-boxes are displayed
          checkboxes = {
            -- NOTE: the 'char' value has to be a single character, and the highlight groups are defined below.
            [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
            ["x"] = { char = "", hl_group = "ObsidianDone" },
            [">"] = { char = "", hl_group = "ObsidianRightArrow" },
            ["~"] = { char = "󰰱", hl_group = "ObsidianTilde" },
            ["!"] = { char = "", hl_group = "ObsidianImportant" },
            -- Replace the above with this if you don't have a patched font:
            -- [" "] = { char = "☐", hl_group = "ObsidianTodo" },
            -- ["x"] = { char = "✔", hl_group = "ObsidianDone" },

            -- You can also add more custom ones...
          },
          -- Use bullet marks for non-checkbox lists.
          bullets = { char = "•", hl_group = "ObsidianBullet" },
          external_link_icon = {
            char = "",
            hl_group = "ObsidianExtLinkIcon",
          },
          -- Replace the above with this if you don't have a patched font:
          -- external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
          reference_text = { hl_group = "ObsidianRefText" },
          highlight_text = { hl_group = "ObsidianHighlightText" },
          tags = { hl_group = "ObsidianTag" },
          block_ids = { hl_group = "ObsidianBlockID" },
          hl_groups = {
            -- The options are passed directly to `vim.api.nvim_set_hl()`. See `:help nvim_set_hl`.
            ObsidianTodo = { bold = true, fg = "#f78c6c" },
            ObsidianDone = { bold = true, fg = "#89ddff" },
            ObsidianRightArrow = { bold = true, fg = "#f78c6c" },
            ObsidianTilde = { bold = true, fg = "#ff5370" },
            ObsidianImportant = { bold = true, fg = "#d73128" },
            ObsidianBullet = { bold = true, fg = "#89ddff" },
            ObsidianRefText = { underline = true, fg = "#c792ea" },
            ObsidianExtLinkIcon = { fg = "#c792ea" },
            ObsidianTag = { italic = true, fg = "#89ddff" },
            ObsidianBlockID = { italic = true, fg = "#89ddff" },
            ObsidianHighlightText = { bg = "#75662e" },
          },
        },

        -- Specify how to handle attachments.
        attachments = {
          -- The default folder to place images in via `:ObsidianPasteImg`.
          -- If this is a relative path it will be interpreted as relative to the vault root.
          -- You can always override this per image by passing a full path to the command instead of just a filename.
          img_folder = "assets/imgs", -- This is the default

          -- Optional, customize the default name or prefix when pasting images via `:ObsidianPasteImg`.
          ---@return string
          img_name_func = function()
            -- Prefix image names with timestamp.
            return string.format("%s-", os.time())
          end,

          -- A function that determines the text to insert in the note when pasting an image.
          -- It takes two arguments, the `obsidian.Client` and an `obsidian.Path` to the image file.
          -- This is the default implementation.
          ---@param client obsidian.Client
          ---@param path obsidian.Path the absolute path to the image file
          ---@return string
          img_text_func = function(client, path)
            path = client:vault_relative_path(path) or path
            return string.format("![%s](%s)", path.name, path)
          end,
        },

        -- see below for configuration
      })
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    version = "*",
    dependencies = {
      "nvim-lua/plenary.nvim",
      -- optional but recommended
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
  },
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          pick = function(cmd, opts) return LazyVim.pick(cmd, opts)() end,
          header = [[
 ██████╗ ██████╗ ███████╗██╗██████╗ ██╗ █████╗ ███╗   ██╗
██╔═══██╗██╔══██╗██╔════╝██║██╔══██╗██║██╔══██╗████╗  ██║
██║   ██║██████╔╝███████╗██║██║  ██║██║███████║██╔██╗ ██║
██║   ██║██╔══██╗╚════██║██║██║  ██║██║██╔══██║██║╚██╗██║
╚██████╔╝██████╔╝███████║██║██████╔╝██║██║  ██║██║ ╚████║
 ╚═════╝ ╚═════╝ ╚══════╝╚═╝╚═════╝ ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
            ]],
          -- stylua: ignore
          ---@type snacks.dashboard.Item[]
          keys = {
            { icon = " ", key = "o", desc = "Obsidian: Open", action = ":ObsidianOpen" },
            { icon = "󰱼 ", key = "q", desc = "Obsidian: Quick Switch", action = ":ObsidianQuickSwitch" },
            { icon = " ", key = "f", desc = "Obsidian: Search", action = ":ObsidianSearch" },
            { icon = " ", key = "n", desc = "Obsidian: New Note", action = ":ObsidianNew" },
            { icon = " ", key = "t", desc = "Obsidian: Today", action = ":ObsidianToday" },
            { icon = "󰃭 ", key = "y", desc = "Obsidian: Yesterday", action = ":ObsidianYesterday" },
            { icon = "󰃰 ", key = "m", desc = "Obsidian: Tomorrow", action = ":ObsidianTomorrow" },
          },
        },
      },
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function() vim.cmd.colorscheme("catppuccin") end,
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          icons_enabled = true,
          theme = "horizon",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          disabled_filetypes = {
            statusline = {},
            winbar = {},
          },
          ignore_focus = {},
          always_divide_middle = true,
          always_show_tabline = true,
          globalstatus = false,
          refresh = {
            statusline = 1000,
            tabline = 1000,
            winbar = 1000,
            refresh_time = 16, -- ~60fps
            events = {
              "WinEnter",
              "BufEnter",
              "BufWritePost",
              "SessionLoadPost",
              "FileChangedShellPost",
              "VimResized",
              "Filetype",
              "CursorMoved",
              "CursorMovedI",
              "ModeChanged",
            },
          },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "hostname", "tabs" },
          lualine_c = { "filename" },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "windows" },
          lualine_z = { "location" },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { "filename" },
          lualine_x = { "location" },
          lualine_y = {},
          lualine_z = {},
        },
        tabline = {},
        winbar = {},
        inactive_winbar = {},
        extensions = {},
      })
    end,
  },
}
