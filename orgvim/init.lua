-- =========================================================
-- orgvim: orgファイル運用だけに特化した最小 init.lua（完全版・安定版）
--   - vim-code-dark
--   - alpha dashboard
--   - orgmode.nvim (startup load)
--   - org-super-agenda.nvim
--   - which-key
--   - nvim-tree
--   - Org Clock commands
--   - capture(j) 保存時クラッシュ対策（末尾空行保証 + touch）
-- =========================================================

------------------------------------------------------------
-- 0) ユーザー設定（ここだけ自分用に変更）
------------------------------------------------------------
local ORG_DIR = vim.fn.expand("~/org") -- orgフォルダ
local ORG_DEFAULT_NOTES = ORG_DIR .. "/notes.org"
local ORG_TODO_FILE = ORG_DIR .. "/todo.org"
local ORG_JOURNAL_FILE = ORG_DIR .. "/journal.org"

------------------------------------------------------------
-- 1) 最小オプション
------------------------------------------------------------
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true

vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.swapfile = true
vim.opt.backup = false
vim.opt.writebackup = false

------------------------------------------------------------
-- 2) ユーティリティ（org環境を“最低限”自動で整える + 安全化）
------------------------------------------------------------
local function ensure_org_skeleton()
	if vim.fn.isdirectory(ORG_DIR) == 0 then
		vim.fn.mkdir(ORG_DIR, "p")
	end

	local function ensure_file(path, lines)
		if vim.fn.filereadable(path) == 0 then
			vim.fn.writefile(lines or {}, path)
		end
	end

	-- 新規作成時は必ず2行以上（末尾空行）
	ensure_file(ORG_TODO_FILE, { "#+TITLE: Todo", "" })
	ensure_file(ORG_JOURNAL_FILE, { "#+TITLE: Journal", "" })
	ensure_file(ORG_DEFAULT_NOTES, { "* Inbox", "" })

	-- 既に存在するファイルでも「実質空」「末尾改行なし」を救済
	local function ensure_trailing_blank_line(path, fallback_lines)
		if vim.fn.filereadable(path) == 0 then
			vim.fn.writefile(fallback_lines, path)
			return
		end

		local ok, lines = pcall(vim.fn.readfile, path)
		if not ok then
			return
		end

		local effectively_empty = (#lines == 0) or (#lines == 1 and (lines[1] == "" or lines[1] == "\r"))
		if effectively_empty then
			vim.fn.writefile(fallback_lines, path)
			return
		end

		local last = lines[#lines] or ""
		if last ~= "" then
			table.insert(lines, "")
			vim.fn.writefile(lines, path)
		end
	end

	ensure_trailing_blank_line(ORG_TODO_FILE, { "#+TITLE: Todo", "" })
	ensure_trailing_blank_line(ORG_JOURNAL_FILE, { "#+TITLE: Journal", "" })
	-- notes は headline 前提。空なら Inbox を作り、末尾空行も保証
	ensure_trailing_blank_line(ORG_DEFAULT_NOTES, { "* Inbox", "" })
end

local function cd_org()
	ensure_org_skeleton()
	vim.cmd("cd " .. vim.fn.fnameescape(ORG_DIR))
	-- notify が邪魔ならコメントアウトしてOK
	-- vim.notify("cd -> " .. ORG_DIR)
end

local function edit_file(path)
	ensure_org_skeleton()
	vim.cmd("edit " .. vim.fn.fnameescape(path))
end

-- “保存段階で落ちる”対策の保険：ターゲットを一回touchして改行確定させる
local function touch_file(path)
	ensure_org_skeleton()
	local cur = vim.api.nvim_get_current_buf()
	vim.cmd("silent keepalt keepjumps edit " .. vim.fn.fnameescape(path))
	vim.cmd("silent write")
	vim.cmd("silent bdelete")
	if vim.api.nvim_buf_is_valid(cur) then
		vim.api.nvim_set_current_buf(cur)
	end
end

------------------------------------------------------------
-- 3) lazy.nvim bootstrap
------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
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

------------------------------------------------------------
-- 4) Plugins
------------------------------------------------------------
require("lazy").setup({
	----------------------------------------------------------
	-- Theme: vim-code-dark
	----------------------------------------------------------
	{
		"tomasiser/vim-code-dark",
		lazy = false,
		priority = 1000,
		config = function()
			vim.cmd("colorscheme codedark")
		end,
	},

	----------------------------------------------------------
	-- nvim-tree（orgフォルダをルートに開く用）
	----------------------------------------------------------
	{
		"nvim-tree/nvim-tree.lua",
		lazy = false,
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("nvim-tree").setup({
				hijack_netrw = true,
				disable_netrw = true,
				view = { width = 36 },
				renderer = { group_empty = true },
				filters = { dotfiles = false },
				git = { enable = true },
			})
		end,
	},

	----------------------------------------------------------
	-- Dashboard: alpha-nvim
	----------------------------------------------------------
	{
		"goolord/alpha-nvim",
		lazy = false,
		priority = 900,
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			local alpha = require("alpha")
			local dashboard = require("alpha.themes.dashboard")

			dashboard.section.header.val = {
				"██╗  ██╗ ██████╗  ██████╗ ",
				"██║  ██║██╔═══██╗██╔════╝ ",
				"███████║██║   ██║██║  ███╗",
				"██╔══██║██║   ██║██║   ██║",
				"██║  ██║╚██████╔╝╚██████╔╝",
				"╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ",
				"        orgvim.nvim       ",
			}

			dashboard.section.buttons.val = {
				dashboard.button("o", "  cd to org folder", function()
					cd_org()
				end),
				dashboard.button("e", "󰙅  OrgTree (cd + nvim-tree)", "<cmd>OrgTree<cr>"),

				dashboard.button("t", "  open todo.org", function()
					cd_org()
					edit_file(ORG_TODO_FILE)
				end),
				dashboard.button("j", "󰃭  open journal.org", function()
					cd_org()
					edit_file(ORG_JOURNAL_FILE)
				end),
				dashboard.button("n", "  open notes.org (Inbox)", function()
					cd_org()
					edit_file(ORG_DEFAULT_NOTES)
				end),

				dashboard.button("a", "󰸗  OrgAgenda", function()
					cd_org()
					vim.cmd("Org agenda")
				end),

				-- 通常 capture
				dashboard.button("c", "  OrgCapture", function()
					cd_org()
					vim.cmd("Org capture")
				end),

				-- ★落ちやすい j を “touch + 指定capture” で安定実行
				dashboard.button("C", "  Quick Journal (safe)", function()
					cd_org()
					touch_file(ORG_JOURNAL_FILE)
					vim.cmd("Org capture j")
				end),

				dashboard.button("s", "󰕮  OrgSuperAgenda", function()
					cd_org()
					vim.cmd("OrgSuperAgenda")
				end),

				dashboard.button("i", "  Clock In", "<cmd>OrgClockIn<cr>"),
				dashboard.button("O", "  Clock Out", "<cmd>OrgClockOut<cr>"),

				dashboard.button("q", "󰩈  Quit", "<cmd>qa<cr>"),
			}

			dashboard.section.footer.val = { "ORG: " .. ORG_DIR }

			alpha.setup(dashboard.config)

			vim.api.nvim_create_autocmd("VimEnter", {
				callback = function()
					ensure_org_skeleton()
					if vim.fn.argc() == 0 then
						require("alpha").start(true)
					end
				end,
			})
		end,
	},

	----------------------------------------------------------
	-- Org mode core（Dashboardから叩きたいので起動時ロード）
	----------------------------------------------------------
	{
		"nvim-orgmode/orgmode",
		lazy = false,
		config = function()
			ensure_org_skeleton()

			require("orgmode").setup({
				org_agenda_files = { ORG_DIR .. "/**/*" },
				org_default_notes_file = ORG_DEFAULT_NOTES,
				win_split_mode = "auto",

				-- ★ Capture templates: あなたの Emacs と同じ
				org_capture_templates = {
					t = {
						description = "Todo",
						template = "* TODO %?\n  CREATED: %U\n",
						target = ORG_TODO_FILE,
						datetree = true,
					},
					n = {
						description = "Note",
						template = "* %?\n  %U\n  ",
						target = ORG_DEFAULT_NOTES,
						headline = "Inbox",
					},
					j = {
						description = "Journal",
						template = "* %<%H:%M> %?\n",
						target = ORG_JOURNAL_FILE,
						datetree = true,
					},
				},
			})

			-- orgだけ触る前提の最小キー
			vim.keymap.set("n", "<leader>oa", "<cmd>Org agenda<cr>", { desc = "Org: Agenda" })
			vim.keymap.set("n", "<leader>oc", "<cmd>Org capture<cr>", { desc = "Org: Capture" })

			-- ★jは安全側：touchしてから実行
			vim.keymap.set("n", "<leader>c", function()
				cd_org()
				touch_file(ORG_JOURNAL_FILE)
				vim.cmd("Org capture j")
			end, { desc = "Org: Quick Journal (safe)" })
		end,
	},

	----------------------------------------------------------
	-- Org Super Agenda
	----------------------------------------------------------
	{
		"hamidi-dev/org-super-agenda.nvim",
		lazy = false,
		dependencies = {
			"nvim-orgmode/orgmode",
			{ "lukas-reineke/headlines.nvim", config = true },
		},
		config = function()
			ensure_org_skeleton()

			require("org-super-agenda").setup({
				org_directories = { ORG_DIR },
				org_files = {},

				todo_states = {
					{
						name = "TODO",
						keymap = "ot",
						strike_through = false,
						fields = { "filename", "todo", "headline", "priority", "date", "tags" },
					},
					{
						name = "DONE",
						keymap = "od",
						strike_through = true,
						fields = { "filename", "todo", "headline", "priority", "date", "tags" },
					},
				},

				window = {
					width = 0.86,
					height = 0.75,
					border = "rounded",
					title = "Org Super Agenda",
					title_pos = "center",
				},

				groups = {
					{
						name = " Today",
						matcher = function(i)
							return i.scheduled and i.scheduled:is_today()
						end,
						sort = { by = "scheduled_time", order = "asc" },
					},
					{
						name = "️ Tomorrow",
						matcher = function(i)
							return i.scheduled and i.scheduled:days_from_today() == 1
						end,
						sort = { by = "scheduled_time", order = "asc" },
					},
					{
						name = "⏳ Overdue",
						matcher = function(i)
							return i.todo_state ~= "DONE"
								and ((i.deadline and i.deadline:is_past()) or (i.scheduled and i.scheduled:is_past()))
						end,
						sort = { by = "date_nearest", order = "asc" },
					},
					{
						name = " Upcoming",
						matcher = function(i)
							local days = require("org-super-agenda.config").get().upcoming_days or 10
							local d1 = i.deadline and i.deadline:days_from_today()
							local d2 = i.scheduled and i.scheduled:days_from_today()
							return (d1 and d1 >= 0 and d1 <= days) or (d2 and d2 >= 0 and d2 <= days)
						end,
						sort = { by = "date_nearest", order = "asc" },
					},
				},

				upcoming_days = 10,
				hide_empty_groups = true,
				allow_duplicates = false,
				show_other_group = false,
				show_tags = true,
				show_filename = true,
				heading_max_length = 80,
				group_sort = { by = "date_nearest", order = "asc" },
				view_mode = "classic",
			})

			vim.keymap.set("n", "<leader>os", "<cmd>OrgSuperAgenda<cr>", { desc = "Org: Super Agenda" })
			vim.keymap.set("n", "<leader>oS", "<cmd>OrgSuperAgenda!<cr>", { desc = "Org: Super Agenda (fullscreen)" })
		end,
	},

	----------------------------------------------------------
	-- Which Key
	----------------------------------------------------------
	{
		"folke/which-key.nvim",
		lazy = false,
		config = function()
			local wk = require("which-key")
			wk.setup({
				preset = "modern",
				delay = 300,
				notify = false,
				plugins = { spelling = true },
				win = { border = "rounded" },
			})

			wk.add({
				{ "<leader>o", group = "Org" },
				{ "<leader>ox", group = "Org Clock" },

				{ "<leader>oa", desc = "Org Agenda" },
				{ "<leader>oc", desc = "Org Capture" },
				{ "<leader>c", desc = "Quick Journal (safe)" },

				{ "<leader>od", desc = "cd to org folder" },
				{ "<leader>oe", desc = "OrgTree (cd + nvim-tree)" },

				{ "<leader>ot", desc = "Open todo.org" },
				{ "<leader>oj", desc = "Open journal.org" },
				{ "<leader>on", desc = "Open notes.org (Inbox)" },

				{ "<leader>oxi", desc = "Clock In" },
				{ "<leader>oxo", desc = "Clock Out" },
				{ "<leader>oxc", desc = "Clock Cancel" },
				{ "<leader>oxg", desc = "Clock Goto" },
			})
		end,
	},
}, {
	ui = { border = "rounded" },
})

------------------------------------------------------------
-- 5) orgフォルダへ移動コマンド（どこからでも）
------------------------------------------------------------
vim.api.nvim_create_user_command("OrgCd", function()
	cd_org()
end, {})

vim.api.nvim_create_user_command("OrgTodo", function()
	cd_org()
	edit_file(ORG_TODO_FILE)
end, {})

vim.api.nvim_create_user_command("OrgJournal", function()
	cd_org()
	edit_file(ORG_JOURNAL_FILE)
end, {})

vim.api.nvim_create_user_command("OrgNotes", function()
	cd_org()
	edit_file(ORG_DEFAULT_NOTES)
end, {})

vim.api.nvim_create_user_command("OrgTree", function()
	cd_org()
	vim.cmd("NvimTreeOpen")
	vim.cmd("NvimTreeFocus")
end, {})

------------------------------------------------------------
-- 6) Org Clock コマンド（Emacsの org-clock-in/out 風）
------------------------------------------------------------
local function org_clock()
	local ok, orgmode = pcall(require, "orgmode")
	if not ok or not orgmode.clock then
		vim.notify("orgmode clock is not available", vim.log.levels.ERROR)
		return nil
	end
	return orgmode.clock
end

vim.api.nvim_create_user_command("OrgClockIn", function()
	local c = org_clock()
	if c then
		c:org_clock_in()
	end
end, {})

vim.api.nvim_create_user_command("OrgClockOut", function()
	local c = org_clock()
	if c then
		c:org_clock_out()
	end
end, {})

vim.api.nvim_create_user_command("OrgClockCancel", function()
	local c = org_clock()
	if c then
		c:org_clock_cancel()
	end
end, {})

vim.api.nvim_create_user_command("OrgClockGoto", function()
	local c = org_clock()
	if c then
		c:org_clock_goto()
	end
end, {})

------------------------------------------------------------
-- 7) キーマップ（org専用）
------------------------------------------------------------
vim.keymap.set("n", "<leader>od", "<cmd>OrgCd<cr>", { desc = "Org: cd to org folder" })
vim.keymap.set("n", "<leader>oe", "<cmd>OrgTree<cr>", { desc = "Org: Tree (cd + nvim-tree)" })

vim.keymap.set("n", "<leader>ot", "<cmd>OrgTodo<cr>", { desc = "Org: open todo.org" })
vim.keymap.set("n", "<leader>oj", "<cmd>OrgJournal<cr>", { desc = "Org: open journal.org" })
vim.keymap.set("n", "<leader>on", "<cmd>OrgNotes<cr>", { desc = "Org: open notes.org" })

vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "NvimTree Toggle" })

vim.keymap.set("n", "<leader>oxi", "<cmd>OrgClockIn<cr>", { desc = "Org: Clock In" })
vim.keymap.set("n", "<leader>oxo", "<cmd>OrgClockOut<cr>", { desc = "Org: Clock Out" })
vim.keymap.set("n", "<leader>oxc", "<cmd>OrgClockCancel<cr>", { desc = "Org: Clock Cancel" })
vim.keymap.set("n", "<leader>oxg", "<cmd>OrgClockGoto<cr>", { desc = "Org: Clock Goto" })
