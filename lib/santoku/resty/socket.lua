local http = require("resty.http")
local str = require("santoku.string")
local ngx = ngx

local function wrap_response (res, err, canceled)
  if canceled then
    return false, { status = 0, headers = {}, ok = false, canceled = true }
  end
  if not res then
    return false, {
      status = 0,
      headers = {},
      ok = false,
      error = err,
      body = function () return nil end
    }
  end
  local headers = {}
  if res.headers then
    for k, v in pairs(res.headers) do headers[str.lower(k)] = v end
  end
  local body = res.body
  return res.status >= 200 and res.status < 300, {
    status = res.status,
    headers = headers,
    ok = res.status >= 200 and res.status < 300,
    body = function () return body end
  }
end

return {
  request = function (url, opts)
    opts = opts or {}
    local canceled = false
    local httpc = nil
    local settled = false
    return {
      cancel = function ()
        canceled = true
        if httpc and not settled then
          pcall(function () httpc:close() end)
        end
      end,
      await = function ()
        if canceled then
          return wrap_response(nil, nil, true)
        end
        httpc = http.new()
        local res, err = httpc:request_uri(url, {
          method = opts.method or "GET",
          body = opts.body,
          headers = opts.headers,
          ssl_verify = opts.ssl_verify
        })
        settled = true
        httpc = nil
        return wrap_response(res, err, canceled)
      end
    }
  end,
  fetch = function (url, opts)
    opts = opts or {}
    local httpc = http.new()
    local res, err = httpc:request_uri(url, {
      method = opts.method or "GET",
      body = opts.body,
      headers = opts.headers,
      ssl_verify = opts.ssl_verify
    })
    return wrap_response(res, err, false)
  end,
  sleep = function (ms)
    ngx.sleep(ms / 1000)
  end
}
