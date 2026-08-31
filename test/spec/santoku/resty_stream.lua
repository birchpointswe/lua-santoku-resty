local test = require("santoku.test")
local err = require("santoku.error")
local assert = err.assert

local state = {}

local function fake_sock (cfg)
  local f = { sent = {}, recvi = 0 }
  f.settimeouts = function (_, c, s, r)
    f.timeouts = { c, s, r }
  end
  f.connect = function (_, h, p)
    f.host, f.port = h, p
    if cfg.refuse then
      return nil, "connection refused"
    end
    return 1
  end
  f.sslhandshake = function (_, reused, name, verify)
    f.hs = { reused = reused, name = name, verify = verify }
    if cfg.hsfail then
      return nil, "handshake failed"
    end
    return true
  end
  f.receiveany = function ()
    f.recvi = f.recvi + 1
    local r = cfg.recvs and cfg.recvs[f.recvi]
    if not r then
      return nil, "closed"
    end
    return r.d, r.e, r.p
  end
  f.send = function (_, d)
    if cfg.sendfail then
      return nil, "broken pipe"
    end
    f.sent[#f.sent + 1] = d
    return #d
  end
  f.close = function ()
    f.closed = true
  end
  return f
end

ngx = {
  socket = {
    tcp = function ()
      return state.sock
    end,
  },
  thread = {
    spawn = function (fn)
      if state.defer then
        state.thread_fn = fn
        return true
      end
      fn()
      return true
    end,
  },
}

local stream = require("santoku.resty.stream")

test("tls connect delivers and closes", function ()
  local chunks, closes = {}, {}
  state.sock = fake_sock({ recvs = {
    { d = "one" },
    { e = "timeout", p = "two" },
    { e = "timeout" },
  } })
  local got
  stream.connect({
    host = "imap.x.y", port = 993,
    data = function (c) chunks[#chunks + 1] = c end,
    closed = function (e) closes[#closes + 1] = e or "eof" end,
  }, function (ok, c)
    assert(ok, "connect failed")
    got = c
  end)
  assert(state.sock.hs.name == "imap.x.y")
  assert(state.sock.hs.verify == true)
  assert(chunks[1] == "one")
  assert(chunks[2] == "two")
  assert(#closes == 1 and closes[1] == "closed")
  assert(state.sock.closed)
  assert(got.thread)
end)

test("write after reader done", function ()
  state.sock = fake_sock({ recvs = {} })
  local got
  stream.connect({
    host = "h", port = 1, tls = false,
    data = function () end,
  }, function (ok, c)
    assert(ok)
    got = c
  end)
  local ok2, e2 = got.write("x")
  assert(ok2 == false and e2 == "closed")
end)

test("plain tcp skips handshake", function ()
  state.sock = fake_sock({ recvs = {} })
  stream.connect({
    host = "h", port = 1, tls = false,
    data = function () end,
  }, function (ok)
    assert(ok)
  end)
  assert(state.sock.hs == nil)
end)

test("verify false passed through", function ()
  state.sock = fake_sock({ recvs = {} })
  stream.connect({
    host = "h", port = 993, verify = false,
    data = function () end,
  }, function (ok)
    assert(ok)
  end)
  assert(state.sock.hs.verify == false)
end)

test("sslname override", function ()
  state.sock = fake_sock({ recvs = {} })
  stream.connect({
    host = "10.0.0.1", port = 993, sslname = "imap.x.y",
    data = function () end,
  }, function (ok)
    assert(ok)
  end)
  assert(state.sock.hs.name == "imap.x.y")
end)

test("connect refused", function ()
  state.sock = fake_sock({ refuse = true })
  local res
  stream.connect({ host = "h", port = 1,
    data = function () end,
  }, function (ok, e)
    res = { ok = ok, e = e }
  end)
  assert(res.ok == false and res.e == "connection refused")
end)

test("handshake failure closes", function ()
  state.sock = fake_sock({ hsfail = true })
  local res
  stream.connect({ host = "h", port = 993,
    data = function () end,
  }, function (ok, e)
    res = { ok = ok, e = e }
  end)
  assert(res.ok == false and res.e == "handshake failed")
  assert(state.sock.closed)
end)

test("send failure closes once", function ()
  local closes = 0
  state.defer = true
  state.sock = fake_sock({ sendfail = true })
  local got
  stream.connect({
    host = "h", port = 1, tls = false,
    data = function () end,
    closed = function () closes = closes + 1 end,
  }, function (ok, c)
    assert(ok)
    got = c
  end)
  local ok2, e2 = got.write("x")
  assert(ok2 == false and e2 == "broken pipe")
  assert(closes == 1)
  state.defer = false
  state.thread_fn()
  assert(closes == 1)
  got.close()
  assert(closes == 1)
end)
