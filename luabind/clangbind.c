#include <lua5.1/lua.h>
#include <lua5.1/lualib.h>
#include <lua5.1/lauxlib.h>
#include <clang-c/Index.h>

static struct luaL_reg luaclang[] =
{
};

int luaopen_clang(lua_State* L)
{
    return 0;
}
