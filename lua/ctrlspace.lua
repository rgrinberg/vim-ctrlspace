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
    return x.score < y.score
  end)

  local top = {}
  for i=1, max do
    if results[i] then
      local r = results[i]
      local positions = fzy.positions(query, r.text)
      local start = positions[1]
      local stop = positions[#positions]
      r.pattern = string.sub(r.text, start, stop)
      table.insert(top, r)
    else
      break
    end
  end
  return top
end
