require 'console'
local co = require 'Co'
local Promise = require 'Promise'

co(coroutine.create(function()
  console.log('begin')
  local v1 = coroutine.yield(Promise.resolve('some value'))
  console.log(v1)
  local v2 = coroutine.yield(Promise.all({
    Promise.resolve('promise01'),
    Promise.resolve('promise02'),
    Promise.resolve('promise03'),
  }))
  console.log(v2)
end)).catch(function(err)
  console.log(err)
end)
