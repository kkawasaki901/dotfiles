-- TodoTxt: Minimal todo.txt manager for Neovim (paste-and-go)
-- Floating window UI, default sort: priority_then_due
-- No external deps. Configure via TodoTxt.setup({ path = "/path/to/todo.txt" })

local TodoTxt = {}

-- =====================
-- Config and State
-- =====================
local cfg = {
  path = nil,                -- if nil, defaults to ~/todo.txt
  float = true,              -- floating window
  show_done = false,         -- show completed tasks at bottom
  default_sort = "priority_then_due",
  auto_created = true,       -- set date_created on add
  clear_pri_on_done = true,  -- clear priority when completing
  assign_id = true,          -- assign id: on add if missing
  recurrence_base = 'done',  -- 'due' (advance from current due) or 'done' (from completion date)
  archive_path = nil,        -- if nil, defaults to sibling 'archive.txt'
  open_on_start = false,     -- open todo file on clean start
}

local state = {
  bufnr = nil,
  winid = nil,
  records = {},         -- parsed records
  lines = {},           -- raw file lines
  map = {},             -- list row -> record index
  sort_mode = cfg.default_sort,
  filter = { tokens = {} },
  cwd_path = nil,       -- resolved cfg.path
  id_counter = 0,
}

-- =====================
-- Utilities
-- =====================
local function pad(n, w) return string.rep("0", w - tostring(n):len()) .. tostring(n) end

local function today()
  local t = os.date("*t")
  return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
end

local function is_date(s)
  if type(s) ~= "string" then return false end
  local y, m, d = s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if not y then return false end
  y, m, d = tonumber(y), tonumber(m), tonumber(d)
  if not (y and m and d) then return false end
  if m < 1 or m > 12 then return false end
  if d < 1 or d > 31 then return false end
  return true
end

local function parse_iso_date(s)
  if not is_date(s) then return nil end
  local y, m, d = s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  return { year = tonumber(y), month = tonumber(m), day = tonumber(d) }
end

local function date_to_ts(tbl)
  return os.time({ year = tbl.year, month = tbl.month, day = tbl.day, hour = 12 })
end

local function ts_to_date(ts)
  local t = os.date("*t", ts)
  return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
end

local function add_days(date_str, n)
  local dt = parse_iso_date(date_str)
  if not dt then return date_str end
  return ts_to_date(date_to_ts(dt) + (n * 86400))
end

local function add_period(date_str, rule)
  -- rule like +1d, +2w, +3m
  local sign, num, unit = rule:match("^([+%-])(%d+)([dwm])$")
  if not sign then return date_str end
  num = tonumber(num)
  if sign == '-' then num = -num end
  if unit == 'd' then
    return add_days(date_str, num)
  elseif unit == 'w' then
    return add_days(date_str, num * 7)
  elseif unit == 'm' then
    local dt = parse_iso_date(date_str)
    if not dt then return date_str end
    local y = dt.year
    local m = dt.month + num
    local d = dt.day
    while m > 12 do y = y + 1; m = m - 12 end
    while m < 1 do y = y - 1; m = m + 12 end
    return string.format("%04d-%02d-%02d", y, m, d)
  end
  return date_str
end

local function split_ws(s)
  local t = {}
  for token in string.gmatch(s, "%S+") do table.insert(t, token) end
  return t
end

-- Extract a token under cursor from current buffer line (non-space delimited)
local function token_under_cursor()
  local pos = vim.api.nvim_win_get_cursor(0)
  local col0 = pos[2] -- 0-based
  local line = vim.api.nvim_get_current_line()
  local len = #line
  local i = col0 + 1 -- 1-based
  if len == 0 then return '' end
  if i < 1 then i = 1 end
  if i > len then i = len end
  local s = i
  local e = i
  while s > 1 and not line:sub(s - 1, s - 1):match('%s') do s = s - 1 end
  while e <= len and not line:sub(e, e):match('%s') do e = e + 1 end
  local tok = line:sub(s, e - 1)
  -- trim leading punctuation except leading + or @ (project/context), and trailing non-word
  tok = tok:gsub('^([^%w@+]+)', '')
  tok = tok:gsub('([^%w]+)$', '')
  -- Fallback to <cword> if still empty
  if tok == '' then tok = vim.fn.expand('<cword>') end
  return tok or ''
end

-- Normalize tokens extracted from either todo file or list UI into filter tokens
local function normalize_filter_token(tok)
  if not tok or tok == '' then return '' end
  -- priority like (A) => pri:A
  local p = tok:match("^%((%u)%)$")
  if p then return 'pri:' .. p end
  -- done marker 'x' from list UI => done:true
  if tok == 'x' then return 'done:true' end
  -- due and t dates => equality filters
  local d = tok:match('^due:(%d%d%d%d%-%d%d%-%d%d)$')
  if d then return 'due:=' .. d end
  local t = tok:match('^t:(%d%d%d%d%-%d%d%-%d%d)$')
  if t then return 't:=' .. t end
  -- +project / @context pass-through
  if tok:sub(1,1) == '+' or tok:sub(1,1) == '@' then return tok end
  -- key:value pass-through
  if tok:match('^[^%s:]+:.+$') then return tok end
  -- otherwise plain text token
  return tok
end

local function shallow_copy(t)
  local r = {}
  for k, v in pairs(t) do r[k] = v end
  return r
end

local function deep_copy(v)
  if type(v) ~= 'table' then return v end
  local r = {}
  for k, val in pairs(v) do r[k] = deep_copy(val) end
  return r
end

-- Safe wrapper for input prompts (avoids leading '(' statements)
local function ui_input(opts, cb)
  if vim.ui and vim.ui.input then
    return vim.ui.input(opts, cb)
  else
    return cb(vim.fn.input(opts.prompt or '', opts.default))
  end
end

-- =====================
-- Parsing and Formatting
-- =====================
local function parse_line(line, idx)
  local rec = {
    src_line = idx,
    done = false,
    pri = nil,
    date_done = nil,
    date_created = nil,
    text = "",
    projects = {},
    contexts = {},
    kv = {},
    raw = line,
  }
  local tokens = split_ws(line)
  local i = 1
  if tokens[i] == 'x' then
    rec.done = true
    i = i + 1
    if tokens[i] and is_date(tokens[i]) then rec.date_done = tokens[i]; i = i + 1 end
    if tokens[i] and is_date(tokens[i]) then rec.date_created = tokens[i]; i = i + 1 end
  else
    -- priority like (A)
    if tokens[i] and tokens[i]:match("^%([A-Z]%)$") then
      rec.pri = tokens[i]:sub(2, 2)
      i = i + 1
    end
    if tokens[i] and is_date(tokens[i]) then rec.date_created = tokens[i]; i = i + 1 end
  end
  local text_parts = {}
  while tokens[i] do
    local tk = tokens[i]
    if tk:sub(1, 1) == '+' and #tk > 1 then
      table.insert(rec.projects, tk:sub(2))
    elseif tk:sub(1, 1) == '@' and #tk > 1 then
      table.insert(rec.contexts, tk:sub(2))
    elseif tk:find('://') then
      table.insert(text_parts, tk)
    else
      local k, v = tk:match("^([^%s:]+):(.+)$")
      if k and v then
        -- normalize known keys
        if not rec.kv[k] then rec.kv[k] = {} end
        table.insert(rec.kv[k], v)
      else
        table.insert(text_parts, tk)
      end
    end
    i = i + 1
  end
  rec.text = table.concat(text_parts, ' ')
  return rec
end

local function sort_list(t)
  table.sort(t)
  return t
end

local function kv_pairs_in_order(kv)
  local keys = {}
  for k, _ in pairs(kv) do table.insert(keys, k) end
  local priority = { due = 1, t = 2, rec = 3, id = 4 }
  table.sort(keys, function(a, b)
    local pa = priority[a] or 100
    local pb = priority[b] or 100
    if pa ~= pb then return pa < pb end
    return a < b
  end)
  local pairs_seq = {}
  for _, k in ipairs(keys) do
    for _, v in ipairs(kv[k]) do table.insert(pairs_seq, { k, v }) end
  end
  return pairs_seq
end

local function fmt_line(rec)
  local parts = {}
  if rec.done then
    table.insert(parts, 'x')
    if rec.date_done then table.insert(parts, rec.date_done) end
    if rec.date_created then table.insert(parts, rec.date_created) end
  else
    if rec.pri then table.insert(parts, string.format("(%s)", rec.pri)) end
    if rec.date_created then table.insert(parts, rec.date_created) end
  end
  if rec.text and #rec.text > 0 then table.insert(parts, rec.text) end
  if rec.projects and #rec.projects > 0 then
    local ps = { unpack(rec.projects) }
    table.sort(ps)
    for _, p in ipairs(ps) do table.insert(parts, "+" .. p) end
  end
  if rec.contexts and #rec.contexts > 0 then
    local cs = { unpack(rec.contexts) }
    table.sort(cs)
    for _, c in ipairs(cs) do table.insert(parts, "@" .. c) end
  end
  if rec.kv then
    for _, kvp in ipairs(kv_pairs_in_order(rec.kv)) do
      table.insert(parts, kvp[1] .. ":" .. kvp[2])
    end
  end
  return table.concat(parts, ' ')
end

-- =====================
-- File I/O
-- =====================
local function ensure_path()
  if not cfg.path or cfg.path == '' then
    local ok, expanded = pcall(function() return vim.fn.expand('~/todo.txt') end)
    cfg.path = (ok and expanded and #expanded > 0) and expanded or 'todo.txt'
  end
  state.cwd_path = cfg.path
  -- ensure file exists
  local f = io.open(state.cwd_path, 'r')
  if not f then
    local nf, err = io.open(state.cwd_path, 'w')
    if nf then nf:close() else vim.notify('TodoTxt: cannot create file: ' .. tostring(err), vim.log.levels.ERROR); return false end
  else
    f:close()
  end
  return true
end

local function read_lines(path)
  local out = {}
  local f = io.open(path, 'r')
  if not f then return out end
  for line in f:lines() do table.insert(out, line) end
  f:close()
  return out
end

local function write_lines(path, lines)
  local f, err = io.open(path, 'w')
  if not f then return false, err end
  for _, l in ipairs(lines) do f:write(l .. "\n") end
  f:close()
  return true
end

local function append_lines(path, lines)
  local f, err = io.open(path, 'a')
  if not f then
    -- try to create then append
    local nf, nerr = io.open(path, 'w')
    if not nf then return false, nerr end
    nf:close()
    f, err = io.open(path, 'a')
    if not f then return false, err end
  end
  for _, l in ipairs(lines) do f:write(l .. "\n") end
  f:close()
  return true
end

-- =====================
-- Archiving
-- =====================
local function get_archive_path()
  if cfg.archive_path and #tostring(cfg.archive_path) > 0 then return cfg.archive_path end
  local dir = nil
  if state.cwd_path and #state.cwd_path > 0 then
    local ok, d = pcall(function() return vim.fn.fnamemodify(state.cwd_path, ':h') end)
    if ok and d and #d > 0 then dir = d end
  end
  if not dir or #dir == 0 then
    local ok, home = pcall(function() return vim.fn.expand('~') end)
    dir = (ok and home and #home > 0) and home or '.'
  end
  local sep = package.config:sub(1,1)
  return dir .. sep .. 'archive.txt'
end

-- Move all completed (done) tasks from todo.txt to archive file.
function TodoTxt.archive_done(opts)
  opts = opts or {}
  if not ensure_path() then return end

  local todo_path = state.cwd_path
  local archive_path = get_archive_path()

  -- Read current lines
  local lines = read_lines(todo_path)
  if not lines then lines = {} end

  -- Separate done vs active
  local done_lines, active_lines = {}, {}
  for idx, line in ipairs(lines) do
    local rec = parse_line(line, idx)
    if rec.done then table.insert(done_lines, line) else table.insert(active_lines, line) end
  end

  if #done_lines == 0 then
    vim.notify('TodoTxt: no completed tasks to archive', vim.log.levels.INFO)
    return
  end

  -- Append to archive, then write back active lines to todo
  local okA, errA = append_lines(archive_path, done_lines)
  if not okA then
    vim.notify('TodoTxt: failed to append to archive: ' .. tostring(errA), vim.log.levels.ERROR)
    return
  end

  local okW, errW = write_lines(todo_path, active_lines)
  if not okW then
    vim.notify('TodoTxt: failed to write updated todo file: ' .. tostring(errW), vim.log.levels.ERROR)
    return
  end

  -- Refresh in-memory state and UI
  pcall(read_file)
  pcall(function()
    if state.winid and vim.api.nvim_win_is_valid(state.winid) then
      render()
    end
  end)
  vim.notify(string.format('TodoTxt: archived %d completed task(s) to %s', #done_lines, archive_path), vim.log.levels.INFO)
end

-- =====================
-- Setup and Commands
-- =====================
function TodoTxt.setup(user_cfg)
  user_cfg = user_cfg or {}
  for k, v in pairs(user_cfg) do cfg[k] = v end
  ensure_path()

  -- User command to archive
  pcall(function()
    vim.api.nvim_create_user_command('TodoArchive', function()
      TodoTxt.archive_done()
    end, { desc = 'Archive completed tasks from todo.txt to archive.txt' })
  end)

  -- Optional keymap: <leader>tA
  pcall(function()
    vim.keymap.set('n', '<leader>tA', function() TodoTxt.archive_done() end, { silent = true, desc = 'TodoTxt: Archive completed tasks' })
  end)

end


local function read_file()
  if not ensure_path() then return false end
  local f = io.open(state.cwd_path, 'r')
  local lines = {}
  if f then
    for l in f:lines() do table.insert(lines, l) end
    f:close()
  else
    -- file does not exist; start empty
    lines = {}
  end
  state.lines = lines
  state.records = {}
  for i, l in ipairs(lines) do
    local rec = parse_line(l, i)
    table.insert(state.records, rec)
  end
  return true
end

local function write_file()
  if not ensure_path() then return false end
  local f, err = io.open(state.cwd_path, 'w')
  if not f then
    vim.notify("TodoTxt: write failed: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  for i, rec in ipairs(state.records) do
    local line = fmt_line(rec)
    f:write(line)
    if i < #state.records then f:write("\n") end
  end
  f:close()
  return true
end

-- =====================
-- Sorting and Filtering
-- =====================
local function pri_rank(pri)
  if not pri then return 999 end
  return string.byte(pri) - string.byte('A') + 1
end

local function cmp_dates(a, b)
  if not a and not b then return 0 end
  if a and not b then return -1 end
  if b and not a then return 1 end
  if a == b then return 0 end
  return a < b and -1 or 1
end

local function sort_key(rec, mode)
  mode = mode or state.sort_mode
  if mode == 'priority_then_due' then
    if rec.done then
      return { 1, 999, '9999-99-99', '9999-99-99', '9999-99-99', rec.src_line }
    else
      local due = rec.kv.due and rec.kv.due[1] or nil
      local tdate = rec.kv.t and rec.kv.t[1] or nil
      return { 0, pri_rank(rec.pri), due or '9999-99-99', tdate or '9999-99-99', rec.date_created or '9999-99-99', rec.src_line }
    end
  elseif mode == 'due_only' then
    local due = rec.kv.due and rec.kv.due[1] or '9999-99-99'
    return { rec.done and 1 or 0, due, pri_rank(rec.pri), rec.date_created or '9999-99-99', rec.src_line }
  elseif mode == 'created_old_first' then
    return { rec.done and 1 or 0, rec.date_created or '9999-99-99', pri_rank(rec.pri), (rec.kv.due and rec.kv.due[1]) or '9999-99-99', rec.src_line }
  elseif mode == 'lexical' then
    return { rec.done and 1 or 0, rec.text or '', rec.src_line }
  end
  return { rec.done and 1 or 0, rec.src_line }
end

local function apply_filter(rec, f)
  if not f or not f.tokens or #f.tokens == 0 then return true end
  local text = rec.text or ''
  local projects = {}
  for _, p in ipairs(rec.projects or {}) do projects[p] = true end
  local contexts = {}
  for _, c in ipairs(rec.contexts or {}) do contexts[c] = true end
  for _, tk in ipairs(f.tokens) do
    if tk:sub(1,1) == '+' then
      if not projects[tk:sub(2)] then return false end
    elseif tk:sub(1,1) == '@' then
      if not contexts[tk:sub(2)] then return false end
    elseif tk:match('^pri:([A-Z])$') then
      local want = tk:match('^pri:([A-Z])$')
      if (rec.pri or '') ~= want then return false end
    elseif tk == 'done:true' then
      if not rec.done then return false end
    elseif tk == 'done:false' then
      if rec.done then return false end
    elseif tk:match('^due:') then
      local op, val = tk:match('^due:(<=|>=|=)(%d%d%d%d%-%d%d%-%d%d)$')
      local due = rec.kv.due and rec.kv.due[1] or nil
      if not op or not val then return false end
      if not due then return false end
      if op == '=' and due ~= val then return false end
      if op == '<=' and not (due <= val) then return false end
      if op == '>=' and not (due >= val) then return false end
    elseif tk:match('^t:') then
      local op, val = tk:match('^t:(<=|>=|=)(%d%d%d%d%-%d%d%-%d%d)$')
      local tdate = rec.kv.t and rec.kv.t[1] or nil
      if not op or not val then return false end
      if not tdate then return false end
      if op == '=' and tdate ~= val then return false end
      if op == '<=' and not (tdate <= val) then return false end
      if op == '>=' and not (tdate >= val) then return false end
    elseif tk:match('^overdue:(true|false)$') then
      local want = tk:match('^overdue:(true|false)$')
      local due = rec.kv.due and rec.kv.due[1] or nil
      local is_overdue = false
      if due and not rec.done then
        local td = today()
        if due < td then is_overdue = true end
      end
      if (want == 'true' and not is_overdue) or (want == 'false' and is_overdue) then return false end
    else
      if not text:lower():find(tk:lower(), 1, true) then return false end
    end
  end
  return true
end

local function refresh_sorted_filtered()
  local items = {}
  for _, rec in ipairs(state.records) do
    if cfg.show_done or not rec.done then
      if apply_filter(rec, state.filter) then table.insert(items, rec) end
    end
  end
  table.sort(items, function(a, b)
    local ka = sort_key(a)
    local kb = sort_key(b)
    for i = 1, math.max(#ka, #kb) do
      local va, vb = ka[i], kb[i]
      if va ~= vb then return va < vb end
    end
    return false
  end)
  return items
end

-- =====================
-- UI: Floating Window and Rendering
-- =====================
local function close_window()
  if state.winid and vim.api.nvim_win_is_valid(state.winid) then
    vim.api.nvim_win_close(state.winid, true)
  end
  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    vim.api.nvim_buf_delete(state.bufnr, { force = true })
  end
  state.winid, state.bufnr = nil, nil
  state.map = {}
end

local function open_window()
  if state.winid and vim.api.nvim_win_is_valid(state.winid) then return end
  state.bufnr = vim.api.nvim_create_buf(false, true)
  local columns = vim.o.columns
  local lines = vim.o.lines
  local width = math.floor(columns * 0.8)
  local height = math.floor(lines * 0.7)
  local row = math.floor((lines - height) / 2 - 1)
  local col = math.floor((columns - width) / 2)
  local opts = {
    relative = 'editor', width = width, height = height, row = row, col = col,
    style = 'minimal', border = 'rounded'
  }
  state.winid = vim.api.nvim_open_win(state.bufnr, true, opts)
  vim.api.nvim_buf_set_option(state.bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(state.bufnr, 'filetype', 'todotxtlist')
end

local function render()
  if not (state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr)) then return end
  local items = refresh_sorted_filtered()
  local lines = {}
  local map = {}
  vim.api.nvim_buf_set_option(state.bufnr, 'modifiable', true)
  -- Header/help banner
  local filter_str = (state.filter.tokens and #state.filter.tokens > 0) and table.concat(state.filter.tokens, ' ') or 'none'
  local done_str = cfg.show_done and 'show' or 'hide'
  local shown = #items
  local total = #state.records
  local filepath = state.cwd_path or cfg.path or ''
  local od = 0
  local tdcount = 0
  do
    local td = today()
    for _, rec in ipairs(items) do
      if not rec.done and rec.kv and rec.kv.due and rec.kv.due[1] then
        local due = rec.kv.due[1]
        if due < td then od = od + 1 end
        if due == td then tdcount = tdcount + 1 end
      end
    end
  end
  local head1 = string.format('TodoTxt — sort: %s | filter: %s | done: %s | count: %d/%d | overdue: %d | today: %d | file: %s', state.sort_mode, filter_str, done_str, shown, total, od, tdcount, filepath)
  local head2 = 'Keys: CR jump  * filter-token  q close  r reload  x toggle  dd delete  e edit  a add  A/Z prio  p set  D/T dates  + proj  @ ctx  - remove  s cycle  S choose  f add-filter  F replace  c clear'
  local sep = string.rep('─', math.max(40, math.floor(vim.o.columns * 0.8) - 2))
  table.insert(lines, head1)
  table.insert(lines, head2)
  table.insert(lines, sep)
  local header_count = #lines
  for i, rec in ipairs(items) do
    local chk = rec.done and 'x' or ' '
    local pri = rec.pri and (" (" .. rec.pri .. ")") or ''
    local dd = rec.date_done and (" " .. rec.date_done) or ''
    local dc = rec.date_created and (" " .. rec.date_created) or ''
    local text = rec.text or ''
    local proj = ''
    if rec.projects and #rec.projects > 0 then
      local ps = { unpack(rec.projects) }
      table.sort(ps)
      proj = ' +' .. table.concat(ps, ' +')
    end
    local ctx = ''
    if rec.contexts and #rec.contexts > 0 then
      local cs = { unpack(rec.contexts) }
      table.sort(cs)
      ctx = ' @' .. table.concat(cs, ' @')
    end
    local due = ''
    if rec.kv and rec.kv.due and rec.kv.due[1] then due = ' due:' .. rec.kv.due[1] end
    local tdate = ''
    if rec.kv and rec.kv.t and rec.kv.t[1] then tdate = ' t:' .. rec.kv.t[1] end
    local recs = ''
    if rec.kv and rec.kv.rec and rec.kv.rec[1] then recs = ' rec:' .. rec.kv.rec[1] end
    local line = string.format("[%s]%s%s%s %s%s%s%s", chk, pri, dd, dc, text, proj, ctx, due .. tdate .. recs)
    table.insert(lines, line)
    map[header_count + i] = rec
  end
  state.map = map
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.bufnr, 'modifiable', false)
  -- Highlights: overdue and today on due:
  if state.ns then vim.api.nvim_buf_clear_namespace(state.bufnr, state.ns, 0, -1) end
  for i, rec in ipairs(items) do
    if not rec.done and rec.kv and rec.kv.due and rec.kv.due[1] then
      local due = rec.kv.due[1]
      local line = lines[header_count + i]
      local s, e = string.find(line, ' due:' .. due, 1, true)
      if s and e then
        local group
        local td = today()
        if due < td then group = 'TodoTxtOverdue'
        elseif due == td then group = 'TodoTxtToday' end
        if group and state.ns then
          vim.api.nvim_buf_add_highlight(state.bufnr, state.ns, group, header_count + i - 1, s - 1, e)
        end
      end
    end
  end
end

-- =====================
-- Editing Helpers
-- =====================
local function get_current_rec()
  local row = vim.api.nvim_win_get_cursor(state.winid)[1]
  return state.map[row]
end

local function jump_to_source(rec)
  if not rec or not state.cwd_path then return end
  -- close list UI first
  close_window()
  local path = state.cwd_path
  local ok, err = pcall(function()
    vim.cmd('edit ' .. vim.fn.fnameescape(path))
    pcall(function() vim.api.nvim_win_set_cursor(0, { rec.src_line, 0 }) end)
  end)
  if not ok and err then vim.notify('TodoTxt: jump failed: ' .. tostring(err), vim.log.levels.WARN) end
end

local function reindex_src_lines()
  for i, rec in ipairs(state.records) do rec.src_line = i end
end

local function assign_id_if_needed(rec)
  if not cfg.assign_id then return end
  if rec.kv.id and rec.kv.id[1] then return end
  local ts = os.time()
  state.id_counter = state.id_counter + 1
  rec.kv.id = { tostring(ts) .. '-' .. tostring(state.id_counter) }
end

local function add_record_from_text(text)
  local rec = parse_line(text, #state.records + 1)
  if cfg.auto_created and not rec.date_created then rec.date_created = today() end
  if cfg.assign_id then assign_id_if_needed(rec) end
  table.insert(state.records, rec)
  write_file()
  reindex_src_lines()
  render()
end

local function edit_record_line(rec)
  local initial = fmt_line(rec)
  ui_input({ prompt = 'Edit: ', default = initial }, function(val)
    if not val or #val == 0 then return end
    local newrec = parse_line(val, rec.src_line)
    -- preserve id if present
    if rec.kv.id and not newrec.kv.id then newrec.kv.id = rec.kv.id end
    state.records[rec.src_line] = newrec
    write_file()
    reindex_src_lines()
    render()
  end)
end

local function delete_record(rec)
  local ok = vim.fn.confirm('Delete this task?', '&Yes\n&No', 2) == 1
  if not ok then return end
  table.remove(state.records, rec.src_line)
  write_file()
  reindex_src_lines()
  render()
end

local function toggle_done(rec)
  rec.done = not rec.done
  if rec.done then
    rec.date_done = today()
    if cfg.clear_pri_on_done then rec.pri = nil end
    -- recurrence
    if rec.kv and rec.kv.rec and rec.kv.rec[1] then
      local rule = rec.kv.rec[1]
      local clone = deep_copy(rec)
      clone.done = false
      clone.date_done = nil
      clone.pri = clone.pri -- keep as-is
      clone.date_created = today()
      -- advance due/t if present
      if clone.kv.due and clone.kv.due[1] then
        local base = (cfg.recurrence_base == 'done') and (rec.date_done or today()) or clone.kv.due[1]
        clone.kv.due[1] = add_period(base, rule)
      end
      if clone.kv.t and clone.kv.t[1] then
        local base_t = (cfg.recurrence_base == 'done') and (rec.date_done or today()) or clone.kv.t[1]
        clone.kv.t[1] = add_period(base_t, rule)
      end
      assign_id_if_needed(clone)
      table.insert(state.records, clone)
    end
  else
    rec.date_done = nil
  end
  write_file()
  reindex_src_lines()
  render()
end

local function change_priority(rec, delta)
  local p = rec.pri and string.byte(rec.pri) or nil
  if not p then
    rec.pri = delta < 0 and 'A' or 'Z'
  else
    p = p - delta
    if p < string.byte('A') then p = string.byte('A') end
    if p > string.byte('Z') then p = string.byte('Z') end
    rec.pri = string.char(p)
  end
  write_file(); render()
end

local function set_priority(rec)
  ui_input({ prompt = 'Priority (A-Z, empty to clear): ', default = rec.pri or '' }, function(val)
    if not val or #val == 0 then rec.pri = nil else rec.pri = val:sub(1,1):upper() end
    write_file(); render()
  end)
end

local function set_kv_date(rec, key)
  local cur = rec.kv[key] and rec.kv[key][1] or ''
  ui_input({ prompt = key .. ' (YYYY-MM-DD, empty to clear): ', default = cur }, function(val)
    if not val or #val == 0 then rec.kv[key] = nil
    else
      if not is_date(val) then vim.notify('Invalid date: ' .. val, vim.log.levels.WARN); return end
      rec.kv[key] = { val }
    end
    write_file(); render()
  end)
end

local function add_project(rec)
  ui_input({ prompt = 'Project (without +): ' }, function(val)
    if not val or #val == 0 then return end
    table.insert(rec.projects, val)
    write_file(); render()
  end)
end

local function add_context(rec)
  ui_input({ prompt = 'Context (without @): ' }, function(val)
    if not val or #val == 0 then return end
    table.insert(rec.contexts, val)
    write_file(); render()
  end)
end

local function remove_tag_or_kv(rec)
  -- simple prompt for token to remove
  local tokens = {}
  for _, p in ipairs(rec.projects or {}) do table.insert(tokens, '+' .. p) end
  for _, c in ipairs(rec.contexts or {}) do table.insert(tokens, '@' .. c) end
  for k, vs in pairs(rec.kv or {}) do for _, v in ipairs(vs) do table.insert(tokens, k .. ':' .. v) end end
  if #tokens == 0 then vim.notify('Nothing to remove', vim.log.levels.INFO); return end
  local chooser = vim.ui and vim.ui.select or nil
  if chooser then
    chooser(tokens, { prompt = 'Remove which?' }, function(item)
      if not item then return end
      if item:sub(1,1) == '+' then
        local name = item:sub(2)
        for i, v in ipairs(rec.projects) do if v == name then table.remove(rec.projects, i) break end end
      elseif item:sub(1,1) == '@' then
        local name = item:sub(2)
        for i, v in ipairs(rec.contexts) do if v == name then table.remove(rec.contexts, i) break end end
      else
        local k, v = item:match('^([^:]+):(.+)$')
        if k and v and rec.kv[k] then
          for i, vv in ipairs(rec.kv[k]) do if vv == v then table.remove(rec.kv[k], i) break end end
          if #rec.kv[k] == 0 then rec.kv[k] = nil end
        end
      end
      write_file(); render()
    end)
  else
    local idx = tonumber(vim.fn.input('Index to remove (1-' .. #tokens .. '): '))
    if not idx or idx < 1 or idx > #tokens then return end
    local item = tokens[idx]
    if item:sub(1,1) == '+' then
      local name = item:sub(2)
      for i, v in ipairs(rec.projects) do if v == name then table.remove(rec.projects, i) break end end
    elseif item:sub(1,1) == '@' then
      local name = item:sub(2)
      for i, v in ipairs(rec.contexts) do if v == name then table.remove(rec.contexts, i) break end end
    else
      local k, v = item:match('^([^:]+):(.+)$')
      if k and v and rec.kv[k] then
        for i, vv in ipairs(rec.kv[k]) do if vv == v then table.remove(rec.kv[k], i) break end end
        if #rec.kv[k] == 0 then rec.kv[k] = nil end
      end
    end
    write_file(); render()
  end
end

-- =====================
-- Filters and Sort selection
-- =====================
local sort_modes = { 'priority_then_due', 'due_only', 'created_old_first', 'lexical' }

local function cycle_sort()
  local idx = 1
  for i, m in ipairs(sort_modes) do if m == state.sort_mode then idx = i break end end
  idx = (idx % #sort_modes) + 1
  state.sort_mode = sort_modes[idx]
  render()
end

local function choose_sort()
  if vim.ui and vim.ui.select then
    vim.ui.select(sort_modes, { prompt = 'Sort mode' }, function(item)
      if not item then return end
      state.sort_mode = item
      render()
    end)
  else
    local inp = vim.fn.input('Sort mode (' .. table.concat(sort_modes, ',') .. '): ', state.sort_mode)
    if inp and #inp > 0 then state.sort_mode = inp end
    render()
  end
end

local function parse_filter_input(inp)
  local toks = {}
  for tk in string.gmatch(inp or '', '%S+') do table.insert(toks, tk) end
  state.filter = { tokens = toks }
end

local function add_filter()
  local cur = table.concat(state.filter.tokens or {}, ' ')
  ui_input({ prompt = 'Add filter tokens: ', default = '' }, function(val)
    if not val or #val == 0 then return end
    local add = {}
    for tk in string.gmatch(val, '%S+') do table.insert(add, tk) end
    local merged = {}
    for _, tk in ipairs(state.filter.tokens or {}) do table.insert(merged, tk) end
    for _, tk in ipairs(add) do table.insert(merged, tk) end
    state.filter.tokens = merged
    render()
  end)
end

local function replace_filter()
  local cur = table.concat(state.filter.tokens or {}, ' ')
  ui_input({ prompt = 'Filter tokens: ', default = cur }, function(val)
    state.filter.tokens = {}
    parse_filter_input(val or '')
    render()
  end)
end

local function clear_filter()
  state.filter.tokens = {}
  render()
end

-- =====================
-- Commands and Keymaps
-- =====================
local function reload()
  read_file()
  render()
end

local function open_list()
  if not read_file() then return end
  open_window()
  render()
end

local function toggle_list()
  if state.winid and vim.api.nvim_win_is_valid(state.winid) then
    close_window()
  else
    open_list()
  end
end

local function quick_add()
  ui_input({ prompt = 'New TODO: ' }, function(val)
    if not val or #val == 0 then return end
    add_record_from_text(val)
  end)
end

local function quick_filter()
  ui_input({ prompt = 'Filter tokens: ' }, function(val)
    parse_filter_input(val or '')
    open_list()
  end)
end

local function set_buffer_keymaps()
  local opts = { nowait = true, noremap = true, silent = true, buffer = state.bufnr }
  vim.keymap.set('n', '<CR>', function() local rec = get_current_rec(); if rec then jump_to_source(rec) end end, opts)
  vim.keymap.set('n', '*', function()
    -- Filter by token under cursor inside the list UI; ignore header lines
    local rec = get_current_rec()
    if not rec then return end
    local tok = token_under_cursor()
    tok = normalize_filter_token(tok)
    if not tok or #tok == 0 then return end
    state.filter.tokens = { tok }
    render()
  end, opts)
  vim.keymap.set('n', 'q', close_window, opts)
  vim.keymap.set('n', 'r', reload, opts)
  vim.keymap.set('n', 'x', function() local rec = get_current_rec(); if rec then toggle_done(rec) end end, opts)
  vim.keymap.set('n', 'A', function() local rec = get_current_rec(); if rec then change_priority(rec, 1) end end, opts)
  vim.keymap.set('n', 'Z', function() local rec = get_current_rec(); if rec then change_priority(rec, -1) end end, opts)
  vim.keymap.set('n', 'p', function() local rec = get_current_rec(); if rec then set_priority(rec) end end, opts)
  vim.keymap.set('n', 'D', function() local rec = get_current_rec(); if rec then set_kv_date(rec, 'due') end end, opts)
  vim.keymap.set('n', 'T', function() local rec = get_current_rec(); if rec then set_kv_date(rec, 't') end end, opts)
  vim.keymap.set('n', '+', function() local rec = get_current_rec(); if rec then add_project(rec) end end, opts)
  vim.keymap.set('n', '@', function() local rec = get_current_rec(); if rec then add_context(rec) end end, opts)
  vim.keymap.set('n', '-', function() local rec = get_current_rec(); if rec then remove_tag_or_kv(rec) end end, opts)
  vim.keymap.set('n', 'dd', function() local rec = get_current_rec(); if rec then delete_record(rec) end end, opts)
  vim.keymap.set('n', 'a', function()
    ui_input({ prompt = 'Add TODO: ' }, function(val)
      if not val or #val == 0 then return end
      add_record_from_text(val)
    end)
  end, opts)
  vim.keymap.set('n', 'e', function() local rec = get_current_rec(); if rec then edit_record_line(rec) end end, opts)
  vim.keymap.set('n', 's', cycle_sort, opts)
  vim.keymap.set('n', 'S', choose_sort, opts)
  vim.keymap.set('n', 'f', add_filter, opts)
  vim.keymap.set('n', 'F', replace_filter, opts)
  vim.keymap.set('n', 'c', clear_filter, opts)
end

-- autocmd to set keymaps when window opens
vim.api.nvim_create_autocmd('BufWinEnter', {
  callback = function(args)
    if args.buf == state.bufnr then set_buffer_keymaps() end
  end,
})

-- =====================
-- Setup
-- =====================
function TodoTxt.setup(user)
  user = user or {}
  for k, v in pairs(user) do cfg[k] = v end
  state.sort_mode = cfg.default_sort or 'priority_then_due'
  -- namespace and default highlights
  state.ns = vim.api.nvim_create_namespace('todotxt')
  if not pcall(function() return vim.api.nvim_get_hl(0, { name = 'TodoTxtOverdue' }) end) then
    vim.api.nvim_set_hl(0, 'TodoTxtOverdue', { fg = vim.rgb and nil or nil, link = 'DiagnosticError' })
  end
  if not pcall(function() return vim.api.nvim_get_hl(0, { name = 'TodoTxtToday' }) end) then
    vim.api.nvim_set_hl(0, 'TodoTxtToday', { link = 'DiagnosticWarn' })
  end
  -- Global keymaps
  if not vim.g.mapleader or vim.g.mapleader == '' then vim.g.mapleader = ' ' end
  vim.keymap.set('n', '<leader>tt', toggle_list, { noremap = true, silent = true, desc = 'TodoTxt: toggle list' })
  vim.keymap.set('n', '<leader>ta', quick_add, { noremap = true, silent = true, desc = 'TodoTxt: quick add' })
  vim.keymap.set('n', '<leader>tf', quick_filter, { noremap = true, silent = true, desc = 'TodoTxt: filter and open' })
  -- Archive command and keymap
  vim.keymap.set('n', '<leader>tA', function() TodoTxt.archive_done() end, { noremap = true, silent = true, desc = 'TodoTxt: archive completed' })
  pcall(function()
    vim.api.nvim_create_user_command('TodoArchive', function()
      TodoTxt.archive_done()
    end, { desc = 'Archive completed tasks to archive.txt' })
  end)
  -- Open built-in explorer (netrw) with <leader>e (leader defaults to space)
  vim.keymap.set('n', '<leader>e', function() vim.cmd('Ex') end, { noremap = true, silent = true, desc = 'Open file explorer (netrw)' })

  -- On clean start, optionally open todo.txt (disabled by default to avoid swap conflicts)
  if cfg.open_on_start then
    vim.api.nvim_create_autocmd('VimEnter', {
      once = true,
      callback = function()
        if vim.fn.argc() == 0 then
          local home = vim.fn.expand('~')
          pcall(function() vim.cmd('cd ' .. vim.fn.fnameescape(home)) end)
          local path = cfg.path or vim.fn.expand('~/todo.txt')
          local f = io.open(path, 'r')
          if not f then local nf = io.open(path, 'w'); if nf then nf:close() end else f:close() end
          local ok_edit, err = pcall(function()
            vim.cmd('edit ' .. vim.fn.fnameescape(path))
          end)
          if not ok_edit and err then
            vim.notify('TodoTxt: failed to open todo file: ' .. tostring(err), vim.log.levels.WARN)
          end
        end
      end,
    })
  end

  -- Buffer-local mapping in the todo.txt file: g* to filter by token under cursor
  vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufEnter' }, {
    callback = function(args)
      local buf = args.buf
      local name = vim.api.nvim_buf_get_name(buf)
      local target = cfg.path or vim.fn.expand('~/todo.txt')
      local ok1, abs_name = pcall(function() return vim.fn.fnamemodify(name, ':p') end)
      local ok2, abs_target = pcall(function() return vim.fn.fnamemodify(target, ':p') end)
      if ok1 and ok2 and abs_name == abs_target then
        vim.keymap.set('n', 'g*', function()
          local tok = token_under_cursor()
          tok = normalize_filter_token(tok)
          if not tok or #tok == 0 then return end
          state.filter.tokens = { tok }
          open_list()
        end, { buffer = buf, noremap = true, silent = true, desc = 'TodoTxt: filter by token under cursor' })
        -- Map bare '*' too, as requested in inst2.md
        vim.keymap.set('n', '*', function()
          local tok = token_under_cursor()
          tok = normalize_filter_token(tok)
          if not tok or #tok == 0 then return end
          state.filter.tokens = { tok }
          open_list()
        end, { buffer = buf, noremap = true, silent = true, desc = 'TodoTxt: filter by token under cursor (*)' })
      end
    end,
  })
end

-- Expose open/toggle if needed
TodoTxt.open = open_list
TodoTxt.reload = reload
TodoTxt.toggle = toggle_list
function TodoTxt.filter_under_cursor()
  local tok = token_under_cursor()
  if not tok or #tok == 0 then return end
  state.filter.tokens = { tok }
  open_list()
end


TodoTxt.setup({
  path = vim.fn.expand('~/todo.txt'), -- 省略時は ~/todo.txt（無ければ自動作成）
  default_sort = 'priority_then_due',
  float = true,
  show_done = false,
  auto_created = true,
  clear_pri_on_done = true,
  assign_id = true,
  recurrence_base = 'done', -- 'due' or 'done'
  open_on_start = true,
})
