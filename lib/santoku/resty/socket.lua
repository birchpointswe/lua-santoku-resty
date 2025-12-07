local http = require("resty.http")
local str = require("santoku.string")
local ngx = ngx

return {
  fetch = function (url, opts, done)
    opts = opts or {}
    local httpc = http.new()
    local res, e = httpc:request_uri(url, {
      method = opts.method or "GET",
      body = opts.body,
      headers = opts.headers,
      ssl_verify = opts.ssl_verify
    })
    if not res then
      return done(false, {
        status = 0,
        headers = {},
        ok = false,
        body = function (cb) return cb(false, e) end
      })
    end
    local headers = {}
    if res.headers then
      for k, v in pairs(res.headers) do headers[str.lower(k)] = v end
    end
    local body = res.body
    return done(res.status >= 200 and res.status < 300, {
      status = res.status,
      headers = headers,
      ok = res.status >= 200 and res.status < 300,
      body = function (cb)
        return cb(true, body)
      end
    })
  end,
  sleep = function (ms, fn)
    ngx.sleep(ms / 1000)
    return fn()
  end
}
