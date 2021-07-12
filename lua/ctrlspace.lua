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
    local positions = fzy.positions(query, r.text)
    local start = positions[1]
    local stop = positions[#positions]
    r.pattern = string.sub(r.text, start, stop)
    table.insert(top, r)
  end
  return top
end
