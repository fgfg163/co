# co
co for lua

lua的co库
参考ti/co  v4.6.0    https://github.com/tj/co

使用协程(coroutine)实现的co库，用于处理Promise异步问题

```lua
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


-- print
begin
some value
{"promise01", "promise02", "promise03"}
```

ChangeLog
-- 2017.05.01 
>  promise bug fix

-- 2017.04.29 release v1.0
