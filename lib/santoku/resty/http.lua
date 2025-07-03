local http = require("resty.http")
local err = require("santoku.error")

-- TODO: accept and serialize params as argument
local function request (opts)
  -- TODO: cache?
  http = http.new()
  if opts.configure then
    opts.configure(http)
  end
  local res, e = http:request_uri(opts.url, {
    method = opts.method,
    body = opts.body,
    headers = opts.headers,
    ssl_verify = opts.ssl_verify,
  })
  if not res then
    return err.error(e)
  end
  return {
    status = res.status,
    headers = res.headers,
    body = res.body
  }
end

return {
  request = request
}
