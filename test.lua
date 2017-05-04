require 'console'
local co = require 'Co'
local Promise = require 'Promise'


local runQ = {
  queue = {},
}
function runQ:add(text, value)
  table.insert(self.queue, value)
end

function runQ:run()
  local value = self.queue[1]
  table.remove(self.queue, 1)
  if (type(value) == 'function') then
    value()
    return true
  end
  return false
end



function getNewPromise(text)
  --  console.log('+ ' .. text)
  return Promise.new(function(resolve)
    runQ:add(text, function()
      --      console.log('- ' .. text)
      resolve(text)
    end)
  end)
end




function case1()

  local p1 = getNewPromise('p1 step1')
  local p2 = getNewPromise('p2 step1')

  p1 = p1.andThen(function(value)
    console.log(value)
    return getNewPromise('p1 step2')
  end)
  p2 = p2.andThen(function(value)
    console.log(value)
    return getNewPromise('p2 step2')
  end)
  p1 = p1.andThen(function(value)
    console.log(value)
    return getNewPromise('p1 step3')
  end)
  p2 = p2.andThen(function(value)
    console.log(value)
    return getNewPromise('p2 step3')
  end)
  p1 = p1.andThen(function(value)
    console.log(value)
    return getNewPromise('p1 step4')
  end)
  p1 = p1.andThen(function(value)
    console.log(value)
    return getNewPromise('p1 step5')
  end)
  p1 = p1.andThen(function(value)
    console.log(value)
    return getNewPromise('p1 step6')
  end)
  p2 = p2.andThen(function(value)
    console.log(value)
    return getNewPromise('p2 step4')
  end)
  p2 = p2.andThen(function(value)
    console.log(value)
    return getNewPromise('p2 step5')
  end)
end


function case2()
  co(coroutine.create(function()
    console.log('p1 begin')
    local v1 = coroutine.yield(getNewPromise('1 01'))
    console.log(v1)
    local v2 = coroutine.yield(getNewPromise('1 02'))
    console.log(v2)
    local v3 = coroutine.yield(getNewPromise('1 03'))
    console.log(v3)
    local v4 = coroutine.yield(getNewPromise('1 04'))
    console.log(v4)
    local v5 = coroutine.yield(getNewPromise('1 05'))
    console.log(v5)
    console.log('p1 end')
  end)).catch(function(err)
    console.log(err)
  end)

  co(coroutine.create(function()
    console.log('p2 begin')
    local v1 = coroutine.yield(getNewPromise('2 01'))
    console.log(v1)
    local v2 = coroutine.yield(getNewPromise('2 02'))
    console.log(v2)
    local v3 = coroutine.yield(getNewPromise('2 03'))
    console.log(v3)
    local v4 = coroutine.yield(getNewPromise('2 04'))
    console.log(v4)
    local v5 = coroutine.yield(getNewPromise('2 05'))
    console.log(v5)
    local v6 = coroutine.yield(getNewPromise('2 06'))
    console.log(v6)
    console.log('p2 end')
  end)).catch(function(err)
    console.log(err)
  end)


  co(coroutine.create(function()
    console.log('p3 begin')
    local v1 = coroutine.yield(getNewPromise('3 01'))
    console.log(v1)
    local v2 = coroutine.yield(getNewPromise('3 02'))
    console.log(v2)
    local v3 = coroutine.yield(getNewPromise('3 03'))
    console.log(v3)
    local v4 = coroutine.yield(getNewPromise('3 04'))
    console.log(v4)
    local v5 = coroutine.yield(getNewPromise('3 05'))
    console.log(v5)
    local v6 = coroutine.yield(getNewPromise('3 06'))
    console.log(v6)
    console.log('p3 end')
  end)).catch(function(err)
    console.log(err)
  end)
end


function case3()
  local coroutineFunc1 = function(a)
    print('1 start')
    for i = 0, 4 do
      print(i, 1)
      coroutine.yield()
    end
    print('1 end')
    return ''
  end
  local coroutineFunc2 = function(a)
    print('2 start')
    for i = 0, 10 do
      print(i, 1)
      coroutine.yield()
    end
    print('2 end')
    return ''
  end

  local co1 = coroutine.create(coroutineFunc1)
  local co2 = coroutine.create(coroutineFunc2)
  console.log('---------------')
  coroutine.resume(co1)
  console.log(coroutine.status(co1))
  coroutine.resume(co2)
  console.log(coroutine.status(co2))
  coroutine.resume(co1)
  console.log(coroutine.status(co1))
  coroutine.resume(co2)
  console.log(coroutine.status(co2))
  coroutine.resume(co1)
  console.log(coroutine.status(co1))
  coroutine.resume(co2)
  console.log(coroutine.status(co2))
  coroutine.resume(co1)
  console.log(coroutine.status(co1))
  coroutine.resume(co2)
  console.log(coroutine.status(co2))
  coroutine.resume(co1)
  console.log(coroutine.status(co1))
  coroutine.resume(co2)
  console.log(coroutine.status(co2))
  coroutine.resume(co1)
  console.log(coroutine.status(co1))
  coroutine.resume(co2)
  console.log(coroutine.status(co2))
  coroutine.resume(co1)
  console.log(coroutine.status(co1))
  coroutine.resume(co2)
  console.log(coroutine.status(co2))
  coroutine.resume(co1)
  console.log(coroutine.status(co1))
  coroutine.resume(co2)
  console.log(coroutine.status(co2))
  coroutine.resume(co1)
  console.log(coroutine.status(co1))
  coroutine.resume(co2)
  console.log(coroutine.status(co2))
  coroutine.resume(co1)
  console.log(coroutine.status(co1))
  coroutine.resume(co2)
  console.log(coroutine.status(co2))
  coroutine.resume(co1)
  console.log(coroutine.status(co1))
  coroutine.resume(co2)
  console.log(coroutine.status(co2))
end

case2()


while (runQ:run()) do
end
