local env = {
  name = "santoku-resty",
  version = "0.0.5-1",
  license = "MIT",
  public = true,
  dependencies = {
    "lua == 5.1",
    "santoku >= 0.0.304-1",
    "lua-resty-http == 0.17.2-0",
    "lua-resty-openssl == 1.5.1-1",
    "lua-resty-jwt == 0.2.3-0",
  },
}

env.homepage = "https://github.com/treadwelllane/lua-" .. env.name
env.tarball = env.name .. "-" .. env.version .. ".tar.gz"
env.download = env.homepage .. "/releases/download/" .. env.version .. "/" .. env.tarball

return { env = env }
