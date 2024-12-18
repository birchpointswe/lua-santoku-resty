local jwt = require("resty.jwt")
local tbl = require("santoku.table")
local str = require("santoku.string")
local capi = require("santoku.resty.jwt.capi")

local M = {}

M.jwk_to_pem = function (jwk)
  local n = str.to_hex(str.from_base64_url(jwk.n))
  local e = str.to_hex(str.from_base64_url(jwk.e))
  return capi.rsa_pem(n, e)
end

M.parse = function (token)
  return jwt:load_jwt(str.from_base64(token))
end

M.verify = function (auth, get_jwk, get_time, claim_spec)
  auth = auth and str.from_base64(auth)
  auth = auth and jwt:load_jwt(auth)
  local kid = tbl.get(auth, "header", "kid")
  if not kid then
    return false, "No kid"
  end
  local jwk = get_jwk(kid)
  if not jwk then
    return false, "No jwk for kid", kid
  end
  if jwk.kty ~= "RSA" then
    return false, "Unsupported key type", jwk.kty
  end
  local pem = M.jwk_to_pem(jwk)
  claim_spec = claim_spec or {
    exp = function (t)
      if not t or get_time() >= t then
        error("expired")
      end
    end
  }
  local data = jwt:verify_jwt_obj(pem, auth, claim_spec)
  if not data then
    return false, "JWT verification failed"
  end
  if not data.verified then
    return false, data.reason
  end
  return true, data
end

return M
