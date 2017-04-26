local co = require 'Co'
require 'TableLib'
require 'console'
require 'TryCall'


co(coroutine.create(function()
  local v1 = coroutine.yield(Promise.resolve(123))
  console.log(v1)
  local v2 = coroutine.yield(Promise.all({
    Promise.resolve(234),
    Promise.resolve(254),
  }))
  console.log(v2)
end)):catch(function(err)
  print(err)
end)
