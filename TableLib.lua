-- table方法添加
table.isArray = table.isArray or function(tab)
  if (type(tab) ~= "table") then
    return false
  end
  local length = #tab
  for k, v in pairs(tab) do
    if ((type(k) ~= "number") or (k > length)) then
      return false
    end
  end
  return true
end

table.every = table.every or function(tab)
  for k, v in ipairs(tab) do
    if (v == false) then
      return false
    end
  end
  return true
end

table.some = table.some or function(tab)
  for k, v in ipairs(tab) do
    if (v == true) then
      return true
    end
  end
  return false
end

table.push = table.push or function(tab, element)
  table.insert(tab, element)
  local length = #tab
  return length
end

table.pop = table.pop or function(tab)
  local length = #tab
  local res = tab[length]
  table.remove(tab, length)
  return res
end

table.shift = table.shift or function(tab)
  local res = tab[1]
  table.remove(tab, 1)
  return res
end

table.unshift = table.unshift or function(tab, element)
  table.insert(tab, 1, element)
  local length = #tab
  return length
end

table.first = table.first or function(tab)
  return tab[1]
end

table.last = table.last or function(tab)
  return tab[#tab]
end

table.slice = table.slice or function(tab, startIndex, endIndex)
  local length = #tab
  if ((type(endIndex) == "nil") or (endIndex == 0)) then
    endIndex = length
  end
  if (endIndex < 0) then
    endIndex = length + 1 + endIndex
  end
  local newTab = {}

  for i = startIndex, endIndex do
    table.insert(newTab, tab[i])
  end

  return newTab
end

table.join = table.join or function(tab, exp)
  if (type(exp) == "nil") then exp = "," end
  return table.concat(tab, exp)
end

table.merge = table.merge or function(tab, ...)
  arg = { ... }
  for k, tabelement in ipairs(arg) do
    local length = #tabelement
    for k2, value in ipairs(tabelement) do
      if ((type(k2) == "number") and (k2 <= length)) then
        table.insert(tab, value)
      end
    end
    for k2, value in pairs(tabelement) do
      if ((type(k2) == "number") and (k2 <= length)) then
      else
        tab[k2] = value
      end
    end
  end
  return tab
end

table.map = table.map or function(tab, callback)
  if (type(callback) ~= 'function') then return tab end
  local newTab = {}
  for k, v in ipairs(tab) do
    table.insert(newTab, callback(v))
  end
  return values
end

table.forEach = table.forEach or function(tab, callback)
  if (type(callback) ~= 'function') then return end
  for k, v in ipairs(tab) do
    callback(v)
  end
end

table.values = table.values or function(tab)
  local values = {}
  for k, v in pairs(tab) do
    table.insert(values, v)
  end
  return values
end

table.keys = table.keys or function(tab)
  local keys = {}
  for k in pairs(tab) do
    table.insert(keys, k)
  end
  return keys
end

-- 将每一组键值对变成数组，再放入一个大数组中返回
table.entries = table.entries or function(tab)
  local ent = {}
  for k, v in pairs(tab) do
    table.insert(ent, { k, v })
  end
  return ent
end

-- 对key排序后放入数组中再返回，结果类似entries
table.sortByKey = table.sortByKey or function(tab, call)
  local keys = table.keys(tab)
  if (type(call) == "function") then
    table.sort(keys, call)
  else
    table.sort(keys)
  end
  local newTable = {}
  for _, key in ipairs(keys) do
    table.insert(newTable, { key, tab[key] })
  end
  return newTable
end

table.toString = table.toString or function(tab, space)
  if ((type(tab) == "function")) then
    return "[function]"
  end
  if ((type(tab) == "number") or (type(tab) == "string")) then
    return "" .. tab
  end
  if (type(tab) == "boolean") then
    return tab and "true" or "false"
  end
  if (type(tab) == "nil") then
    return "no message"
  end
  if (type(tab) ~= "table") then
    return "[" .. type(tab) .. "]"
  end
  if (type(space) ~= "string") then
    space = ""
  end
  local newTab = {}
  local childSpace = space .. "  "
  for k, v in pairs(tab) do
    table.insert(newTab, childSpace .. k .. ": " .. table.toString(v, childSpace))
  end
  return "{\n" .. table.concat(newTab, ", \n") .. " \n" .. space .. "}"
end

table.toJsString = table.toJsString or function(tab, other, space)
  if ((type(tab) == "function")) then
    return "[function]"
  end
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
    return "[" .. type(tab) .. "]"
  end
  if (type(space) ~= "string") then
    space = ""
  end
  local isArray = table.isArray(tab)
  local newTab = {}
  local childSpace = space .. "  "
  if (isArray) then
    for k, v in ipairs(tab) do
      table.insert(newTab, table.toJsString(v, other, childSpace))
    end
    local childStr = table.concat(newTab, ", ")

    if (string.len(childStr) > 50) then
      newTab = {}
      for k, v in ipairs(tab) do
        table.insert(newTab, childSpace .. table.toJsString(v, other, childSpace))
      end
      childStr = table.concat(newTab, ", \n")
      return "[\n" .. childStr .. " \n" .. childSpace .. "]"
    end

    return space .. "[" .. childStr .. "]"
  else
    for k, v in pairs(tab) do
      if ((other == true) or (type(v) ~= "function")) then
        table.insert(newTab, childSpace .. k .. ": " .. table.toJsString(v, childSpace))
      end
    end
    return "{\n" .. table.concat(newTab, ", \n") .. " \n" .. space .. "}"
  end
end

table.unpack = unpack or table.unpack