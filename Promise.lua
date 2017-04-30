--------------------------------------------------------------------------------------
-- es2015 Promise for lua 5.1 and 5.2

--------------------------------------------------------------------------------------

local PENDING = 0
local RESOLVED = 1
local REJECTED = 2

-- 是否需要显示stack traceback里的错误信息
-- stack traceback错误信息很长，所以这个功能作为可选项
local stackTraceback = true
-- 封装了xpcall方法
function tryCatch(cb)
  return xpcall(cb, function(e)
    return stackTraceback and
        (e .. '\n' .. debug.traceback())
        or (e)
  end)
end

-- 绑定self到某个方法
function bindSelf(fn, self)
  return function(...)
    return fn(self, ...)
  end
end

-- 隔离函数，为了防止回调过多导致爆栈需要隔离回调操作
function asap(callback)
  local co = coroutine.wrap(callback)
  co()
end

-- 类
local Promise = {
  setStackTraceback = function(value)
    stackTraceback = value
  end
}

-- 类方法 （静态方法）
function Promise.new(resolver)
  if (type(resolver) ~= 'function') then
    error('Promise resolver ' .. type(resolver) .. ' is not a function')
  end

  local newPromise = {
    PromiseStatus = PENDING,
    PromiseValue = nil,
    deferreds = {},
  }
  -- promise的主要方法，这么写是为了绑定self
  newPromise.andThen = bindSelf(andThen, newPromise)
  newPromise.catch = bindSelf(catch, newPromise)

  -- 执行传入promise的方法
  resolver(bindSelf(resolve, newPromise), bindSelf(reject, newPromise))

  return newPromise
end

function Promise.isPromise(obj)
  return (type(obj) == 'table') and type(obj.andThen) == 'function'
end

--- - Promise.resolve方法相当于实例化一个Promise对象，状态变为RESOLVED
function Promise.resolve(value)
  if (Promise.isPromise(value)) then return value end
  return Promise.new(function(resolve, reject)
    resolve(value)
  end)
end

--- - Promise.reject方法相当于实例化一个Promise对象，状态变为REJECTED
function Promise.reject(value)
  return Promise.new(function(resolve, reject)
    reject(value)
  end)
end

function Promise.all(args)
  if (type(args) ~= 'table') then args = {} end
  return Promise.new(function(resolve, reject)
    if (#args == 0) then return resolve({}) end
    local remaining = #args
    local function getRes(k, value)
      if (Promise.isPromise(value)) then
        value.andThen(function(res)
          getRes(k, res)
        end, function(err)
          reject(err)
        end)
        return
      end

      args[k] = value
      remaining = remaining - 1
      if (remaining == 0) then
        resolve(args)
      end
    end

    for k, value in ipairs(args) do
      getRes(k, value)
    end
  end)
end

function Promise.race(args)
  if (type(args) ~= 'table') then args = {} end
  return Promise.new(function(resolve, reject)
    for k, v in ipairs(args) do
      Promise.resolve(v).andThen(resolve, reject)
    end
  end)
end

-- 对象方法
function resolve(self, value)
  local xpcallRes, xpcallErr = tryCatch(function()
    if (Promise.isPromise(value)) then
      doResolve(self, value.andThen, resolve, reject)
      return
    end
    self.PromiseStatus = RESOLVED
    self.PromiseValue = value
    finale(self)
  end)
  if (not xpcallRes) then
    reject(self, xpcallErr)
  end
end

function reject(self, value)
  self.PromiseStatus = REJECTED
  self.PromiseValue = value
  if (stackTraceback) then
    self.PromiseValue = value .. '\n' .. debug.traceback()
  end
  finale(self)
end

function Handler(onResolved, onRejected, resolve, reject)
  return {
    -- 当前promise的状态转换事件处理函数
    onResolved = type(onResolved) == 'function' and onResolved or nil,
    -- 当前promise的状态转换事件处理函数
    onRejected = type(onRejected) == 'function' and onRejected or nil,
    resolve = resolve,
    reject = reject,
  }
end

-- promise的主要方法。由于lua中then是关键字，所以用andThen取代
function andThen(self, onResolved, onRejected)
  -- then本身也会返回一个promise，实现promise链
  return Promise.new(function(resolve, reject)
    local deferred = Handler(onResolved, onRejected, resolve, reject)
    handle(self, deferred)
  end)
end

function handle(self, deferred)
  if (self.PromiseStatus == PENDING) then
    table.insert(self.deferreds, deferred)
    return
  end
  asap(function()
    local cb
    if (self.PromiseStatus == RESOLVED) then
      cb = deferred.onResolved
    else
      cb = deferred.onRejected
    end
    if (type(cb) == 'nil') then
      if (self.PromiseStatus == RESOLVED) then
        deferred.resolve(self.PromiseValue)
      else
        deferred.reject(self.PromiseValue)
      end
      return
    end

    local ret
    local xpcallRes, xpcallErr = tryCatch(function()
      -- 执行当前promise的状态转换事件处理函数
      ret = cb(self.PromiseValue)
    end)
    if (not xpcallRes) then
      -- 修改promise链表中下一个promise对象的状态为rejected
      deferred.reject(xpcallErr)
      return
    end
    -- 修改promise链表中下一个promise对象的状态为resolved
    deferred.resolve(ret)
  end)
end

-- 对状态转换事件处理函数进行封装后，再传给执行函数
function doResolve(self, andThenFn, onResolved, onRejected)
  -- done作为开关以防止fn内同时调用resolve和reject方法
  local done = false
  local xpcallRes, xpcallErr = tryCatch(function()
    andThenFn(function(value)
      if (done) then return end
      done = true
      onResolved(self, value)
    end, function(value)
      if (done) then return end
      done = true
      onRejected(self, value)
    end)
  end)
  if (not xpcallRes) then
    if (done) then return end
    done = true
    onRejected(self, xpcallErr)
  end
end

-- 移动到链表的下一个promise
function finale(self)
  for k, v in ipairs(self.deferreds) do
    handle(self, v);
  end
  self.deferreds = {};
end

-- promise的主要方法
function catch(self, onRejected)
  -- then本身也会返回一个promise，实现promise链
  self.andThen(nil, onRejected)
end

return Promise
