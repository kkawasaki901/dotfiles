-- =========================================
-- Minimal Full Config (SJIS + Search + Tags + Harpoon + Dashboard + Session)
-- =========================================

vim.g.mapleader = " "

-- =========================================
-- SJIS 優先読込
-- =========================================
vim.opt.fileencodings = { "cp932", "sjis", "utf-8", "euc-jp", "latin1" }
vim.opt.tags = { "./tags;", "tags;" }

vim.opt.number = true
vim.opt.termguicolors = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"

-- =========================================
-- lazy.nvim bootstrap
-- =========================================
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

-- =========================================
-- Plugins
-- =========================================
require("lazy").setup({

	{ "tomasiser/vim-code-dark" },

	{ "preservim/nerdtree" },

	{
		"nvim-tree/nvim-tree.lua",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("nvim-tree").setup({})
		end,
	},

	-- Telescope (file/dir/grep)
	{
		"nvim-telescope/telescope.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("telescope").setup({
				defaults = {
					vimgrep_arguments = {
						"rg",
						"--color=never",
						"--no-heading",
						"--with-filename",
						"--line-number",
						"--column",
						"--smart-case",
						"--hidden",
						"--glob",
						"!.git/*",
						"--encoding",
						"Shift_JIS",
					},
				},
			})
		end,
	},

	-- Tag viewer (ctags required)
	{ "preservim/tagbar" },

	-- Harpoon
	{
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("harpoon"):setup()
		end,
	},

	-- which-key
	{
		"folke/which-key.nvim",
		config = function()
			require("which-key").setup({})
		end,
	},

	-- alpha dashboard
	{
		"goolord/alpha-nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			local alpha = require("alpha")
			local dashboard = require("alpha.themes.dashboard")

			dashboard.section.header.val = {
				"███╗   ██╗██╗   ██╗██╗███╗   ███╗",
				"████╗  ██║██║   ██║██║████╗ ████║",
				"██╔██╗ ██║██║   ██║██║██╔████╔██║",
				"██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║",
				"██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║",
				"╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝",
			}

			dashboard.section.buttons.val = {
				dashboard.button("f", "  Find file", ":Telescope find_files<CR>"),
				dashboard.button("g", "  Live grep", ":Telescope live_grep<CR>"),
				dashboard.button("s", "  Restore session", ":SessionManager load_session<CR>"),
				dashboard.button("q", "  Quit", ":qa<CR>"),
			}

			alpha.setup(dashboard.opts)
		end,
	},

	-- session manager
	{
		"Shatur/neovim-session-manager",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("session_manager").setup({
				autoload_mode = require("session_manager.config").AutoloadMode.CurrentDir,
			})
		end,
	},
})

vim.cmd.colorscheme("codedark")

-- =========================================
-- Keymaps
-- =========================================
local wk = require("which-key")

wk.register({
	e = { ":NvimTreeToggle<CR>", "nvim-tree" },
	n = { ":NERDTreeToggle<CR>", "NERDTree" },

	f = {
		name = "Find",
		f = { ":Telescope find_files<CR>", "Files" },
		g = { ":Telescope live_grep<CR>", "Grep SJIS" },
		d = {
			function()
				require("telescope.builtin").find_files({ find_command = { "fd", "--type", "d" } })
			end,
			"Directories",
		},
	},

	t = { ":TagbarToggle<CR>", "Tagbar" },

	h = {
		name = "Harpoon",
		a = {
			function()
				require("harpoon"):list():add()
			end,
			"Add file",
		},
		h = {
			function()
				require("harpoon").ui:toggle_quick_menu(require("harpoon"):list())
			end,
			"Menu",
		},
		["1"] = {
			function()
				require("harpoon"):list():select(1)
			end,
			"File 1",
		},
		["2"] = {
			function()
				require("harpoon"):list():select(2)
			end,
			"File 2",
		},
		["3"] = {
			function()
				require("harpoon"):list():select(3)
			end,
			"File 3",
		},
		["4"] = {
			function()
				require("harpoon"):list():select(4)
			end,
			"File 4",
		},
	},

	s = {
		name = "Session",
		s = { ":SessionManager save_current_session<CR>", "Save" },
		l = { ":SessionManager load_session<CR>", "Load" },
		d = { ":SessionManager delete_session<CR>", "Delete" },
	},
}, { prefix = "<leader>" })
