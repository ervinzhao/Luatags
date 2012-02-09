#include <limits.h>
#include <stdlib.h>
#include <unistd.h>
#include <lua5.1/lua.h>
#include <lua5.1/lualib.h>
#include <lua5.1/lauxlib.h>

int bind_realpath(lua_State *L)
{
    const char *filepath = luaL_checkstring(L, 1);
    
    lua_settop(L, 0);
    if(access(filepath, R_OK) != 0)
    {
        lua_pushnil(L);
        return 1;
    }
    char *rpath = realpath(filepath, NULL);
    if(rpath == NULL)
        lua_pushnil(L);
    else
        lua_pushstring(L, rpath);
    free(rpath);
    return 1;
}

static struct luaL_reg luatagslib[] =
{
    {"realpath",        bind_realpath},
};

int luaopen_tagslib(lua_State *L)
{
    luaL_register(L, "tagslib", luatagslib);
    return 1;
}
