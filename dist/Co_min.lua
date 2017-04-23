

do

do
local _ENV = _ENV
package.preload[ "lib/Promise" ] = function( ... ) local arg = _G.arg;
-----------------------------------------------------------------------------
-- ES6 Promise in lua v1.1
-- Author: aimingoo@wandoujia.com
-- Copyright (c) 2015.11
--
-- The promise module from NGX_4C architecture
-- 1) N4C is programming framework.
-- 2) N4C = a Controllable & Computable Communication Cluster architectur.
--
-- Promise module, ES6 Promises full supported. @see:
-- 1) https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise
-- 2) http://liubin.github.io/promises-book/#ch2-promise-resolve
--
-- Usage:
-- promise = Promise.new(executor)
-- promise:andThen(onFulfilled1):andThen(onFulfilled2, onRejected2)
--
-- History:
-- 2015.10.29	release v1.1, fix some bugs and update testcases
-- 2015.08.10	release v1.0.1, full testcases, minor fix and publish on github
-- 2015.03		release v1.0.0
-----------------------------------------------------------------------------

local Promise, promise = {}, {}

-- andThen replacer
--  1) replace standard .then() when promised
local PENDING = {}
local nil_promise = {}

local function promised(value, action)
  local ok, result = pcall(action, value)
  return ok and Promise.resolve(result) or Promise.reject(result) -- .. '.\n' .. debug.traceback())
end

local function promised_s(self, onFulfilled)
  return onFulfilled and promised(self, onFulfilled) or self
end

local function promised_y(self, onFulfilled)
  return onFulfilled and promised(self[1], onFulfilled) or self
end

local function promised_n(self, _, onRejected)
  return onRejected and promised(self[1], onRejected) or self
end

-- inext() list all elementys in array
--	*) next() will list all members for table without order
--	*) @see iter(): http://www.lua.org/pil/7.3.html
local function inext(a, i)
  i = i + 1
  local v = a[i]
  if v then return i, v end
end

-- put resolved value to p[1], or push lazyed calls/object to p[]
--	1) if resolved a no pending promise, direct call promise.andThen()
local function nothing(x) return x end

local function resolver(this, resolved, sure)
  local typ = type(resolved)
  if (typ == 'table' and resolved.andThen) then
    local lazy = {
      this,
      function(value) return resolver(this, value, true) end,
      function(reason) return resolver(this, reason, false) end
    }
    if resolved[1] == PENDING then
      table.insert(resolved, lazy) -- lazy again
    else -- deep resolve for promise instance, until non-promise
      resolved:andThen(lazy[2], lazy[3])
    end
  else -- resolve as value
    this[1], this.andThen = resolved, sure and promised_y or promised_n
    for i, lazy, action in inext, this, 1 do -- 2..n
      action = sure and (lazy[2] or nothing) or (lazy[3] or nothing)
      pcall(resolver, lazy[1], promised(resolved, action), sure)
      this[i] = nil
    end
  end
end

-- for Promise.all/race, ding coroutine again and again
local function coroutine_push(co, promises)
  -- push once
  coroutine.resume(co)

  -- and try push all
  --	1) resume a dead coroutine is safe always.
  -- 	2) if promises[i] promised, skip it
  local resume_y = function(value) coroutine.resume(co, true, value) end
  local resume_n = function(reason) coroutine.resume(co, false, reason) end
  for i = 1, #promises do
    if promises[i][1] == PENDING then
      promises[i]:andThen(resume_y, resume_n)
    end
  end
end

-- promise as meta_table of all instances
promise.__index = promise
-- reset __len meta-method
--	1) lua 5.2 or LuaJIT 2 with LUAJIT_ENABLE_LUA52COMPAT enabled
--	2) need table-len patch in 5.1x, @see http://lua-users.org/wiki/LuaPowerPatches
-- promise.__len = function() return 0 end

-- promise for basetype
local number_promise = setmetatable({ andThen = promised_y }, promise)
local true_promise = setmetatable({ andThen = promised_y, true }, promise)
local false_promise = setmetatable({ andThen = promised_y, false }, promise)
number_promise.__index = number_promise
nil_promise.andThen = promised_y
getmetatable('').__index.andThen = promised_s
getmetatable('').__index.catch = function(self) return self end
setmetatable(nil_promise, promise)

------------------------------------------------------------------------------------------
-- instnace method
-- 1) promise:andThen(onFulfilled, onRejected)
-- 2) promise:catch(onRejected)
------------------------------------------------------------------------------------------
function promise:andThen(onFulfilled, onRejected)
  local lazy = { { PENDING }, onFulfilled, onRejected }
  table.insert(self, lazy)
  return setmetatable(lazy[1], promise) -- <lazy[1]> is promise2
end

function promise:catch(onRejected)
  return self:andThen(nil, onRejected)
end

------------------------------------------------------------------------------------------
-- class method
-- 1) Promise.resolve(value)
-- 2) Promise.reject(reason)
-- 3) Promise.all()
------------------------------------------------------------------------------------------

-- resolve() rules:
--	1) promise object will direct return
-- 	2) thenable (with/without string) object
-- 		- case 1: direct return, or
--		- case 2: warp as resolved promise object, it's current selected.
-- 	3) warp other(nil/boolean/number/table/...) as resolved promise object
function Promise.resolve(value)
  local valueType = type(value)
  if valueType == 'nil' then
    return nil_promise
  elseif valueType == 'boolean' then
    return value and true_promise or false_promise
  elseif valueType == 'number' then
    return setmetatable({ (value) }, number_promise)
  elseif valueType == 'string' then
    return value
  elseif (valueType == 'table') and (value.andThen ~= nil) then
    return value.catch ~= nil and value -- or, we can direct return value
        or setmetatable({ catch = promise.catch }, { __index = value })
  else
    return setmetatable({ andThen = promised_y, value }, promise)
  end
end

function Promise.reject(reason)
  return setmetatable({ andThen = promised_n, reason }, promise)
end

function Promise.all(arr)
  local this, promises, count = setmetatable({ PENDING }, promise), {}, #arr
  local co = coroutine.create(function()
    local i, result, sure, last = 1, {}, true, 0
    while i <= count do
      local promise, typ, reason, resolved = promises[i], type(promises[i])
      if typ == 'table' and promise.andThen and promise[1] == PENDING then
        sure, reason = coroutine.yield()
        if not sure then
          return resolver(this, { index = i, reason = reason }, sure)
        end
        -- dont inc <i>, continue and try pick again
      else
        -- check reject/resolve of promsied instance
        --	*) TODO: dont access promise[1] or promised_n
        sure = (typ == 'string') or (typ == 'table' and promise.andThen ~= promised_n)
        resolved = (typ == 'string') and promise or promise[1]
        if not sure then
          return resolver(this, { index = i, reason = resolved }, sure)
        end
        -- pick result from promise, and push once
        result[i] = resolved
        if result[i] ~= nil then last = i end
        i = i + 1
      end
    end
    -- becuse 'result[x]=nil' will reset length to first invalid, so need reset it to last
    -- 	1) invalid: setmetatable(result, {__len=function() retun count end})
    -- 	2) obsoleted: table.setn(result, count)
    resolver(this, sure and { unpack(result, 1, last) } or result, sure)
  end)

  -- init promises and push
  for i, item in ipairs(arr) do promises[i] = Promise.resolve(item) end
  coroutine_push(co, promises)
  return this
end

function Promise.race(arr)
  local this, result, count = setmetatable({ PENDING }, promise), {}, #arr
  local co = coroutine.create(function()
    local i, sure, resolved = 1
    while i < count do
      local promise, typ = result[i], type(result[i])
      if typ == 'table' and promise.andThen and promise[1] == PENDING then
        sure, resolved = coroutine.yield()
      else
        -- check reject/resolve of promsied instance
        --	*) TODO: dont access promise[1] or promised_n
        sure = (typ == 'string') or (typ == 'table' and promise.andThen ~= promised_n)
        resolved = typ == 'string' and promise or promise[1]
      end
      -- pick resolved once only
      break
    end
    resolver(this, resolved, sure)
  end)

  -- init promises and push
  for i, item in ipairs(arr) do promises[i] = Promise.resolve(item) end
  coroutine_push(co, promises)
  return this
end

------------------------------------------------------------------------------------------
-- constructor method
-- 1) Promise.new(func)
-- (*) new() will try execute <func>, but andThen() is lazyed.
------------------------------------------------------------------------------------------
function Promise.new(func)
  local this = setmetatable({ PENDING }, promise)
  local ok, result = pcall(func,
    function(value) return resolver(this, value, true) end,
    function(reason) return resolver(this, reason, false) end)
  return ok and this or Promise.reject(result) -- .. '.\n' .. debug.traceback())
end

return Promise

end
end

do
local _ENV = _ENV
package.preload[ "lib/TableLib" ] = function( ... ) local arg = _G.arg;
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
end
end

do
local _ENV = _ENV
package.preload[ "lib/TryCall" ] = function( ... ) local arg = _G.arg;
tryCall = tryCall or function(func, catchFunc)
  local errTraceBack

  local ret = xpcall(func, function(err)
    errTraceBack = debug.traceback()
  end)
  if (not ret) then
    if (type(catchFunc) == 'function') then
      catchFunc(ret, errTraceBack)
    end
    return ret, errTraceBack
  end
  return nil
end
end
end

end

-----------------------------------------------------------------------------
-- ES6 co lib in lua 5.1
-- Author: fgfg163@163.com
-- Copyright (c) 2015.11
--
-- This is a lib porting from Co v4 in JavaScript
-- It has some different before.
-- to see https://github.com/tj/co
-- Useage:
-- co(coroutine.create(function()
--     local v1 = coroutine.yield(Promise.resolve(123))
--     local v2 = coroutine.yield({
--     a = Promise.resolve(234),
--     b = Promise.resolve(456),
--   })
--   console.log(v1)
--   console.log(v2)
-- end)):catch(function(err)
--   print(err)
-- end)

-----------------------------------------------------------------------------

package.path = package.path .. ';..\\?.lua'
require 'lib/TableLib'
require 'lib/TryCall'


Promise = Promise or require 'lib/Promise'

local unpack = unpack or table.unpack


function new(gen, ...)
  local args = { ... }

  return Promise.new(function(resolve, reject)
    if (type(gen) == 'function') then
      gen = gen(args)
    end
    if (not isCoroutine(gen)) then
      return resolve(gen)
    end



    -- @param {Mixed} res
    -- @return {Promise}
    -- @api private
    function onFulfilled(res)
      local done, flag, ret

      local _, errMsg = tryCall(function()
        flag, ret = coroutine.resume(gen, res)
      end)
      if (errMsg) then
        return reject(errMsg)
      end
      done = coroutine.status(gen) == 'dead' and true or false
      next(done, ret)
      return nil
    end


    -- @param {Error} err
    -- @return {Promise}
    -- @api private
    function onRejected(err)
      local ret

      local _, errMsg = tryCall(function()
        ret = gen.throw(err)
      end)
      if (errMsg) then
        return reject(errMsg)
      end

      next(ret);
    end

    -- Get the next value in the generator,
    -- return a promise.
    --
    -- @param {Object} ret
    -- @return {Promise}
    -- @api private
    function next(done, ret)
      if (done) then return resolve(ret) end
      local value = toPromise(ret);
      if (value and isPromise(value)) then return value:andThen(onFulfilled, onRejected) end

      return onRejected(error('You may only yield a function, promise, generator, array, or object, '
          .. 'but the following object was passed: "' .. ret .. '"'))
    end

    onFulfilled();
  end)
end

-- Convert a `yield`ed value into a promise.
--
-- @param {Mixed} obj
-- @return {Promise}
-- @api private
function toPromise(obj)
  if (not obj) then return obj end

  if (isPromise(obj)) then return obj end
  if (isCoroutine(obj)) then return new(obj) end
  if (type(obj) == 'function') then return thunkToPromise(obj) end

  if (table.isArray(obj)) then
    return arrayToPromise(obj)
  elseif (type(obj) == 'table') then
    return objectToPromise(obj)
  end

  return obj
end

-- Check if `obj` is a promise.
--
-- @param {Object} obj
-- @return {Boolean}
-- @api private
function isPromise(obj)
  if ((type(obj) == 'table') and type(obj.andThen) == 'function') then
    return true
  end
  return false
end

-- Check if `obj` is a generator.
--
-- @param {Mixed} obj
-- @return {Boolean}
-- @api private
function isCoroutine(obj)
  if (type(obj) == 'thread') then
    return true
  end
  return false
end


-- Convert a thunk to a promise.
--
-- @param {Function}
-- @return {Promise}
-- @api private
function thunkToPromise(fn)
  return Promise.new(function(resolve, reject)
    fn(function(err, res)
      if (err) then return reject(err) end
      if (#res > 2) then
        res = table.slice(res, 0, 1)
      end
      resolve(res)
    end)
  end)
end

-- Convert an array of "yieldables" to a promise.
-- Uses `Promise.all()` internally.
--
-- @param {Array} obj
-- @return {Promise}
-- @api private
function arrayToPromise(obj)
  return Promise.all(table.map(obj, toPromise));
end

-- Convert an object of "yieldables" to a promise.
-- Uses `Promise.all()` internally.
--
-- @param {Object} obj
-- @return {Promise}
-- @api private
function objectToPromise(obj)
  local results = {}
  local promises = {}

  local function defer(promise, key)
    results[key] = nil
    table.push(promises, promise:andThen(function(res)
      results[key] = res
    end))
  end

  for _, it in ipairs(table.entries(obj)) do
    local key = it[1]
    local value = it[2]
    local promise = toPromise(value)
    if (promise and isPromise(promise)) then
      defer(promise, key)
    else
      results[key] = obj[key]
    end
  end

  return Promise.all(promises):andThen(function()
    return results
  end)
end

return setmetatable({
  new = new;
}, {
  __call = function(_, ...)
    return new(...)
  end
})