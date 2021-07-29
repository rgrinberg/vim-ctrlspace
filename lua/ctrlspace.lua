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
M.files = files
M.buffers = buffers

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

local function managed_buf(buf)
  local getbufvar = vim.fn.getbufvar
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

buffers.in_tab = function (tabnr)
  local res = {}
  for k, _ in pairs(vim.fn.gettabvar(tabnr, "CtrlSpaceList", {})) do
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

return M
