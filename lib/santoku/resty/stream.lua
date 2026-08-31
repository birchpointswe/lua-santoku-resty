local ngx = ngx

local M = {}

M.connect = function (opts, done)
  local sock = ngx.socket.tcp()
  sock:settimeouts(opts.connect_timeout_ms or 30000,
    opts.send_timeout_ms or 30000,
    opts.read_timeout_ms or 30000)
  local okc, cerr = sock:connect(opts.host, opts.port)
  if not okc then
    return done(false, cerr)
  end
  if opts.tls ~= false then
    local okh, herr = sock:sslhandshake(false, opts.sslname or opts.host,
      opts.verify ~= false)
    if not okh then
      sock:close()
      return done(false, herr)
    end
  end
  local closed = false
  local function shut (e)
    if closed then return end
    closed = true
    sock:close()
    if opts.closed then opts.closed(e) end
  end
  local function reader ()
    while not closed do
      local d, rerr, partial = sock:receiveany(8192)
      if d and #d > 0 then
        opts.data(d)
      elseif rerr == "timeout" then
        if partial and #partial > 0 then
          opts.data(partial)
        end
      else
        if partial and #partial > 0 then
          opts.data(partial)
        end
        shut(rerr)
        return
      end
    end
  end
  local conn = {
    write = function (d)
      if closed then
        return false, "closed"
      end
      local n, werr = sock:send(d)
      if not n then
        shut(werr)
        return false, werr
      end
      return true
    end,
    close = function ()
      shut()
    end,
  }
  conn.thread = ngx.thread.spawn(reader)
  done(true, conn)
  return conn
end

return M
