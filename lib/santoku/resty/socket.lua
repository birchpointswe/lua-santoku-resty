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
      return done(false, { status = 0, headers = {}, body = e })
    end
    local headers = {}
    if res.headers then
      for k, v in pairs(res.headers) do headers[str.lower(k)] = v end
    end
    return done(res.status >= 200 and res.status < 300, {
      status = res.status,
      headers = headers,
      body = res.body,
      ok = res.status >= 200 and res.status < 300
    })
  end,
  sleep = function (ms, fn)
    ngx.sleep(ms / 1000)
    return fn()
  end
}
