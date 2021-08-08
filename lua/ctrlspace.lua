local fzy = require("fzy_lua")

local function ctrlspace_filter(candidates, query, max)
  local results = {}
  for _, n in ipairs(candidates) do
    if fzy.has_match(query, n.text) then
       n.score = fzy.score(query, n.text)
       table.insert(results, n)
     end
  end

  table.sort(results, function(x, y)
    if x.score < y.score then
      return true
    elseif x.score > y.score then
      return false
    else
      return x.index < y.index
    end
  end)

  local start = 1
  if max < #results then
    start = #results - max
  end

  local top = {}
  for i=start, #results do
    local r = results[i]
    r.positions = fzy.positions(query, r.text)
    table.insert(top, r)
  end
  return top
end

local fn = vim.fn
local api = vim.api

local files = {}
local buffers = { api = {} }
local bookmarks = {}
local tabs = {}
local drawer = {}
local search = {}
local ui = {}
local modes = { all = {} ; slots = {} }

local M = {
  modes = modes,
  files = files,
  buffers = buffers,
  tabs = tabs,
  drawer = drawer,
  search = search,
  bookmarks = bookmarks,
  ui = ui,
}

local files_cache = nil

function files.clear ()
  files = nil
end

local item = {}

function item.create(index, text, indicators)
  if index == 0 then
    error("index must not be 0")
  end
  return {
    index = index,
    text = text,
    indicators = indicators,
  }
end

local function buffer_name(bufnr)
  local name = fn.fnamemodify(fn.bufname(bufnr), ":.")
  if name == "" then
    return "[" .. bufnr .. "*No Name]"
  else
    return name
  end
end

-- introduce customization for this eventually
local function glob_cmd()
  return "rg --color=never --files --sort path"
end

function files.collect ()
  if files_cache then
    return files_cache
  end
  local output = fn["ctrlspace#util#system"](glob_cmd())
  local res = {}
  local i = 1
  for s in string.gmatch(output, "[^\r\n]+") do
    local text = fn.fnamemodify(s, ":.")
    local m = item.create(i, text, "")
    table.insert(res, m)
    i = i + 1
  end
  files_cache = res
  return files_cache
end

local getbufvar = fn.getbufvar

-- TODO use this helper consistently
local function exe(cmds)
  for _, cmd in ipairs(cmds) do
    vim.cmd('silent! ' .. cmd)
  end
end

function ui.input(prompt, default, compl)
  local config = fn["ctrlspace#context#Configuration"]()
  prompt = config.Symbols.CS .. "  " .. prompt
  fn["inputsave"]()
  local answer
  if compl then
    answer = fn.input(prompt, default, compl)
  elseif default then
    answer = fn.input(prompt, default)
  else
    answer = fn.input(prompt)
  end
  fn["inputrestore"]()
  exe({"redraw!"})
  return answer
end

function ui.confirmed(msg)
  return ui.input(msg .. " (yN): ") == "y"
end

local function plugin_buffer(buf)
  return getbufvar(buf, "&ft") == "ctrlspace"
end

local function managed_buf(buf)
  return fn.buflisted(buf) and not plugin_buffer(buf)
end

function files.load_file_or_buffer(file)
  local listed = fn.buflisted(file) == 1
  if listed then
    exe({"b " .. fn.bufnr(file)})
  else
    exe({"e " .. fn.fnameescape(file)})
  end
end

function files.load_file(commands)
  local file = drawer.selected_file_path()
  file = fn.fnamemodify(file, ":p")
  drawer.kill(true)
  exe(commands)
  M.files.load_file_or_buffer(file)
end

local function assert_drawer_off()
  local pbuf = drawer.buffer()
  if pbuf ~= -1 then
    error("plugin buffer exists\n" .. debug.traceback())
  end
end

local function assert_drawer_on()
  if vim.bo.filetype ~= "ctrlspace" then
    error("the current buffer isn't ctrlspace\n" .. debug.traceback())
  end
end

function files.load_many_files(pre, post)
  assert_drawer_on()
  local file = fn.fnamemodify(drawer.selected_file_path(), ":p")
  local curln = fn.line(".")
  drawer.kill(false)
  drawer.go_start_window()
  exe(pre)
  M.files.load_file_or_buffer(file)
  exe({"normal! zb"})
  exe(post)
  drawer.restore()
  drawer.move_selection_and_remember(curln)
end

function files.edit()
  assert_drawer_on()
  local path = fn.fnamemodify(drawer.selected_file_path(), ":p:h")
  local file = ui.input("Edit a new file: ", path .. '/', "file")
  if not file or string.len(file) == 0 then
    return
  end

  file = fn.expand(file)
  file = fn.fnamemodify(file, ":p")

  drawer.kill(true)
  exe({"e " .. fn.fnameescape(file)})
end

function files.edit_dir()
  assert_drawer_on()
  local path = fn.fnamemodify(drawer.selected_file_path(), ":p:h")

  drawer.kill(true)
  exe({"e " .. fn.fnameescape(path)})
end

function buffers.add_current()
  local current = fn.bufnr('%')

  if not managed_buf(current) then
    return
  end

  vim.b.CtrlSpaceJumpCounter = fn["ctrlspace#jumps#IncrementJumpCounter"]()

  if not vim.t.CtrlSpaceList then
    vim.t.CtrlSpaceList = {}
  end

  local tmp = vim.t.CtrlSpaceList
  tmp[tostring(current)] = true
  vim.t.CtrlSpaceList = tmp
end

-- TODO sort
local function all_buffers()
  local res = {}
  for _, buf in pairs(api.nvim_list_bufs()) do
    if managed_buf(buf) then
      res[buf] = true
    end
  end
  return res
end

local function buffer_modified(bufnr)
  return getbufvar(bufnr, "&modified") == 1
end

function buffers.unsaved()
  local res = {}
  for b, _ in ipairs(all_buffers()) do
    if buffer_modified(b) and managed_buf(b) then
      table.insert(res, b)
    end
  end
  return res
end

local function raw_buffers_in_tab(tabnr)
  return fn.gettabvar(tabnr, "CtrlSpaceList", {})
end

local function buffers_in_tab(tabnr)
  local res = {}
  for key, _ in pairs(raw_buffers_in_tab(tabnr)) do
    res[tonumber(key)] = true
  end
  return res
end

-- TODO this should exist in the tabs module
-- TODO sort
buffers.in_tab = function (tabnr)
  local res = {}
  local t = raw_buffers_in_tab(tabnr)
  for k, _ in pairs(t) do
    table.insert(res, tonumber(k))
  end
  return res
end

-- local function find_buffer_visible_in_tabs(bufnr)
--   local res = {}
--   for tabnr=1,fn.tabpagenr("$") do
--     local tab_buffers = fn.tabpagebuflist(tabnr)
--     for _, b in ipairs(tab_buffers) do
--       if b == bufnr then
--         res[tabnr] = true
--       end
--     end
--   end
--   return res
-- end

-- returns a table keyed by the tabs containing the buffer. the values of the
-- table are a boolean that tells if the buffer is actualyl being displayed
local function find_buffer_in_tabs(bufnr)
  local res = {}
  for tabnr=1,fn.tabpagenr("$") do
    local in_tab_list = buffers_in_tab(tabnr)[bufnr]
    if in_tab_list then
      local visible_buffers = fn.tabpagebuflist(tabnr)
      local visible = false
      for _, b in ipairs(visible_buffers) do
        if b == bufnr then
          visible = true
        end
      end
      res[tabnr] = visible
    end
  end
  return res
end

function buffers.remove(bufnr)
  bufnr = tonumber(bufnr)
  local in_tabs = find_buffer_in_tabs(bufnr)
  for tabnr, _ in ipairs(in_tabs) do
    tabs.remove_buffers(tabnr, {bufnr})
  end
end

-- you must restore the view after calling this function
local function forget_buffer_in_tab(tabnr, bufnr)
  assert_drawer_off()
  local curtab = fn.tabpagenr()
  if curtab ~= tabnr then
    exe({"tabn " .. tabnr})
  end
  local winnr = fn.bufwinnr(bufnr)
  local new_buf = nil
  while winnr ~= -1 do
    exe({winnr .. "wincmd w"})

    -- this ensures that we create at most one new buffer per forget
    local next_buf = new_buf or tabs.next_buf(tabnr, bufnr)

    if next_buf then
      exe({"b! " .. next_buf})
    else
      exe({"enew"})
      new_buf = fn.bufnr()
    end
    winnr = fn.bufwinnr(bufnr)
  end
  tabs.remove_buffers(tabnr, {bufnr})
end

local function forget_buffer_in_all_tabs(bufnr)
  local curtab = fn.tabpagenr()
  local in_tabs = find_buffer_in_tabs(bufnr)
  for t, _ in pairs(in_tabs) do
    forget_buffer_in_tab(t, bufnr)
  end
  exe({"tabn " .. curtab})
end

local function with_restore_drawer(f)
  assert_drawer_on()
  local curln = fn.line(".")
  drawer.kill(false)
  f()
  assert_drawer_off()
  drawer.toggle(true)
  drawer.move_selection_and_remember(curln)
end

local function delete_buffer(bufnr)
  local modified = buffer_modified(bufnr)
  if modified and not ui.confirmed(
    "The buffer contains unsaved changes. Proceed anyway?") then
    return
  end

  with_restore_drawer(function ()
    forget_buffer_in_all_tabs(bufnr)
    -- why aren't we using wipeout like elsewhere?
    exe({"bdelete! " .. bufnr})
  end)
end

function buffers.delete ()
  local bufnr = drawer.last_selected_index()
  delete_buffer(bufnr)
end

local function detach_buffer(bufnr)
  local modified = buffer_modified(bufnr)
  if modified and not ui.confirmed(
    "The buffer contains unsaved changes. Proceed anyway?") then
    return
  end

  with_restore_drawer(function ()
    local curtab = fn.tabpagenr()
    forget_buffer_in_tab(curtab, bufnr)
  end)
end

function buffers.detach()
  local bufnr = drawer.last_selected_index()
  detach_buffer(bufnr)
end

function buffers.close_buffer()
  local bufnr = drawer.last_selected_index()
  local found_tabs = tabs.buffer_present_count(bufnr)
  if found_tabs > 1 then
    buffers.detach()
  else
    buffers.delete()
  end
end

function buffers.api.in_tab(tabnr)
  local res = {}
  for k, _ in pairs(raw_buffers_in_tab(tabnr)) do
    res[tostring(k)] = buffer_name(k)
  end
  return res
end

function buffers.in_all_tabs ()
  local res = {}
  for tabnr=1,fn.tabpagenr("$") do
    for _, b in ipairs(buffers.in_tab(tabnr)) do
      res[b] = true
    end
  end
  return res
end

function buffers.all ()
  local res = {}
  for buf, _ in pairs(all_buffers()) do
    table.insert(res, buf)
  end
  return res
end

local function foreign_buffers()
  local bufs =  {}
  for _, i in ipairs(buffers.all()) do
    bufs[i] = true
  end
  for tabnr=1,fn.tabpagenr("$") do
    for _, b in ipairs(buffers.in_tab(tabnr)) do
      bufs[b] = nil
    end
  end
  return bufs
end

function buffers.foreign ()
  local bufs = foreign_buffers()
  local res = {}
  for i, _ in pairs(bufs) do
    table.insert(res, i)
  end
  return res
end

local function delete_buffers (bufs)
  for b, _ in pairs(bufs) do
    vim.cmd('exe "bwipeout" ' .. b)
  end
  tabs.forget_buffers(bufs)
end

function buffers.visible ()
  local res = {}
  for tabnr=1,fn.tabpagenr("$") do
    for _, b in ipairs(fn.tabpagebuflist(tabnr)) do
      if managed_buf(b) then
        res[b] = true
      end
    end
  end
  return res
end

function buffers.unnamed ()
  local res = {}
  for _, b in ipairs(buffers.all()) do
    if managed_buf(b)
      and fn.bufexists(b)
      and (not getbufvar(b, "&buftype")
      or fn.filereadable(fn.bufname(b))) then
      res[b] = true
    end
  end
  return res
end

buffers.delete_hidden_noname = function ()
  local bufs = all_buffers()
  for u, _ in pairs(buffers.unnamed()) do
    bufs[u] = nil
  end
  for u, _ in pairs(buffers.visible()) do
    bufs[u] = nil
  end
  delete_buffers(bufs)
end

buffers.delete_foreign = function ()
  delete_buffers(foreign_buffers())
end

tabs.buffer_present_count = function (buf)
  local res = 0
  local b = tostring(buf)
  for tabnr=1,fn.tabpagenr("$") do
    local btabs = raw_buffers_in_tab(tabnr)
    if btabs[b] then
      res = res + 1
    end
  end
  return res
end

local function number_of_buffers_in_tab(tabnr)
  local bufs = 0
  for _, _ in pairs(buffers_in_tab(tabnr)) do
    bufs = bufs + 1
  end
  return bufs
end

function tabs.next_buf(tabnr, buf)
  local bufs = buffers_in_tab(tabnr)
  local next = nil
  local prev = nil
  for candidate, _ in pairs(bufs) do
    if candidate > buf then
      if next then
        if candidate - buf < next - buf then
          next = candidate
        end
      else
        next = candidate
      end
    elseif candidate < buf then
      if prev then
        if candidate < prev then
          prev = candidate
        end
      else
        prev = candidate
      end
    end
  end
  return (next or prev)
end

function tabs.buffers_number(tabnr)
  local config = fn["ctrlspace#context#Configuration"]()
  local count = number_of_buffers_in_tab(tabnr)
  local superscripts = {"⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"}
  if config.UseUnicode == 1 then
    count = tostring(count)
    local res = {}
    for i = 1, #count do
      local char = tonumber(string.sub(count, i, i))
      local super_char = superscripts[char - 1]
      table.insert(res, super_char)
    end
    return table.concat(res, "")
  else
    return tostring(count)
  end
end

function tabs.modified(tabnr)
  for b, _ in pairs(buffers_in_tab(tabnr)) do
    if buffer_modified(b) then
      return true
    end
  end
  return false
end

function tabs.remove_buffers(tabnr, bufs)
  local bufs_in_tab = raw_buffers_in_tab(tabnr)
  local modified = false
  for _, key_int in ipairs(bufs) do
    local key = tostring(key_int)
    if bufs_in_tab[key] then
      modified = true
      bufs_in_tab[key] = nil
    end
  end
  if modified then
    fn.settabvar(tabnr, "CtrlSpaceList", bufs_in_tab)
  end
end

tabs.forget_buffers = function (bufs)
  for tabnr=1,fn.tabpagenr("$") do
    tabs.remove_buffers(tabnr, bufs)
  end
end

tabs.add_buffer = function (tabnr, buf)
  local btabs = raw_buffers_in_tab(tabnr)
  local key = tostring(buf)
  if btabs[key] then
    return
  end
  btabs[key] = true
  fn.settabvar(tabnr, "CtrlSpaceList", btabs)
end

function drawer.buffer()
  for _, buf in pairs(api.nvim_list_bufs()) do
    if plugin_buffer(buf) then
      return buf
    end
  end
  return -1
end

function buffers.load(pre)
  local nr = drawer.last_selected_index()
  drawer.kill(true)
  exe(pre)
  exe({"b " .. nr})
end

function buffers.load_keep(pre, post)
  local nr = drawer.last_selected_index()
  local curln = fn.line(".")
  drawer.kill(false)
  fn["ctrlspace#window#GoToStartWindow"]()
  exe(pre)
  exe({"b " .. nr})
  vim.cmd("normal! zb")
  exe(post)
  drawer.restore()
  drawer.move_selection_and_remember(curln)
end

function drawer.go_to_buffer_or_file(direction)
  local start = fn.tabpagenr()
  local limit = fn.tabpagenr("$")

  local target_tab, target_buffer

  local modes = fn["ctrlspace#modes#Modes"]()
  local found
  if modes.File.Enabled == 1 then
    local file = drawer.selected_file_path()
    file = fn.fnamemodify(file, ":p")
    found = function(bufnr)
      return file == fn.fnamemodify(fn.bufname(bufnr), ":p")
    end
  elseif modes.Buffer.Enabled == 1 then
    local nr = drawer.last_selected_index()
    found = function(bufnr)
      return bufnr == nr
    end
  end

  for i=0, limit-1 do
    local j = start + (i * direction)
    if j > limit then
      j = j - limit
    end
    if j <= 0 then
      j = limit + j
    end

    for bufnr, _ in pairs(buffers_in_tab(j)) do
      if found(bufnr) then
        target_tab = j
        target_buffer = bufnr
        goto found
      end
    end
  end

  ::found::

  if target_tab and target_buffer then
    with_restore_drawer(function ()
      exe({"normal! " .. target_tab .. "gt"})
      -- TODO restore cursor to the selected buffer
    end)
  end
end

local function help_filler()
  return string.rep(" ", vim.o.columns) .. "\n"
end

local function bookmark_items()
  local config = fn["ctrlspace#context#Configuration"]()

  local bookmarks = fn['ctrlspace#bookmarks#Bookmarks']()
  local active = fn['ctrlspace#bookmarks#FindActiveBookmark']()

  local res = {}
  for i, bm in ipairs(bookmarks) do
    local indicators = ""
    if active and bm.Directory == active.Directory then
      indicators = config.Symbols.IA
    end
    table.insert(res, item.create(i, bm.Name, indicators))
  end
  return res
end

local function workspace_items (clv)
  local workspaces = fn["ctrlspace#workspaces#Workspaces"]()
  local active = fn["ctrlspace#workspaces#ActiveWorkspace"]()
  local config = fn["ctrlspace#context#Configuration"]()

  local res = {}
  for i, ws in ipairs(workspaces) do
    local indicators = ""
    if active and ws == active.Name and active.Status ~= 0 then
      if active.Status == 2 then
        indicators = indicators .. config.Symbols.IM
      end
    elseif ws == clv.Data.LastActive then
      indicators = indicators .. config.Symbols.IV
    end
    table.insert(item.create(i, ws, indicators))
  end
  return res
end

local function tab_items()
  local config = fn["ctrlspace#context#Configuration"]()
  local current_tab = fn.tabpagenr()

  local res = {}
  for tabnr=1,fn.tabpagenr("$") do
    local indicators = ""

    local tab_buffer_number = fn["ctrlspace#api#TabBuffersNumber"](tabnr)
    local title = fn["ctrlspace#api#TabTitle"](tabnr)

    if fn["ctrlspace#api#TabModified"](tabnr) ~= 1 then
      indicators = indicators .. config.Symbols.IM
    end

    if tabnr == current_tab then
      indicators = indicators .. config.Symbols.IA
    end

    local name = tabnr .. " " .. tab_buffer_number .. " " .. title
    table.insert(res, item.create(tabnr, name, indicators))
  end
  return res
end

local function buffer_items(clv)
  local res = {}
  local bufs
  local submode = clv.Data.SubMode
  local config = fn["ctrlspace#context#Configuration"]()

  if submode == "single" then
    bufs = buffers_in_tab(fn.tabpagenr())
  elseif submode == "all" then
    bufs = all_buffers()
  elseif submode == "visible" then
    bufs = {}
    for buf, _ in raw_buffers_in_tab(fn.tabeagenr()) do
      if fn.bufwinnr(buf) ~= -1 then
        bufs[buf] = true
      end
    end
  else
    error("invalid mode " .. submode)
  end

  for bufnr, _ in pairs(bufs) do
    local name = buffer_name(bufnr)
    local modified = buffer_modified(bufnr)
    local winnr = fn.bufwinnr(bufnr)

    local indicators = ""
    if modified then
      indicators = indicators .. config.Symbols.IM
    end

    if winnr == vim.t.CtrlSpaceStartWindow then
      indicators = indicators .. config.Symbols.IA
    elseif winnr ~= -1 then
      indicators = indicators .. config.Symbols.IV
    end

    table.insert(res, item.create(bufnr, name, indicators))
  end

  return res
end

local function content_source()
  local clv = fn["ctrlspace#modes#CurrentListView"]()

  if clv.Name == "Buffer" then
    return buffer_items(clv)
  elseif clv.Name == "File" then
    -- TODO why doesn't this work?
    -- return M.files.collect()
    return M.files.collect()
  elseif clv.Name == "Tab" then
    return tab_items()
  elseif clv.Name == "Workspace" then
    return workspace_items(clv)
  elseif clv.Name == "Bookmark" then
    return bookmark_items()
  else
    error("unknown list view: " .. clv.Name)
  end
end

local function render_candidates(items)
  local config = fn["ctrlspace#context#Configuration"]()
  local modes = fn["ctrlspace#modes#Modes"]()
  local sizes = fn["ctrlspace#context#SymbolSizes"]()

  local item_space
  if modes.File.Enabled == 1 then
    item_space = 5
  elseif modes.Bookmark.Enabled == 1 then
    item_space = 5 + sizes.IAV
  else
    item_space = 5 + sizes.IAV + sizes.IM
  end

  local res = {}
  local columns = vim.o.columns

  for _, i in ipairs(items) do
    local line = i.text
    local len = string.len(line)

    if len + item_space > columns then
      line = config.Symbols.Dots .. string.sub(line, line - columns + item_space + sizes.Dots)
    end

    if i.indicators ~= "" then
      line = line .. " " .. i.indicators
    end
    line = "  " .. line

    table.insert(res, line)
  end

  return res
end

function drawer.content ()
  local absolute_max = 500
  local candidates = content_source()
  local modes = fn["ctrlspace#modes#Modes"]()
  local query = table.concat(modes.Search.Data.Letters, "")
  if query == "" then
    if #candidates > absolute_max then
      candidates = { unpack(candidates, 1, absolute_max) }
    end
  else
    local max
    if modes.Search.Enabled == 1 then
      max = drawer.max_height()
    else
      max = absolute_max
    end
    candidates = ctrlspace_filter(candidates, query, max)
  end

  return candidates
end

local function save_tab_config()
  vim.t.CtrlSpaceStartWindow = fn.winnr()
  vim.t.CtrlSpaceWinrestcmd  = fn.winrestcmd()
  vim.t.CtrlSpaceActivebuf   = fn.bufnr("")
end

function drawer.show()
  save_tab_config()
  exe({
    "noautocmd botright pedit CtrlSpace",
    "noautocmd wincmd P"
  })
end

local function drawer_display(items)
  vim.cmd('setlocal modifiable')
  local buf = drawer.buffer()
  if #items > 0 then
    local line = 0
    local text = render_candidates(items)
    api.nvim_buf_set_lines(buf, 0, -1, true, text)
    for _, i in ipairs(items) do
      if i.positions then
        for _, hl in ipairs(i.positions) do
          api.nvim_buf_add_highlight(0, -1, "CtrlSpaceSearch", line, hl + 1, hl + 2)
        end
      end
      line = line + 1
    end
  else
    api.nvim_buf_set_lines(buf, 0, -1, true, {"  List empty"})
    vim.cmd("normal! GkJ")
    vim.cmd("normal! 0")
    vim.cmd([[
      let modes = ctrlspace#modes#Modes()
      call modes.Nop.Enable()
    ]])
  end
  vim.cmd('setlocal nomodifiable')
end

drawer.insert_content = function ()
  local config = fn["ctrlspace#context#Configuration"]()
  local modes = fn["ctrlspace#modes#Modes"]()
  exe({'resize ' .. config.Height})
  if modes.Help.Enabled == 1 then
    fn["ctrlspace#help#DisplayHelp"](help_filler())
    fn["ctrlspace#util#SetStatusline"]()
    return
  end

  local items = drawer.content()

  -- for backwards compat
  vim.b.items = items
  vim.b.size = #items

  if #items > config.Height then
    local max_height = drawer.max_height()
    local size
    if #items < max_height then
      size = #items
    else
      size = max_height
    end
    exe({'resize ' .. size})
  end

  drawer_display(items)
  fn["ctrlspace#util#SetStatusline"]()
  fn["ctrlspace#window#setActiveLine"]()
  vim.cmd("normal! zb")
end

function drawer.refresh ()
  local last_line = fn.line("$")
  vim.cmd('setlocal modifiable')
  api.nvim_buf_set_lines(0, 0, last_line, 0, {})
  vim.cmd('setlocal nomodifiable')
  drawer.insert_content()
end

function drawer.setup_buffer ()
  vim.cmd([[
    setlocal noswapfile
    setlocal buftype=nofile
    setlocal bufhidden=delete
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal nowrap
    setlocal nonumber
    setlocal norelativenumber
    setlocal nocursorcolumn
    setlocal nocursorline
    setlocal nospell
    setlocal nolist
    setlocal cc=
    setlocal filetype=ctrlspace
    setlocal foldmethod=manual

    augroup CtrlSpaceUpdateSearch
        au!
        au CursorHold <buffer> call ctrlspace#search#UpdateSearchResults()
    augroup END

    augroup CtrlSpaceLeave
        au!
        au BufLeave <buffer> call ctrlspace#window#Kill(1)
    augroup END
  ]])
  local root = fn["ctrlspace#roots#CurrentProjectRoot"]()

  if root then
    exe({"lcd " .. fn.fnameescape(root)})
  end

  if vim.o.timeout then
    vim.b.timeout_save = vim.o.timeoutlen
    vim.o.timeoutlen = 10
  end

  local config = fn["ctrlspace#context#Configuration"]()

  vim.b.updatetime_save = vim.o.updatetime
  vim.o.updatetime = config.SearchTiming

  if not config.UseMouseAndArrowsInTerm and not fn.has("gui_running") then
    vim.cmd([[
        " Block unnecessary escape sequences!
        noremap <silent><buffer><esc>[ :call ctrlspace#keys#MarkKeyEscSequence()<CR>
        let b:mouseSave = &mouse
        set mouse=
    ]])
  end

  for _, k in ipairs(fn["ctrlspace#keys#KeyNames"]()) do
    local key = k
    if string.len(k) > 1 then
      key = "<" .. k .. ">"
    end

    if k == '"' then
      k = '\\' .. k
    end

    exe(
      {"nnoremap <silent><buffer> " .. key .. ' :call ctrlspace#keys#Keypressed("' .. k .. '")<CR>'})
  end
end

function drawer.max_height()
  local config = fn["ctrlspace#context#Configuration"]()
  local config_max = config.MaxHeight
  if config_max <= 0 then
    config_max = nil
  end
  return config_max or vim.o.lines / 3
end

function drawer.go_to_window()
  local nr = drawer.last_selected_index()
  local win = fn.bufwinnr(nr)
  if win == -1 then
    return false
  end

  exe({win .. "wincmd w"})
  drawer.kill(true)
  return true
end

function drawer.restore()
  exe({"pclose"})
  assert_drawer_off()
  drawer.show()
  drawer.setup_buffer()
  drawer.insert_content()
end

local function reset_window()
  vim.cmd([[
    call s:modes.Help.Disable()
    call s:modes.Nop.Disable()
    call s:modes.Search.Disable()
    call s:modes.NextTab.Disable()

    call s:modes.Buffer.Enable()
    call s:modes.Buffer.SetData("SubMode", "single")

    call s:modes.Search.SetData("NewSearchPerformed", 0)
    call s:modes.Search.SetData("Restored", 0)
    call s:modes.Search.SetData("Letters", [])
    call s:modes.Search.SetData("HistoryIndex", -1)

    call s:modes.Workspace.SetData("LastBrowsed", 0)

    call ctrlspace#roots#SetCurrentProjectRoot(ctrlspace#roots#FindProjectRoot())
    call s:modes.Bookmark.SetData("Active", ctrlspace#bookmarks#FindActiveBookmark())

    call s:modes.Search.RemoveData("LastSearchedDirectory")

    if ctrlspace#roots#LastProjectRoot() != ctrlspace#roots#CurrentProjectRoot()
        call luaeval('require("ctrlspace").files.clear()')
        call ctrlspace#roots#SetLastProjectRoot(ctrlspace#roots#CurrentProjectRoot())
        call ctrlspace#workspaces#SetWorkspaceNames()
    endif

    set guicursor+=n:block-CtrlSpaceSelected-blinkon0

    call ctrlspace#util#HandleVimSettings("start")
  ]])
end

function drawer.toggle(internal)
  if not internal then
    reset_window()
  end
  
  local pbuf = drawer.buffer()
  if pbuf ~= -1 then
    if fn.winnr(pbuf) == -1 then
      drawer.kill(false)
      if not internal then
        save_tab_config()
      end
    end
  elseif not internal then
    exe({"pclose"})
    save_tab_config()
  end

  drawer.show()
  drawer.setup_buffer()
  drawer.insert_content()
end

function drawer.last_selected_index()
  local pbuf = drawer.buffer()
  if pbuf == -1 then
    error("ctrlspace plugin buffer does not exist")
  end

  local items = api.nvim_buf_get_var(pbuf, "items")
  if not items then
    error("no items loaded")
  end
  local idx
  if fn.bufnr() == pbuf then
    idx = fn.line(".")
  else
    idx = fn.getbufinfo(pbuf)[0].lnum
  end
  return items[idx].index
end

function drawer.go_start_window()
  exe({vim.t.CtrlSpaceStartWindow .. "wincmd w"})
  if fn.winrestcmd() == vim.t.CtrlSpaceWinrestcmd then
    return
  end
  exe({vim.t.CtrlSpaceWinrestcmd})
  if fn.winrestcmd() ~= vim.t.CtrlSpaceWinrestcmd then
    exe("wincmd =")
  end
end

function tabs.set_label(tabnr, label, auto)
  api.nvim_tabpage_set_var(tabnr, "CtrlSpaceLabel", label)
  api.nvim_tabpage_set_var(tabnr, "CtrlSpaceAutotab", auto)
end

function tabs.remove_label(tabnr)
  tabs.set_label(tabnr, "", 0)
  return true
end

function tabs.rename(tabnr)
  assert_drawer_on()
  local old_name = fn.gettabvar(tabnr, "CtrlSpaceLabel", nil)
  if not old_name or old_name == vim.NIL then
    old_name = ""
  end

  local new_label = ui.input("Label for tab " .. tabnr .. ": ", old_name, nil)

  if not new_label or new_label == "" then
    return false
  end

  tabs.set_label(tabnr, new_label, 0)
  return true
end

function tabs.ask_rename_selected()
  assert_drawer_on()
  local l = fn.line(".")
  local tabnr = drawer.last_selected_index()
  if not tabs.rename(tabnr) then
    return
  end
  drawer.refresh()
  drawer.move_selection_and_remember(l)
end

function tabs.remove_label_selected()
  assert_drawer_on()
  local l = fn.line(".")
  local tabnr = drawer.last_selected_index()
  tabs.remove_label(tabnr)
  drawer.refresh()
  drawer.move_selection_and_remember(l)
end

function tabs.new_label()
  assert_drawer_on()
  local l = fn.line(".")
  local tabnr = drawer.last_selected_index()
  local old_name = fn.gettabvar(tabnr, "CtrlSpaceLabel", nil)
  if not old_name or old_name == vim.NIL then
    old_name = ""
  end

  local new_label = ui.input("Label for tab " .. tabnr .. ": ", old_name, nil)

  if not new_label or new_label == "" then
    return
  end

  tabs.set_label(tabnr, new_label, 0)
  drawer.refresh()
  drawer.move_selection_and_remember(l)
end

function tabs.close()
  -- we don't close the last tab
  if fn.tabpagenr("$") == 1 then
    vim.cmd('echoerr "unable to delete last buffer"')
    return
  end

  local auto_tab = vim.t.CtrlSpaceAutotab

  if auto_tab and auto_tab ~= 0 then
    return
  end

  local label = vim.t.CtrlSpaceLabel
  if label and string.len(label) > 0 then
    local bufs = buffers_in_tab(fn.tabpagenr())
    local count = 0
    for _, _ in pairs(bufs) do
      count = count + 1
    end
    local prompt =
      "Close tab named '" .. label .. "' with " .. count .. " buffers?"
    if not ui.confirmed(prompt) then
      return
    end
  end

  drawer.kill(true)

  exe({"tabclose"})

  fn["ctrlspace#buffers#DeleteHiddenNonameBuffers"](1)
  fn["ctrlspace#buffers#DeleteForeignBuffers"](1)
  drawer.restore()
end

function tabs.collect_unsaved()
  local unsaved = buffers.unsaved()
  if #unsaved == 0 then
    vim.cmd('echomsg "there are no unsaved buffers"')
    return
  end

  drawer.toggle(0)
  exe({'tabnew'})
  local tab = fn.tabpagenr()
  tabs.set_label(tab, "Unsaved Buffers", 1)
  for _, b in ipairs(unsaved) do
    vim.cmd("silent! :b " .. b)
  end
  drawer.restore()
end

function tabs.collect_foreign()
  local foreign = buffers.foreign()
  if #foreign == 0 then
    vim.cmd("echoerr 'There are no foreign buffers'")
  end

  drawer.toggle(0)
  exe({'tabnew'})
  local tab = fn.tabepagenr()
  tabs.set_label(tab, "Foreign Buffers", 1)

  exe(foreign)
  -- TODO what attaches these buffers to the new tab? Is there a BufEnter
  -- autocmd firing?
  for fb, _ in ipairs(foreign) do
    exe({":b " .. fb})
  end
  drawer.restore()
end

function tabs.move(key)
  local nr = drawer.last_selected_index()
  with_restore_drawer(function()
    exe({"normal! " .. nr .. "gt"})
    fn["ctrlspace#keys#tab#MoveHelper"](key)
    vim.cmd[[
      let modes = ctrlspace#modes#Modes()
      call modes.Tab.Enable()
    ]]
  end)
end

function drawer.selected_file_path()
  local modes = fn["ctrlspace#modes#Modes"]()
  if modes.File.Enabled == 1 then
    local idx = drawer.last_selected_index()
    return M.files.collect()[idx].text
  elseif modes.Buffer.Enabled == 1 then
    local idx = drawer.last_selected_index()
    return fn.resolve(fn.bufname(idx))
  else
    error("selected_file_path doesn't work in this mode")
  end
end

function drawer.kill(final)
  assert_drawer_on()
  if vim.b.updatetime_save then
    vim.o.updatetime = vim.b.updatetime_save
  end

  if vim.b.timeoutlen_save then
    vim.o.timeoutlen = vim.b.timeoutlen_save
  end

  if vim.b.mouse_save then
    vim.o.mouse = vim.b.mouse_save
  end

  exe({"bwipeout"})

  if final then
    fn["ctrlspace#util#HandleVimSettings"]("stop")
    local modes = fn["ctrlspace#modes#Modes"]()
    if modes.Search.Data.Restored == 1 then
      fn["ctrlspace#search#AppendToSearchHistory"]()
    end
    drawer.go_start_window()
    exe({"set guicursor-=n:block-CtrlSpaceSelected-blinkon0"})
  end
end

local function goto_line(l)
  if vim.b.size < 1 then
    return
  end

  if l < 1 then
    goto_line(vim.b.size - l)
  elseif l > vim.b.size then
    goto_line(l - vim.b.size)
  else
    fn.cursor(l, 1)
  end
end

function drawer.move_selection(where)
  local line = fn.line(".")

  local delta
  if where == "up" then
    delta = -1
  elseif where == "down" then
    delta = 1
  elseif where == "pgup" then
    delta = -fn.winheight("0")
  elseif where == "pgdown" then
    delta = fn.winheight("0")
  elseif where == "half_pgup" then
    delta = -math.floor(fn.winheight("0") / 2)
  elseif where == "half_pgdown" then
    delta = math.floor(fn.winheight("0") / 2)
  else
    delta = -line + where
  end

  local newpos = line + delta
  newpos = math.min(newpos, fn.line("$"))
  newpos = math.max(newpos, 1)
  goto_line(newpos)
end

function drawer.move_selection_and_remember(where)
  assert_drawer_on()
  if vim.b.size < 1 then
    return
  end

  if not vim.b.lastline then
    vim.b.lastline = 0
  end

  drawer.move_selection(where)

  vim.b.lastline = fn.line(".")
end

function ui.confirm_if_modified()
  local unsaved = #buffers.unsaved()
  if #unsaved == 0 then
    return true
  else
    return ui.confirmed(#unsaved .. " buffers are unsaved. Proceed anyway?")
  end
end

function tabs.copy_or_move_selected_buffer(tabnr, copy_or_move)
  local bufnr = drawer.last_selected_index()
  if copy_or_move == "move" then
    detach_buffer(bufnr)
  end

  tabs.add_buffer(tabnr, bufnr)
  drawer.kill(false)
  exe({"normal! " .. tabnr .. "gt"})
  drawer.restore()

  local bname = fn.bufname(bufnr)
  for i in ipairs(vim.b.items) do
    if fn.bufname(i.index) == bname then
      -- TODO this is all suspicious and wrong. We just need to move the cursor to where
      -- the buffer we inserted exists
      -- drawer.move_selection_and_remember(i + 1)
      exe({"b " .. i.index})
      break
    end
  end
end

function util.chdir(dir)
  dir = fn.fnameescape(dir)
  local tab = fn.tabpagenr()
  local win = fn.winnr()

  exe({"cd " .. dir})
  for tabnr=1, fn.tabpagenr("$") do
    exe({"noautocmd tabnext " .. tabnr})
    if fn.haslocaldir() then
      exe({"lcd " .. dir})
    end
  end

  exe({
    "noautocmd tabnext " .. tab,
    "noautocmd " .. win .. "wincmd w"
  })
end

function util.normalize_dir(dir)
  dir = fn.resolve(fn.expand(dir))
  local is_slash = function (d)
    local last = string.sub(d, -1)
    return last == '\\' or last == '/'
  end
  while is_slash(dir) do
    dir = string.sub(dir, 1, -2)
  end
  return dir
end

function util.project_local_file(name)
  local config = fn["ctrlspace#context#Configuration"]()
  local root = fn["ctrlspace#roots#CurrentProjectRoot"]()
  if root ~= "" then
    root = root .. "/"
  end
  for _, marker in ipairs(config.ProjectRootMarkers) do
    local candidate = root .. marker
    if fn.isdirectory(candidate) then
      return candidate .. "/" .. name
    end
  end
  return root .. "." .. name
end

function bookmarks.add_new(dir)
  dir = ui.input("Add directroy to bookmarks: ", dir, "dir")
  if not dir or string.len(dir) == 0 then
    return
  end

  dir = fn["ctrlspace#util#NormalizeDirectory"](dir)

  if fn.isdirectory(dir) == 0 then
    print(string.format("Directory '%s' is invalid", dir))
    return
  end

  local bms = fn['ctrlspace#bookmarks#Bookmarks']()
  for _, bm in ipairs(bms) do
    if bm.Directory == dir then
      print(string.format(
        "Directory '%s' is already bookmarked under the name '%s'", dir, bm.Name))
      return
    end
  end

  local name = ui.input("New bookmark name: ", fn.fnamemodify(dir, ":t"))

  if not name or string.len(name) == 0 then
    return
  end

  fn['ctrlspace#bookmarks#AddToBookmarks'](dir, name)
  print(string.format("Directory '%s' has been bookmarked under the name '%s'", dir, name))
  drawer.refresh()
end

return M
