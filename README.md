# santoku-resty

OpenResty glue for the santoku ecosystem: thin wrappers over the upstream `lua-resty-*`
rocks (HTTP client, JWT, WebSocket) that add santoku error handling and a smaller surface.
Built on base `santoku` (see [../lua-santoku/README.md](../lua-santoku/README.md) for the
error/table/string helpers these modules use).

This README is a usage guide, not an API reference. The source files are short; read them
for the exhaustive surface.

## Runtime

These modules run inside OpenResty / nginx. They call the `ngx` API and the cosocket-based
upstream rocks, so they cannot be loaded or exercised outside an nginx worker. There are no
tests in this repo for that reason: the suite would need a running nginx to execute. The
upstream rocks supply the base behavior; this repo only adds glue:

- `lua-resty-http` (0.17.x) backs `santoku.resty.http` and `santoku.resty.socket`.
- `lua-resty-jwt` (0.2.x) backs `santoku.resty.jwt`.
- `lua-resty-openssl` (1.5.x) is pulled in transitively by `lua-resty-jwt`.
- `resty.websocket.client` / `resty.websocket.server` (shipped with OpenResty) back the
  WebSocket modules.

See the upstream projects for the underlying request, signing, and frame semantics:
[lua-resty-http](https://github.com/ledgetech/lua-resty-http),
[lua-resty-jwt](https://github.com/SkyLothar/lua-resty-jwt),
[lua-resty-openssl](https://github.com/fffonion/lua-resty-openssl).

## santoku.resty.http

A one-call wrapper over `resty.http`'s `request_uri`. It takes an options table, returns
a plain `{ status, headers, body }` table on success, and raises through `santoku.error`
on transport failure (rather than returning `nil, err`).

```lua
local http = require("santoku.resty.http")

local res = http.request({
  url = "https://example.com/api",
  method = "POST",
  body = '{"k":"v"}',
  headers = { ["Content-Type"] = "application/json" },
  ssl_verify = true,
})
-- res.status, res.headers, res.body

-- configure hook receives the underlying resty.http client before the request:
http.request({ url = u, configure = function (c) c:set_timeout(5000) end })
```

## santoku.resty.socket

A second HTTP client over `resty.http`, oriented around cancelable, awaitable requests
plus a sleep helper. Unlike `santoku.resty.http`, it does not raise: every call returns
`ok, response` where `response` normalizes headers to lowercase keys, exposes `body` as a
function, and sets `ok` from a 2xx status.

```lua
local socket = require("santoku.resty.socket")

-- synchronous one-shot
local ok, res = socket.fetch("https://example.com", { method = "GET" })
if ok then local body = res.body() end

-- deferred request with cancellation
local req = socket.request("https://example.com", { method = "GET" })
-- req.cancel()  -- closes the client if in flight; await then reports canceled
local ok2, res2 = req.await()

socket.sleep(250)  -- milliseconds; wraps ngx.sleep
```

Cancellation before `await` short-circuits to `{ status = 0, ok = false, canceled = true }`.
A transport error yields `{ status = 0, ok = false, error = err }`.

## santoku.resty.jwt

Wraps `resty.jwt` for parsing and RSA-signature verification, plus a JWK to PEM conversion
backed by the `santoku.resty.jwt.capi` C helper. Tokens are expected base64-encoded
(decoded with `santoku.string` before being handed to `resty.jwt`). Only RSA keys are
supported; `verify` returns `false, reason, ...` for missing kid, missing or non-RSA JWK,
or a failed/unverified signature.

```lua
local jwt = require("santoku.resty.jwt")

local parsed = jwt.parse(token)              -- { header = ..., payload = ... }, no verification

local ok, data = jwt.verify(
  auth,                                      -- the (base64) token
  function (kid) return jwks[kid] end,       -- resolve a JWK by key id
  function () return os.time() end           -- current unix time, used by the default exp check
  -- optional claim_spec table overrides the default exp validator
)
if ok then local payload = data.payload end

-- JWK ({ kty = "RSA", n = ..., e = ... }) to a PEM public key:
local pem = jwt.jwk_to_pem(jwk)
```

The C helper (`luaopen_santoku_resty_jwt_capi`) exposes a single function `rsa_pem(n_hex,
e_hex)` that builds an RSA public key from hex-encoded modulus and exponent and returns the
PEM string; `jwk_to_pem` decodes the base64url JWK fields to hex and calls it.

## santoku.resty.websocket.client

Wraps `resty.websocket.client` as a connected object with three methods. The module value
is a constructor function `(url, nopts, copts)` where `nopts` are passed to `client:new`
and `copts` to `connect`. Sends are binary; `receive` loops internally, answering pings
with pongs and returning on the first text or binary frame (or `nil` on close).

```lua
local connect = require("santoku.resty.websocket.client")

local ws = connect("wss://example.com/socket", { timeout = 5000 }, { proto = "chat" })
ws.send("payload")        -- send_binary
local msg = ws.receive()  -- text/binary frame, pings answered automatically; nil on close
ws.close()
```

## santoku.resty.websocket.server

Wraps `resty.websocket.server` with the same three-method shape, constructed from a single
options table passed to `server:new`. `receive` reassembles fragmented messages: it
accumulates binary, text, and continuation frames until a frame is not flagged `again`,
then concatenates and returns the whole message.

```lua
local accept = require("santoku.resty.websocket.server")

local ws = accept({ timeout = 5000, max_payload_len = 65535 })
local msg = ws.receive()  -- full (reassembled) message; pings answered automatically
ws.send("reply")          -- send_binary
ws.close()                -- send_close
```

## License

Copyright 2025 Birch Point SWE

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
