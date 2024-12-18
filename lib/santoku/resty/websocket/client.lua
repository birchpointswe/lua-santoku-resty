-- TODO: Handle received "continuation" frames
-- TODO: Handle received "again" frames for fragmented types

local err = require("santoku.error")
local client = require("resty.websocket.client")

local function receive (ws)
  while true do
    local data, typ0 = err.checknil(ws:recv_frame())
    if typ0 == "close" then
      err.checknil(ws:send_close())
      return
    elseif typ0 == "ping" then
      err.checknil(ws:send_pong(data))
    elseif typ0 == "binary" or typ0 == "text" then
      return data
    end
  end
end

return function (url, nopts, copts)

  local ws = err.checknil(client:new(nopts))
  err.checknil(ws:connect(url, copts))

  return {
    send = function (payload)
      err.checknil(ws:send_binary(payload))
    end,
    receive = function ()
      return receive(ws)
    end,
    close = function ()
      err.checknil(ws:close())
    end
  }

end
