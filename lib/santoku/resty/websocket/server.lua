-- TODO: Handle received "continuation" frames
-- TODO: Handle received "again" frames for fragmented types

local err = require("santoku.error")
local arr = require("santoku.array")
local server = require("resty.websocket.server")

local function receive (ws)
  local ret = {}
  while true do
    local data, typ0, e = err.checknil(ws:recv_frame())
    if typ0 == "close" then
      err.checknil(ws:send_close())
      return
    elseif typ0 == "ping" then
      err.checknil(ws:send_pong(data))
    elseif typ0 == "binary" or typ0 == "text" or typ0 == "continuation" then
      arr.push(ret, data)
      if e ~= "again" then
        return arr.concat(ret)
      end
    else
      err.error("Unhandled frame type", typ0)
    end
  end
end

return function (opts)

  local ws = err.checknil(server:new(opts))

  return {
    send = function (payload)
      err.checknil(ws:send_binary(payload))
    end,
    receive = function ()
      return receive(ws)
    end,
    close = function ()
      err.checknil(ws:send_close())
    end
  }

end
