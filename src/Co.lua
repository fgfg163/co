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