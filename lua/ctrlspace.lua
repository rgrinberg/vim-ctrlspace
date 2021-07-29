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

M.files = files
M.buffers = buffers
M.tabs = tabs

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

local function managed_buf(buf)
  return getbufvar(buf, "&buflisted") or getbufvar(buf, "&ft") ~= "ctrlspace"
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

local function filter_unlisted_buffers(bufs)
  local res = {}
  for _, b in ipairs(bufs) do
    if vim.fn.buflisted(b) then
      table.insert(res, b)
    end
  end
  return res
end

local function tab_buffers(tabnr)
  return vim.fn.gettabvar(tabnr, "CtrlSpaceList", {})
end

buffers.unsaved = function()
  local res = {}
  for _, b in ipairs(buffers.all()) do
    if getbufvar(b, "&modified") and managed_buf(b) then
      table.insert(res, b)
    end
  end
  return res
end

-- TODO this should exist in the tabs module
buffers.in_tab = function (tabnr)
  local res = {}
  for k, _ in pairs(tab_buffers(tabnr)) do
    table.insert(res, tonumber(k))
  end
  return res
end

buffers.all = function ()
  local res = {}
  for _, buf in pairs(vim.api.nvim_list_bufs()) do
    if managed_buf(buf) then
      table.insert(res, buf)
    end
  end
  return filter_unlisted_buffers(res)
end

buffers.foreign = function ()
  local bufs =  {}
  for _, i in ipairs(buffers.all()) do
    bufs[i] = true
  end
  for tabnr=1,vim.fn.tabpagenr("$") do
    for _, b in ipairs(buffers.in_tab(tabnr)) do
      bufs[b] = nil
    end
  end
  local res = {}
  for i, _ in pairs(bufs) do
    table.insert(res, i)
  end
  return res
end

tabs.forget_buffers = function (bufs)
  for tabnr=1,vim.fn.tabpagenr("$") do
    local bufs_in_tab = buffers.in_tab(tabnr)
    local modified = false
    for _, key in ipairs(bufs) do
      if bufs_in_tab[key] then
        modified = true
        bufs_in_tab[key] = nil
      end
    end
    if modified then
      vim.t.CtrlSpaceList = bufs_in_tab
    end
  end
end

return M
