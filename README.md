# Santoku Resty

OpenResty extensions for the Santoku library, providing HTTP client, JWT handling, and WebSocket utilities for Lua applications running in the OpenResty/nginx environment.

## Module Reference

### `santoku.resty.http`

HTTP client wrapper around `lua-resty-http` with simplified interface and santoku error handling.

| Function | Arguments | Returns | Description |
|----------|-----------|---------|-------------|
| `request` | `opts` | `response` | Makes HTTP request. `opts` fields: `url` (required URL string), `method` (HTTP method), `body` (request body), `headers` (table of headers), `ssl_verify` (boolean), `configure` (function to configure client). Returns table with `status` (number), `headers` (table), `body` (string) |

### `santoku.resty.jwt`

JWT (JSON Web Token) utilities with RSA key support and verification capabilities.

| Function | Arguments | Returns | Description |
|----------|-----------|---------|-------------|
| `jwk_to_pem` | `jwk` | `string` | Converts JWK to PEM format. `jwk` fields: `kty` (key type), `n` (modulus), `e` (exponent) |
| `parse` | `token` | `table` | Parses JWT token without verification. Returns table with `header` (table) and `payload` (table) |
| `verify` | `auth, get_jwk, get_time, [claim_spec]` | `ok, data/error` | Verifies JWT with RSA signature. `auth` is the JWT string, `get_jwk` is function(kid) returning JWK, `get_time` returns current Unix timestamp, `claim_spec` is optional table of claim validators |

### `santoku.resty.websocket.client`

WebSocket client implementation with automatic ping/pong handling and frame management.

| Function | Arguments | Returns | Description |
|----------|-----------|---------|-------------|
| `client` | `url, [nopts], [copts]` | `websocket` | Creates WebSocket client connection. `url` is ws:// or wss:// URL, `nopts` are network options (e.g. `pool_size`, `backlog`), `copts` are connection options (e.g. `proto`). Returns object with methods: `send(payload)`, `receive()`, `close()` |

### `santoku.resty.websocket.server`

WebSocket server implementation with fragmented message support and automatic connection handling.

| Function | Arguments | Returns | Description |
|----------|-----------|---------|-------------|
| `server` | `[opts]` | `websocket` | Creates WebSocket server connection. `opts` are server options (e.g. `timeout`, `max_payload_len`). Returns object with methods: `send(payload)`, `receive()`, `close()` |

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