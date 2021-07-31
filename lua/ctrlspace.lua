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
local buffers = {}
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
  if modes.Zoom.Enabled == 1 then
    return
  end

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

buffers.unsaved = function()
  local res = {}
  for b, _ in ipairs(all_buffers()) do
    if getbufvar(b, "&modified") and managed_buf(b) then
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

tabs.forget_buffers = function (bufs)
  for tabnr=1,vim.fn.tabpagenr("$") do
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

-- TODO use this helper consistently
local function exe(cmd)
  vim.cmd('silent! exe :' .. cmd)
end

function buffers.load(pre)
  local nr = vim.fn["ctrlspace#window#SelectedIndex"]()
  vim.fn["ctrlspace#window#kill"]()
  for _, c in ipairs(pre) do
    exe(c)
  end
  exe("b " .. nr)
end


-- TODO implement this function properly
local function help_filler()
  local fill = "\n"
  local i = 0
  while i < vim.o.columns do
    i = i + 1
    fill = ' ' .. fill
  end
  return fill
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
    local name = vim.fn.fnamemodify(vim.fn.bufname(bufnr), ":.")
    local modified = getbufvar(bufnr, "&modified") == 1
    local winnr = vim.fn.bufwinnr(bufnr)

    if name == "" and (modified or winnr ~= -1) then
      name = "[" .. bufnr .. "*No Name]"
    end

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
    line = "  " .. line .. "\n"

    table.insert(res, line)
  end

  return table.concat(res, "")
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

  local content = render_candidates(candidates)
  return {candidates, content}
end

drawer.insert_content = function ()
  local config = vim.fn["ctrlspace#context#Configuration"]()
  local modes = vim.fn["ctrlspace#modes#Modes"]()
  vim.cmd('silent! exe "resize" ' .. config.Height)
  if modes.Help.Enabled == 1 then
    vim.fn["ctrlspace#help#DisplayHelp"](help_filler())
    vim.fn["ctrlspace#util#SetStatusline"]()
    return
  end

  local content = drawer.content()
  local items = content[1]
  local text = content[2]

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
    vim.cmd('silent! exe "resize "' .. size)
  end

  vim.o.updatetime = config.SearchTiming

  vim.fn["ctrlspace#window#displayContent"](items, text)
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

return M
