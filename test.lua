local co = require 'src/Co'
local json = require 'lib/json'
require 'lib/TableLib'
require 'lib/console'
require 'lib/TryCall'


co(coroutine.create(function()
  local v1 = coroutine.yield(Promise.resolve(123))
  local v2 = coroutine.yield({
    a = Promise.resolve(234),
    b = Promise.resolve(456),
  })
  console.log(v1)
  console.log(v2)
end)):catch(function(err)
  print(err)
end)
