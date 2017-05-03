# co
co for lua

lua的co库
参考ti/co  v4.6.0    https://github.com/tj/co

使用协程(coroutine)实现的co库，用于处理Promise异步问题

这个Co库打包为2个版本
Co.lua不包含Promise，你可以使用自己的Promise实现。
需要在使用前将Promise加载到全局变量里，或者将Promise.lua文件放在Co.lua相同目录下
```lua
-- 用全局变量方式引入Promise
Promise = require 'Your Promise lib'
local co = require 'Co'

...

```

Co_with_promise.lua包含了一个Promise实现，使用时直接引用即可
```lua
local co = require 'Co_with_promise'
local Promise = co.Promise

...

```


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
-- 2017.05.03 
>  add Co_with_promise for some user.

-- 2017.05.01 
>  promise bug fix

-- 2017.04.29 release v1.0
