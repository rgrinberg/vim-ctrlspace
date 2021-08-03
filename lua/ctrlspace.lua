local fzy = require("fzy_lua")

function _G.ctrlspace_filter(candidates, query, max)
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

local M = {}

local files = {}
local buffers = { api = {} }
local tabs = {}
local drawer = {}

M.files = files
M.buffers = buffers
M.tabs = tabs
M.drawer = drawer

local files_cache = nil

files.clear = function ()
  files = nil
end

local function buffer_name(bufnr)
  local name = vim.fn.fnamemodify(vim.fn.bufname(bufnr), ":.")
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

files.collect = function ()
  if files_cache then
    return files_cache
  end
  local output = vim.fn["ctrlspace#util#system"](glob_cmd())
  local res = {}
  local i = 0
  for s in string.gmatch(output, "[^\r\n]+") do
    local m = {
      text = vim.fn.fnamemodify(s, ":."),
      index = i,
      indicators = "",
    }
    table.insert(res, m)
    i = i + 1
  end
  files_cache = res
  return files_cache
end

local getbufvar = vim.fn.getbufvar

-- TODO use this helper consistently
local function exe(cmds)
  for _, cmd in ipairs(cmds) do
    vim.cmd('silent! ' .. cmd)
  end
end

local function plugin_buffer(buf)
  return getbufvar(buf, "&ft") == "ctrlspace"
end

local function managed_buf(buf)
  return vim.fn.buflisted(buf) and not plugin_buffer(buf)
end

buffers.add_current = function ()
  local current = vim.fn.bufnr('%')

  if not managed_buf(current) then
    return
  end

  local modes = vim.fn["ctrlspace#modes#Modes"]()

  vim.b.CtrlSpaceJumpCounter = vim.fn["ctrlspace#jumps#IncrementJumpCounter"]()

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
  for _, buf in pairs(vim.api.nvim_list_bufs()) do
    if managed_buf(buf) then
      res[buf] = true
    end
  end
  return res
end

local function buffer_modified(bufnr)
  return getbufvar(bufnr, "&modified") == 1
end

buffers.unsaved = function()
  local res = {}
  for b, _ in ipairs(all_buffers()) do
    if buffer_modified(b) and managed_buf(b) then
      table.insert(res, b)
    end
  end
  return res
end

local function raw_buffers_in_tab(tabnr)
  return vim.fn.gettabvar(tabnr, "CtrlSpaceList", {})
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
--   for tabnr=1,vim.fn.tabpagenr("$") do
--     local tab_buffers = vim.fn.tabpagebuflist(tabnr)
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
  for tabnr=1,vim.fn.tabpagenr("$") do
    local in_tab_list = buffers_in_tab(tabnr)[bufnr]
    if in_tab_list then
      local visible_buffers = vim.fn.tabpagebuflist(tabnr)
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

local function assert_drawer_off()
  -- TODO implement
end

local function assert_drawer_on()
  -- TODO implement
end

-- you must restore the view after calling this function
local function forget_buffer_in_tab(tabnr, bufnr)
  assert_drawer_off()
  local curtab = vim.fn.tabpagenr()
  if curtab ~= tabnr then
    exe({"tabn " .. tabnr})
  end
  local winnr = vim.fn.bufwinnr(bufnr)
  local new_buf = nil
  while winnr ~= -1 do
    exe({winnr .. "wincmd w"})

    -- this ensures that we create at most one new buffer per forget
    local next_buf = new_buf or tabs.next_buf(tabnr, bufnr)

    if next_buf then
      exe({"b! " .. next_buf})
    else
      exe({"enew"})
      new_buf = vim.fn.bufnr()
    end
    winnr = vim.fn.bufwinnr(bufnr)
  end
  tabs.remove_buffers(tabnr, {bufnr})
end

local function with_restore_drawer(f)
  assert_drawer_on()
  local curln = vim.fn.line(".")
  vim.fn["ctrlspace#window#Kill"](0)
  f()
  vim.fn["ctrlspace#window#Toggle"](1)
  vim.fn["ctrlspace#window#MoveSelectionBar"](curln)
end

local function delete_buffer(bufnr)
  local modified = buffer_modified(bufnr)
  if modified and not vim.fn['ctrlspace#ui#Confirmed'](
    "The buffer contains unsaved changes. Proceed anyway?") then
    return
  end

  with_restore_drawer(function ()
    local in_tabs = find_buffer_in_tabs(bufnr)
    local curtab = vim.fn.tabpagenr()
    for t, _ in pairs(in_tabs) do
      forget_buffer_in_tab(t, bufnr)
    end

    -- why aren't we using wipeout like elsewhere?
    exe({
      "bdelete! " .. bufnr,
      "tabn " .. curtab,
    })
  end)
end

function buffers.delete ()
  local bufnr = vim.fn["ctrlspace#window#SelectedIndex"]()
  delete_buffer(bufnr)
end

local function detach_buffer(bufnr)
  local modified = buffer_modified(bufnr)
  if modified and not vim.fn['ctrlspace#ui#Confirmed'](
    "The buffer contains unsaved changes. Proceed anyway?") then
    return
  end

  with_restore_drawer(function ()
    local curtab = vim.fn.tabpagenr()
    forget_buffer_in_tab(curtab, bufnr)
  end)
end

function buffers.detach()
  local bufnr = vim.fn["ctrlspace#window#SelectedIndex"]()
  detach_buffer(bufnr)
end

function buffers.close_buffer()
  local bufnr = vim.fn["ctrlspace#window#SelectedIndex"]()
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

buffers.in_all_tabs = function()
  local res = {}
  for tabnr=1,vim.fn.tabpagenr("$") do
    for _, b in ipairs(buffers.in_tab(tabnr)) do
      res[b] = true
    end
  end
  return res
end

buffers.all = function ()
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
  for tabnr=1,vim.fn.tabpagenr("$") do
    for _, b in ipairs(buffers.in_tab(tabnr)) do
      bufs[b] = nil
    end
  end
  return bufs
end

buffers.foreign = function ()
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

buffers.visible = function ()
  local res = {}
  for tabnr=1,vim.fn.tabpagenr("$") do
    for _, b in ipairs(vim.fn.tabpagebuflist(tabnr)) do
      if managed_buf(b) then
        res[b] = true
      end
    end
  end
  return res
end

buffers.unnamed = function ()
  local res = {}
  for _, b in ipairs(buffers.all()) do
    if managed_buf(b)
      and vim.fn.bufexists(b)
      and (not getbufvar(b, "&buftype")
      or vim.fn.filereadable(vim.fn.bufname(b))) then
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
  for tabnr=1,vim.fn.tabpagenr("$") do
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
  local config = vim.fn["ctrlspace#context#Configuration"]()
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
    vim.fn.settabvar(tabnr, "CtrlSpaceList", bufs_in_tab)
  end
end

tabs.forget_buffers = function (bufs)
  for tabnr=1,vim.fn.tabpagenr("$") do
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
  vim.fn.settabvar(tabnr, "CtrlSpaceList", btabs)
end

drawer.buffer = function()
  for _, buf in pairs(vim.api.nvim_list_bufs()) do
    if plugin_buffer(buf) then
      return buf
    end
  end
  return -1
end

function buffers.load(pre)
  local nr = vim.fn["ctrlspace#window#SelectedIndex"]()
  vim.fn["ctrlspace#window#kill"]()
  exe(pre)
  exe({"b " .. nr})
end

function buffers.load_keep(pre, post)
  local nr = vim.fn["ctrlspace#window#SelectedIndex"]()
  local curln = vim.fn.line(".")

  vim.fn["ctrlspace#window#hide"]()
  vim.fn["ctrlspace#window#GoToStartWindow"]()
  exe(pre)
  exe({"b " .. nr})
  vim.cmd("normal! zb")
  exe(post)
  vim.fn["ctrlspace#window#restore"]()
  vim.fn["ctrlspace#window#MoveSelectionBar"](curln)
end

local function help_filler()
  return string.rep(" ", vim.o.columns) .. "\n"
end

local item = {}

item.create = function(index, text, indicators)
  return {
    index = index,
    text = text,
    indicators = indicators,
  }
end

local function bookmark_items()
  local config = vim.fn["ctrlspace#context#Configuration"]()

  local bookmarks = vim.fn['ctrlspace#bookmarks#Bookmarks']()
  local active = vim.fn['ctrlspace#bookmarks#FindActiveBookmark']()

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
  local workspaces = vim.fn["ctrlspace#workspaces#Workspaces"]()
  local active = vim.fn["ctrlspace#workspaces#ActiveWorkspace"]()
  local config = vim.fn["ctrlspace#context#Configuration"]()

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
  local config = vim.fn["ctrlspace#context#Configuration"]()
  local current_tab = vim.fn.tabpagenr()

  local res = {}
  for tabnr=1,vim.fn.tabpagenr("$") do
    local indicators = ""

    local tab_buffer_number = vim.fn["ctrlspace#api#TabBuffersNumber"](tabnr)
    local title = vim.fn["ctrlspace#api#TabTitle"](tabnr)

    if vim.fn["ctrlspace#api#TabModified"](tabnr) ~= 1 then
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
  local config = vim.fn["ctrlspace#context#Configuration"]()

  if submode == "single" then
    bufs = buffers_in_tab(vim.fn.tabpagenr())
  elseif submode == "all" then
    bufs = all_buffers()
  elseif submode == "visible" then
    bufs = {}
    for buf, _ in raw_buffers_in_tab(vim.fn.tabeagenr()) do
      if vim.fn.bufwinnr(buf) ~= -1 then
        bufs[buf] = true
      end
    end
  else
    error("invalid mode " .. submode)
  end

  for bufnr, _ in pairs(bufs) do
    local name = buffer_name(bufnr)
    local modified = buffer_modified(bufnr)
    local winnr = vim.fn.bufwinnr(bufnr)

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
  local clv = vim.fn["ctrlspace#modes#CurrentListView"]()

  if clv.Name == "Buffer" then
    return buffer_items(clv)
  elseif clv.Name == "File" then
    return vim.fn["ctrlspace#files#CollectFiles"]()
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
  local config = vim.fn["ctrlspace#context#Configuration"]()
  local modes = vim.fn["ctrlspace#modes#Modes"]()
  local sizes = vim.fn["ctrlspace#context#SymbolSizes"]()

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

drawer.content = function ()
  local absolute_max = 500
  local candidates = content_source()
  local modes = vim.fn["ctrlspace#modes#Modes"]()
  local query = table.concat(modes.Search.Data.Letters, "")
  if query == "" then
    if #candidates > absolute_max then
      candidates = { unpack(candidates, 1, absolute_max) }
    end
  else
    local max
    if modes.Search.Enabled == 1 then
      max = vim.fn["ctrlspace#window#MaxHeight"]()
    else
      max = absolute_max
    end
    candidates = ctrlspace_filter(candidates, query, max)
  end

  return candidates
end

local function save_tab_config()
  vim.t.CtrlSpaceStartWindow = vim.fn.winnr()
  vim.t.CtrlSpaceWinrestcmd  = vim.fn.winrestcmd()
  vim.t.CtrlSpaceActivebuf   = vim.fn.bufnr("")
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
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, text)
    for _, i in ipairs(items) do
      if i.positions then
        for _, hl in ipairs(i.positions) do
          vim.api.nvim_buf_add_highlight(0, -1, "CtrlSpaceSearch", line, hl + 1, hl + 2)
        end
      end
      line = line + 1
    end
  else
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, {"  List empty"})
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
  local config = vim.fn["ctrlspace#context#Configuration"]()
  local modes = vim.fn["ctrlspace#modes#Modes"]()
  exe({'resize ' .. config.Height})
  if modes.Help.Enabled == 1 then
    vim.fn["ctrlspace#help#DisplayHelp"](help_filler())
    vim.fn["ctrlspace#util#SetStatusline"]()
    return
  end

  local items = drawer.content()

  -- for backwards compat
  vim.b.items = items
  vim.b.size = #items

  if #items > config.Height then
    local max_height = vim.fn["ctrlspace#window#MaxHeight"]()
    local size
    if #items < max_height then
      size = #items
    else
      size = max_height
    end
    exe({'resize ' .. size})
  end

  drawer_display(items)
  vim.fn["ctrlspace#util#SetStatusline"]()
  vim.fn["ctrlspace#window#setActiveLine"]()
  vim.cmd("normal! zb")
end

function drawer.refresh ()
  local last_line = vim.fn.line("$")
  vim.cmd('setlocal modifiable')
  vim.api.nvim_buf_set_lines(0, 0, last_line, 0, {})
  vim.cmd('setlocal nomodifiable')
  drawer.insert_content()
end

function drawer.setup_buffer ()
  assert_drawer_on()
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
  local root = vim.fn["ctrlspace#roots#CurrentProjectRoot"]()

  if root then
    exe({"lcd " .. vim.fn.fnameescape(root)})
  end

  if vim.o.timeout then
    vim.b.timeout_save = vim.o.timeoutlen
    vim.o.timeoutlen = 10
  end

  local config = vim.fn["ctrlspace#context#Configuration"]()

  vim.b.updatetime_save = vim.o.updatetime
  vim.o.updatetime = config.SearchTiming

  if not config.UseMouseAndArrowsInTerm and not vim.fn.has("gui_running") then
    vim.cmd([[
        " Block unnecessary escape sequences!
        noremap <silent><buffer><esc>[ :call ctrlspace#keys#MarkKeyEscSequence()<CR>
        let b:mouseSave = &mouse
        set mouse=
    ]])
  end

  for _, k in ipairs(vim.fn["ctrlspace#keys#KeyNames"]()) do
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
  local config = vim.fn["ctrlspace#context#Configuration"]()
  local config_max = config.MaxHeight
  if config_max <= 0 then
    config_max = nil
  end
  return config_max or vim.o.lines / 3
end

function drawer.go_to_window()
  local nr = vim.fn["ctrlspace#window#SelectedIndex"]()
  local win = vim.fn.bufwinnr(nr)
  if win == -1 then
    return false
  end

  vim.fn["ctrlspace#window#kill"]()
  vim.cmd("silent! " .. win .. "wincmd w")
  return true
end

function drawer.restore()
  vim.cmd("silent! pclose")
  assert_drawer_off()
  drawer.show()
  drawer.setup_buffer()
  drawer.insert_content()
end

return M
