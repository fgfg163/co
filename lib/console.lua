local __console = console or {}

local function runTable(tab, space)
  if (type(tab) == "number") then
    return "" .. tab
  end
  if (type(tab) == "string") then
    return '"' .. tab .. '"'
  end
  if (type(tab) == "boolean") then
    return tab and "true" or "false"
  end
  if (type(tab) == "nil") then
    return "no message"
  end
  if (type(tab) ~= "table") then
    return "(" .. type(tab) .. ")"
  end
  if (type(space) ~= "string") then
    space = ""
  end
  local isArray = table.isArray(tab)
  local newTab = {}
  local childSpace = space .. "  "
  if (isArray) then
    for k, v in ipairs(tab) do
      table.insert(newTab, runTable(v, childSpace))
    end
    local childStr = table.concat(newTab, ", ")

    if (string.len(childStr) > 50) then
      newTab = {}
      for k, v in ipairs(tab) do
        table.insert(newTab, childSpace .. runTable(v, childSpace))
      end
      childStr = table.concat(newTab, ", \n")
      return "[\n" .. childStr .. " \n" .. childSpace .. "]"
    end

    return space .. "[" .. childStr .. "]"
  else
    for k, v in pairs(tab) do
      table.insert(newTab, childSpace .. k .. ": " .. runTable(v, childSpace))
    end
    return "{\n" .. table.concat(newTab, ", \n") .. " \n" .. space .. "}"
  end
end

__console.log = __console.log or function(obj)
  local js = runTable(obj)
  print(js)
  return js
end

console = __console