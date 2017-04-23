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