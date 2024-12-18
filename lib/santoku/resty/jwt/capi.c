#include "lua.h"
#include "lauxlib.h"

#include <stdio.h>
#include <stdlib.h>
#include <openssl/rsa.h>
#include <openssl/pem.h>
#include <openssl/bn.h>

static inline void tk_lua_callmod (lua_State *L, int nargs, int nret, const char *smod, const char *sfn)
{
  lua_getglobal(L, "require"); // arg req
  lua_pushstring(L, smod); // arg req smod
  lua_call(L, 1, 1); // arg mod
  lua_pushstring(L, sfn); // args mod sfn
  lua_gettable(L, -2); // args mod fn
  lua_remove(L, -2); // args fn
  lua_insert(L, - nargs - 1); // fn args
  lua_call(L, nargs, nret); // results
}

static inline int tk_lua_error (lua_State *L, const char *err)
{
  lua_pushstring(L, err);
  tk_lua_callmod(L, 1, 0, "santoku.error", "error");
  return 0;
}

// TODO: fix deprecation warnings
// TODO: consider using lua_Buffer instead of malloc/free
static inline int push_pem (lua_State *L, BIGNUM *n, BIGNUM *e)
{
  RSA *rsa = RSA_new();
  if (rsa == NULL) {
    lua_pushnil(L);
    lua_pushstring(L, "Failed to create RSA structure");
    return 2;
  }
  if (RSA_set0_key(rsa, n, e, NULL) != 1) {
    lua_pushnil(L);
    lua_pushstring(L, "Failed to set RSA key");
    RSA_free(rsa);
    return 2;
  }
  BIO *bio = BIO_new(BIO_s_mem());
  if (bio == NULL) {
    lua_pushnil(L);
    lua_pushstring(L, "Failed to create BIO");
    RSA_free(rsa);
    return 2;
  }
  if (PEM_write_bio_RSA_PUBKEY(bio, rsa) != 1) {
    lua_pushnil(L);
    lua_pushstring(L, "Failed to write public key to BIO");
    BIO_free(bio);
    RSA_free(rsa);
    return 2;
  }
  long pem_length = BIO_ctrl(bio, BIO_CTRL_PENDING, 0, NULL);
  if (pem_length <= 0) {
    lua_pushnil(L);
    lua_pushstring(L, "Failed to get BIO length");
    BIO_free(bio);
    RSA_free(rsa);
    return 2;
  }
  char *pem_string = (char *)malloc(pem_length + 1);
  if (pem_string == NULL) {
    lua_pushnil(L);
    lua_pushstring(L, "Failed to allocate memory for PEM string");
    BIO_free(bio);
    RSA_free(rsa);
    return 2;
  }
  BIO_read(bio, pem_string, pem_length);
  pem_string[pem_length] = '\0';
  BIO_free(bio);
  RSA_free(rsa);
  lua_pushstring(L, pem_string);
  free(pem_string);
  return 1;
}

static int rsa_pem (lua_State *L)
{
  const char *n_hex = luaL_checkstring(L, 1);
  const char *e_hex = luaL_checkstring(L, 2);
  BIGNUM *n = NULL;
  BIGNUM *e = NULL;
  n = BN_new();
  e = BN_new();
  if (BN_hex2bn(&n, n_hex) == 0 || BN_hex2bn(&e, e_hex) == 0) {
    BN_free(n);
    BN_free(e);
    return tk_lua_error(L, "Failed to convert hex to BIGNUM");
  }
  return push_pem(L, n, e);
}

static luaL_Reg fns[] =
{
  { "rsa_pem", rsa_pem },
  { NULL, NULL }
};

int luaopen_santoku_resty_jwt_capi (lua_State *L)
{
  lua_newtable(L);
  luaL_register(L, NULL, fns);
  return 1;
}
