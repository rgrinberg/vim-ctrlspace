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

local files = {}
local buffers = {}

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

buffers.in_tab = function ()

end

buffers.all = function ()

end

local M = {}
M.files = files
M.buffers = buffers
return M
