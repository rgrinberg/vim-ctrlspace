local fzy = require("fzy_lua")

function _G.ctrlspace_filter(candidates, query, max)
  if query == "" then
    return candidates
  end

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
      table.insert(top, results[i])
    else
      break
    end
  end
  return top
end
