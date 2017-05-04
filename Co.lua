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
-- local v1 = coroutine.yield(Promise.resolve(123))
-- local v2 = coroutine.yield({
-- a = Promise.resolve(234),
-- b = Promise.resolve(456),
-- })
-- console.log(v1)
-- console.log(v2)
-- end)):catch(function(err)
-- print(err)
-- end)

-----------------------------------------------------------------------------


local Promise = Promise or require 'Promise'

local unpack = unpack or table.unpack
local isArray = table.isArray or function(tab)
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
function tryCatch(cb)
  return xpcall(cb, function(e)
    return setStackTraceback and
        (e .. '\n' .. debug.traceback())
        or (e)
  end)
end

----------------------------------------------------------------------
function new(gen, ...)
  return Promise.new(function(resolve, reject)
    if (type(gen) == 'function') then gen = coroutine.create(gen) end
    if (type(gen) ~= 'thread') then return resolve(gen) end

    local onResolved, onRejected, next

    onResolved = function(res)
      local done, ret
      local coStatus = true
      local xpcallRes, xpcallErr = tryCatch(function()
        coStatus, ret = coroutine.resume(gen, res)
      end)
      if (not xpcallRes) then
        return reject(xpcallErr)
      end
      if (not coStatus) then
        return reject(ret)
      end
      done = (coroutine.status(gen) == 'dead')
      next(done, ret)
    end

    onRejected = function(err)
      local done, ret
      local coStatus = true
      local xpcallRes, xpcallErr = tryCatch(function()
        coStatus, ret = coroutine.resume(gen, error(err))
      end)
      if (not xpcallRes) then
        return reject(xpcallErr)
      end
      if (not coStatus) then
        return reject(xpcallErr)
      end
      done = (coroutine.status(gen) == 'dead')
      next(done, ret)
    end

    next = function(done, ret)
      if (done) then
        return resolve(ret)
      end
      local value = toPromise(ret)
      if (value and (isPromise(value))) then
        return value.andThen(onResolved, onRejected)
      end
      return onResolved(value)
      --       onRejected(error('You may only yield a function, promise, generator, array, or object, '
      --          .. 'but the following object was passed: "' .. type(ret) .. '"'))
    end

    onResolved();
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

  if (isArray(obj)) then
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
  if ((type(obj) == 'table') and (type(obj.andThen) == 'function')) then
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
        res = { res[2] }
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
  local newArr = {}
  for k, v in ipairs(obj) do
    table.insert(newArr, toPromise(v))
  end
  return Promise.all(newArr);
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
    table.insert(promises, promise.andThen(function(res)
      results[key] = res
    end))
  end

  for key, value in pairs(obj) do
    local promise = toPromise(value)
    if (promise and isPromise(promise)) then
      defer(promise, key)
    else
      results[key] = obj[key]
    end
  end

  return Promise.all(promises).andThen(function()
    return results
  end)
end



return setmetatable({
  new = new,
  Promise = Promise,
}, {
  __call = function(_, ...)
    return new(...)
  end
})
