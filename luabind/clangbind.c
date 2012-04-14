#include <stdlib.h>
#include <lua5.1/lua.h>
#include <lua5.1/lualib.h>
#include <lua5.1/lauxlib.h>
#include <clang-c/Index.h>

#define LUA_ENUM(L, name, val) do{\
    lua_pushnumber(L, val);\
    lua_setfield(L, -2, name);\
}while(0);


#define TYPE_CXCursor              "CXCursor"
#define TYPE_CXString              "CXString"
#define TYPE_CXSourceLocation      "CXSourceLocation"
#define TYPE_CXType                "CXType"
#define TYPE_CXToken               "CXToken"
#define TYPE_CXTranslationUnit     "CXTranslationUnit"
#define TYPE_CXFile                "CXFile"
#define TYPE_CXIndex               "CXIndex"
#define TYPE_CXSourceRange         "CXSourceRange"

/*
 * CXCursor
 * clang_function (CXCursor)
 */
#define BIND_CXCursor__CXCursor(fun_clang, fun_bind)\
static int fun_bind(lua_State *L)\
{\
    CXCursor *cursor_p;\
    CXCursor cursor;\
\
    cursor_p = luaL_checkudata(L, 1, TYPE_CXCursor);\
\
    cursor = fun_clang(*cursor_p);\
\
    lua_settop(L, 0);\
    cursor_p = lua_newuserdata(L, sizeof(CXCursor));\
    *cursor_p = cursor;\
    help_setudatatype(L, TYPE_CXCursor);\
    return 1;\
}


static void help_setudatatype(lua_State *L, const char *typename)
{
    luaL_getmetatable(L, typename);
    lua_setmetatable(L, -2);
}

static void help_pushlightudata(lua_State *L, void *ptr)
{
    void **addr = lua_newuserdata(L, sizeof(void *));
    *addr = ptr;
}

static void *help_checklightudata(lua_State *L, int pos, const char *typename)
{
    void **addr = luaL_checkudata(L, pos, typename);
    return *addr;
}

/*
 * CXString
 * clang_getFileName (CXFile SFile)
 */
static int bind_getFileName(lua_State *L)
{
    CXFile file;
    CXString name;
    
    file = help_checklightudata(L, 1, TYPE_CXFile);

    name = clang_getFileName(file);
    lua_settop(L, 0);

    lua_pushstring(L, clang_getCString(name));
    clang_disposeString(name);
    return 1;
}

/*
 * time_t
 * clang_getFileTime (CXFile SFile)
 */
static int bind_getFileTime(lua_State *L)
{
    CXFile file;
    time_t mod_time;

    file = help_checklightudata(L, 1, TYPE_CXFile);

    mod_time = clang_getFileTime(file);
    lua_settop(L, 0);

    lua_pushinteger(L, (lua_Integer)mod_time);
    return 1;
}

/*
 * CXIndex
 * clang_createIndex (int excludeDeclarationsFromPCH, int displayDiagnostics)
 */
static int bind_createIndex(lua_State *L)
{
    CXIndex index;
    int excludeDeclarations;
    int displayDiagnostics;

    excludeDeclarations = luaL_checkint(L, 1);
    displayDiagnostics  = luaL_checkint(L, 2);

    index = clang_createIndex(excludeDeclarations, displayDiagnostics);
    lua_settop(L, 0);

    help_pushlightudata(L, index);
    help_setudatatype(L, TYPE_CXIndex);
    return 1;
}

/*
 * void
 * clang_disposeIndex (CXIndex index)
 */
static int bind_disposeIndex(lua_State *L)
{
    CXIndex index;

    index = help_checklightudata(L, 1, TYPE_CXIndex);

    clang_disposeIndex(index);
    return 0;
}

/*
 * void
 * clang_disposeTranslationUnit (CXTranslationUnit)
 */
static int bind_disposeTU(lua_State *L)
{
    CXTranslationUnit tu;

    tu = help_checklightudata(L, 1, TYPE_CXTranslationUnit);

    clang_disposeTranslationUnit(tu);
    return 0;
}

/*
 * CXTranslationUnit
 * clang_createTranslationUnitFromSourceFile
 * (CXIndex CIdx,
 * const char *source_filename,
 * int num_clang_command_line_args,
 * const char *const *clang_command_line_args,
 * unsigned num_unsaved_files,
 * struct CXUnsavedFile *unsaved_files)
 */
static int bind_createTranslationUnitFromSourceFile(lua_State *L)
{
    int args = lua_gettop(L);
    CXIndex index;
    const char *filename;
    int  num_cl_args;
    const char *cl_args;
    unsigned int num_unsaved_files = 0;
    struct CXUnsavedFile *unsaved_files = NULL;

    // TODO: we need a better implementation.
    index = help_checklightudata(L, 1, TYPE_CXIndex);
    filename = lua_tostring(L, 2);
    if(args < 3)
    {
        num_cl_args = 0;
        cl_args = NULL;
    }
    else
    {
        num_cl_args = 1;
        cl_args = lua_tostring(L, 3);
    }
    if(args < 5)
    {
        num_unsaved_files = 0;
        unsaved_files = NULL;
    }
    else
    {
        num_unsaved_files = luaL_checkint(L, 4);
        unsaved_files = lua_touserdata(L, 5);
    }

    CXTranslationUnit tu = clang_createTranslationUnitFromSourceFile(
            index, filename, num_cl_args, &cl_args, num_unsaved_files, unsaved_files);

    lua_settop(L, 0);
    if(tu == NULL)
        lua_pushnil(L);
    else
    {
        help_pushlightudata(L, tu);
        help_setudatatype(L, TYPE_CXTranslationUnit);
    }
    return 1;
}

/*
 * CXCursor
 * clang_getTranslationUnitCursor (CXTranslationUnit)
 */
static int bind_getTUCursor(lua_State *L)
{
    CXTranslationUnit tu;
    CXCursor cursor, *cursor_p;

    // tu = lua_touserdata(L, 1);
    tu = help_checklightudata(L, 1, TYPE_CXTranslationUnit);

    cursor = clang_getTranslationUnitCursor(tu);
    lua_settop(L, 0);

    cursor_p = lua_newuserdata(L, sizeof(CXCursor));
    *cursor_p = cursor;
    help_setudatatype(L, TYPE_CXCursor);
    return 1;
}

/*
 * CXCursorVisitor
 *
 */
static enum CXChildVisitResult visitCallback(CXCursor cursor, CXCursor parent, CXClientData client_data)
{
    lua_State *L = client_data;
    int extra_arg;
    CXCursor *cursor_p;

    lua_pushvalue(L, 1);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);

    extra_arg = lua_gettop(L) - 1;
    int *arg_ref = malloc(extra_arg);
    int i;
    for(i = 0; i < extra_arg; i++)
    {
        lua_pushvalue(L, i+2);
        arg_ref[i] = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    cursor_p = lua_newuserdata(L, sizeof(CXCursor));
    *cursor_p = parent;
    help_setudatatype(L, TYPE_CXCursor);
    lua_insert(L, 2);

    cursor_p = lua_newuserdata(L, sizeof(CXCursor));
    *cursor_p = cursor;
    help_setudatatype(L, TYPE_CXCursor);
    lua_insert(L, 2);

    // Call the lua function.
    lua_call(L, extra_arg+2, 1);

    int ret;
    if(lua_isnil(L, 1))
        ret = CXVisit_Break;
    else
        ret = luaL_checkint(L, 1);
    
    // Push the lua function to the stack again.
    lua_settop(L, 0);
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
    luaL_unref(L, LUA_REGISTRYINDEX, ref);
    // Push extra arguments to the stack again.
    for(i = 0; i< extra_arg; i++)
    {
        lua_rawgeti(L, LUA_REGISTRYINDEX, arg_ref[i]);
        luaL_unref(L, LUA_REGISTRYINDEX, arg_ref[i]);
    }
    free(arg_ref);
    return ret;
}
/*
 * unsigned
 * clang_visitChildren (CXCursor parent, CXCursorVisitor visitor, CXClientData client_data)
 *
 */
static int bind_visitChildren(lua_State *L)
{
    CXCursor parent;
    CXCursor *cursor_arg;

    cursor_arg = luaL_checkudata(L, 1, TYPE_CXCursor);
    parent = *cursor_arg;
    if(clang_Cursor_isNull(parent) || clang_isInvalid(parent.kind))
        luaL_error(L, "Function: visitChildren, Cursor is NULL or invalid!");
    lua_remove(L, 1);

    unsigned int ret;
    ret = clang_visitChildren(parent, visitCallback, (void *)L);

    // Pop all elements from the stack,
    // then push return value at index 1.
    lua_pop(L, lua_gettop(L));
    lua_pushinteger(L, ret);
    return 1;
}

/*
 * CXSourceLocation
 * clang_getLocation (CXTranslationUnit tu, CXFile file, unsigned line, unsigned column)
 */
static int bind_getLocation(lua_State *L)
{
    CXTranslationUnit tu;
    CXSourceLocation loc, *loc_p;
    CXFile file;
    unsigned int line, column;
    
    tu = help_checklightudata(L, 1, TYPE_CXTranslationUnit);
    file = help_checklightudata(L, 2, TYPE_CXFile);
    line = luaL_checkint(L, 3);
    column = luaL_checkint(L, 4);

    loc = clang_getLocation(tu, file, line, column);

    lua_settop(L, 0);
    loc_p = lua_newuserdata(L, sizeof(CXSourceLocation));
    *loc_p = loc;
    help_setudatatype(L, TYPE_CXSourceLocation);
    return 1;
}

/*
 * CXSourceLocation
 * clang_getLocationForOffset (CXTranslationUnit tu, CXFile file, unsigned offset)
 */
static int bind_getLocationForOffset(lua_State *L)
{
    CXTranslationUnit tu;
    CXSourceLocation loc, *loc_p;
    CXFile file;
    unsigned int offset;

    tu = help_checklightudata(L, 1, TYPE_CXTranslationUnit);
    file = help_checklightudata(L, 2, TYPE_CXFile);
    offset = luaL_checkint(L, 3);

    loc = clang_getLocationForOffset(tu, file, offset);

    lua_settop(L, 0);
    loc_p = lua_newuserdata(L, sizeof(CXSourceLocation));
    *loc_p = loc;
    help_setudatatype(L, TYPE_CXSourceLocation);
    return 1;
}

/*
 * CXCursor
 * clang_getCursor (CXTranslationUnit, CXSourceLocation)
 */
static int bind_getCursor(lua_State *L)
{
    CXTranslationUnit tu;
    CXSourceLocation *loc_p;
    
    tu = help_checklightudata(L, 1, TYPE_CXTranslationUnit);
    loc_p = luaL_checkudata(L, 2, TYPE_CXSourceLocation);

    CXCursor cursor = clang_getCursor(tu, *loc_p);
    lua_settop(L, 0);
        
    CXCursor *cursor_p = lua_newuserdata(L, sizeof(CXCursor));
    *cursor_p = cursor;
    help_setudatatype(L, TYPE_CXCursor);
    return 1;
}

static struct luaL_reg luaclang[] =
{
    {"getFileName",              bind_getFileName},
    {"getFileTime",              bind_getFileTime},
    {"createIndex",              bind_createIndex},
    {"disposeIndex",             bind_disposeIndex},
    {"disposeTU",                bind_disposeTU},
    {"createTUFromSourceFile",   bind_createTranslationUnitFromSourceFile},
    {"visitChildren",            bind_visitChildren},
    {"getTUCursor",              bind_getTUCursor},
    {"getLocation",              bind_getLocation},
    {"getLocationForOffset",     bind_getLocationForOffset},
    {"getCursor",                bind_getCursor},
    {NULL, NULL},
};

/* Function bindings for CXCursor. */

/*
 * CXCursorKind
 * clang_getCursorKind (CXCursor)
 */
static int bind_getCursorKind(lua_State *L)
{
    CXCursor *cursor_p;
    int kind;

    cursor_p = luaL_checkudata(L, 1, TYPE_CXCursor);

    kind = clang_getCursorKind(*cursor_p);

    lua_settop(L, 1);
    lua_pushinteger(L, kind);
    return 1;
}

/*
 * int
 * clang_Cursor_isNull (CXCursor) 
 */
static int bind_cursor_isNULL(lua_State *L)
{
    CXCursor *cursor_p;
    int ret;

    cursor_p = luaL_checkudata(L, 1, TYPE_CXCursor);

    ret = clang_Cursor_isNull(*cursor_p);

    lua_settop(L, 0);
    lua_pushboolean(L, ret);
    return 1;
}

/*
 * unsigned
 * clang_equalCursors (CXCursor, CXCursor)
 */
static int bind_equalCursors(lua_State *L)
{
    CXCursor *cursor_p1;
    CXCursor *cursor_p2;
    int ret;

    cursor_p1 = luaL_checkudata(L, 1, TYPE_CXCursor);
    cursor_p2 = luaL_checkudata(L, 2, TYPE_CXCursor);

    ret = clang_equalCursors(*cursor_p1, *cursor_p2);

    lua_settop(L, 0);
    lua_pushboolean(L, ret);
    return 1;
}

/*
 * CXSourceLocation
 * clang_getCursorLocation(CXCursor)
 */
static int bind_getCursorLocation(lua_State *L)
{
    CXCursor *cursor_p;
    CXSourceLocation loc, *loc_p;

    cursor_p = luaL_checkudata(L, 1, TYPE_CXCursor);

    loc = clang_getCursorLocation(*cursor_p);
    
    lua_settop(L, 0);
    loc_p = lua_newuserdata(L, sizeof(CXSourceLocation));
    *loc_p = loc;
    help_setudatatype(L, TYPE_CXSourceLocation);
    return 1;
}

/*
 * CXType
 * clang_getCursorType (CXCursor C)
 */
static int bind_getCursorType(lua_State *L)
{
    CXCursor *cursor_p;
    CXType type, *type_p;

    cursor_p = luaL_checkudata(L, 1, TYPE_CXType);

    type = clang_getCursorType(*cursor_p);

    lua_settop(L, 0);
    type_p = lua_newuserdata(L, sizeof(CXType));
    *type_p = type;
    help_setudatatype(L, TYPE_CXType);
    return 1;
}

/*
 * CXTranslationUnit
 * clang_Cursor_getTranslationUnit (CXCursor)
 */
static int bind_Cursor_getTranslationUnit(lua_State *L)
{
    CXCursor *cursor_p;
    CXTranslationUnit tu;
    
    cursor_p = help_checklightudata(L, 1, TYPE_CXTranslationUnit);

    tu = clang_Cursor_getTranslationUnit(*cursor_p);

    lua_settop(L, 0);
    if(tu == NULL)
        lua_pushnil(L);
    else
    {
        help_pushlightudata(L, tu);
        help_setudatatype(L, TYPE_CXTranslationUnit);
    }
    return 1;
}

/*
 * CXString 
 * clang_getCursorDisplayName (CXCursor)
 */
static int bind_getCursorDisplayName(lua_State *L)
{
    CXCursor *cursor_p;
    CXString name;

    cursor_p = luaL_checkudata(L, 1, TYPE_CXCursor);

    lua_settop(L, 0);
    name = clang_getCursorDisplayName(*cursor_p);
    lua_pushstring(L, clang_getCString(name));
    clang_disposeString(name);
    return 1;
}

/*
 * CXString
 * clang_getCursorSpelling (CXCursor)
 */
static int bind_getCursorSpelling(lua_State *L)
{
    CXCursor *cursor_p;
    CXString name;

    cursor_p = luaL_checkudata(L, 1, TYPE_CXCursor);

    name = clang_getCursorSpelling(*cursor_p);

    lua_settop(L, 0);
    lua_pushstring(L, clang_getCString(name));
    clang_disposeString(name);
    return 1;
}

/*
 * CXCursor
 * clang_getCursorReferenced (CXCursor)
 */
static int bind_getCursorReferenced(lua_State *L)
{
    CXCursor *cursor_p;
    CXCursor cursor;

    cursor_p = luaL_checkudata(L, 1, TYPE_CXCursor);

    cursor = clang_getCursorReferenced(*cursor_p);

    lua_settop(L, 0);
    cursor_p = lua_newuserdata(L, sizeof(CXCursor));
    *cursor_p = cursor;
    help_setudatatype(L, TYPE_CXCursor);
    return 1;
}

/*
 * CXCursor
 * clang_getCursorDefinition (CXCursor)
 */
static int bind_getCursorDefinition(lua_State *L)
{
    CXCursor *cursor_p;
    CXCursor cursor;

    cursor_p = luaL_checkudata(L, 1, TYPE_CXCursor);

    cursor = clang_getCursorDefinition(*cursor_p);

    lua_settop(L, 0);
    cursor_p = lua_newuserdata(L, sizeof(CXCursor));
    *cursor_p = cursor;
    help_setudatatype(L, TYPE_CXCursor);
    return 1;
}

/*
 * unsigned
 * clang_isCursorDefinition (CXCursor)
 */
static int bind_isCursorDefinition(lua_State *L)
{
    CXCursor *cursor_p;
    int ret;

    cursor_p = luaL_checkudata(L, 1, TYPE_CXCursor);

    ret = clang_isCursorDefinition(*cursor_p);
    lua_settop(L, 0);
    if(ret == 0)
        lua_pushnil(L);
    else
        lua_pushinteger(L, ret);
    return 1;
}

/*
 * CXCursor
 * clang_getCanonicalCursor (CXCursor)
 */
static int bind_getCanonicalCursor(lua_State *L)
{
    CXCursor *cursor_p;
    CXCursor cursor;

    cursor_p = luaL_checkudata(L, 1, TYPE_CXCursor);

    cursor = clang_getCanonicalCursor(*cursor_p);

    lua_settop(L, 0);
    cursor_p = lua_newuserdata(L, sizeof(CXCursor));
    *cursor_p = cursor;
    help_setudatatype(L, TYPE_CXCursor);
    return 1;
}

/*
 * CXString
 * clang_getCursorUSR (CXCursor)
 */
static int bind_getCursorUSR(lua_State *L)
{
    CXCursor *cursor_p;
    CXString name;

    cursor_p = luaL_checkudata(L, 1, TYPE_CXCursor);

    name = clang_getCursorUSR(*cursor_p);

    lua_settop(L, 0);
    lua_pushstring(L, clang_getCString(name));
    clang_disposeString(name);
    return 1;
}

/*
 * CXCursor
 * clang_getCursorSemanticParent (CXCursor cursor);
 */
BIND_CXCursor__CXCursor(clang_getCursorSemanticParent, bind_getCursorSemanticParent)

/*
 * CXCursor
 * clang_getCursorLexicalParent (CXCursor);
 */ 
BIND_CXCursor__CXCursor(clang_getCursorLexicalParent, bind_getCursorLexicalParent)

/*
 * CXType
 * clang_getTypedefDeclUnderlyingType (CXCursor C)
 */
static int bind_getTypedefDeclUnderlyingType(lua_State *L)
{
    CXCursor *cursor_p;
    CXType type, *type_p;

    cursor_p = luaL_checkudata(L, 1, TYPE_CXType);

    type = clang_getCursorType(*cursor_p);

    lua_settop(L, 0);
    type_p = lua_newuserdata(L, sizeof(CXType));
    *type_p = type;
    help_setudatatype(L, TYPE_CXType);
    return 1;
}

/*
 * CXType
 * clang_getEnumDeclIntegerType (CXCursor C)
 * */
static int bind_getEnumDeclIntegerType(lua_State *L)
{
    CXCursor *cursor_p;
    CXType type, *type_p;

    cursor_p = luaL_checkudata(L, 1, TYPE_CXType);

    type = clang_getCursorType(*cursor_p);

    lua_settop(L, 0);
    type_p = lua_newuserdata(L, sizeof(CXType));
    *type_p = type;
    help_setudatatype(L, TYPE_CXType);
    return 1;
}

/*
 * long long
 * clang_getEnumConstantDeclValue (CXCursor C)
 */
static int bind_getEnumConstantDeclValue(lua_State *L)
{
    CXCursor *cursor_p;
    long long ret;

    cursor_p = luaL_checkudata(L, 1, TYPE_CXCursor);

    ret = clang_getEnumConstantDeclValue(*cursor_p);

    lua_settop(L, 0);
    lua_pushinteger(L, ret);
    return 1;
}

static struct luaL_reg luaclang_cursor[] =
{
    {"getKind",                         bind_getCursorKind},
    {"getType",                         bind_getCursorType},
    {"getLocation",                     bind_getCursorLocation},
    {"isNull",                          bind_cursor_isNULL},
    {"equal",                           bind_equalCursors},
    {"getDisplayName",                  bind_getCursorDisplayName},
    {"getSpelling",                     bind_getCursorSpelling},
    {"getReferenced",                   bind_getCursorReferenced},
    {"getDefinition",                   bind_getCursorDefinition},
    {"isDefinition",                    bind_isCursorDefinition},
    {"getCanonical",                    bind_getCanonicalCursor},
    {"getUSR",                          bind_getCursorUSR},
    {"getSemanticParent",               bind_getCursorSemanticParent},
    {"getLexicalParent",                bind_getCursorLexicalParent},
    {"getTypedefDeclUnderlyingType",    bind_getTypedefDeclUnderlyingType},
    {"getEnumDeclIntegerType",          bind_getEnumDeclIntegerType},
    {"getEnumConstantDeclValue",        bind_getEnumConstantDeclValue},
    {"getTranslationUnit",              bind_Cursor_getTranslationUnit},
    {NULL, NULL},
};
/* End function bindings for CXCursor. */

/* Function bindings for CXType. */

/*
 * CXType
 * clang_function (CXType)
 */
#define BIND_CXType__CXType(fun_clang, fun_bind)\
static int fun_bind(lua_State *L)\
{\
    CXType *type_p;\
    CXType r_type;\
    \
    type_p = luaL_checkudata(L, 1, TYPE_CXType);\
    \
    r_type = fun_clang(*type_p);\
    \
    lua_settop(L, 0);\
    type_p = lua_newuserdata(L, sizeof(CXType));\
    *type_p = r_type;\
    help_setudatatype(L, TYPE_CXType);\
    return 1;\
}

/*
 * unsigned
 * clang_function (CXType)
 */
#define BIND_Integer__CXType(fun_clang, fun_bind)\
static int fun_bind(lua_State *L)\
{\
    CXType *type_p;\
    long long ret;\
    \
    type_p = luaL_checkudata(L, 1, TYPE_CXType);\
    \
    ret = fun_clang(*type_p);\
    \
    lua_settop(L, 0);\
    lua_pushinteger(L, ret);\
    return 1;\
}

/*
 * CXType
 * clang_getCanonicalType (CXType T)
 */
BIND_CXType__CXType(clang_getCanonicalType, bind_getCanonicalType);

/*
 * CXType
 * clang_getPointeeType (CXType T)
 */
BIND_CXType__CXType(clang_getPointeeType, bind_getPointeeType);

/*
 * CXType
 * clang_getResultType (CXType T)
 */
BIND_CXType__CXType(clang_getResultType, bind_getResultType);

/*
 * CXType
 * clang_getElementType (CXType T)
 */
// TODO:Not Implemented in clang 3.0
 BIND_CXType__CXType(clang_getElementType, bind_getElementType);

/*
 * CXType
 * clang_getArrayElementType (CXType T)
 */
BIND_CXType__CXType(clang_getArrayElementType, bind_getArrayElementType);

/*
 * unsigned
 * clang_isConstQualifiedType (CXType T)
 */
BIND_Integer__CXType(clang_isConstQualifiedType, bind_isConstQualifiedType);

/*
 * unsigned
 * clang_isVolatileQualifiedType (CXType T)
 */
BIND_Integer__CXType(clang_isVolatileQualifiedType, bind_isVolatileQualifiedType);

/*
 * unsigned
 * clang_isRestrictQualifiedType (CXType T)
 */
BIND_Integer__CXType(clang_isRestrictQualifiedType, bind_isRestrictQualifiedType);

/*
 * unsigned
 * clang_getNumArgTypes (CXType T)
 */
BIND_Integer__CXType(clang_getNumArgTypes, bind_getNumArgTypes);

/*
 * unsigned
 * clang_isFunctionTypeVariadic (CXType T)
 */
BIND_Integer__CXType(clang_isFunctionTypeVariadic, bind_isFunctionTypeVariadic);

/*
 * unsigned
 * clang_isPODType (CXType T)
 */
BIND_Integer__CXType(clang_isPODType, bind_isPODType);

/*
 * long long
 * clang_getNumElements (CXType T)
 */
BIND_Integer__CXType(clang_getNumElements, bind_getNumElements);

// TODO:Not Implemented in clang 3.0
// We just use the newest version of libclang.

/*
 * long long
 * clang_getArraySize (CXType T)
 */
BIND_Integer__CXType(clang_getArraySize, bind_getArraySize);

/*
 * CXType
 * clang_getArgType (CXType T, unsigned i)
 */
static int bind_getArgType(lua_State *L)
{
    CXType *type_p;
    CXType r_type;
    unsigned int i;
    
    type_p = luaL_checkudata(L, 1, TYPE_CXType);
    i = luaL_checkint(L, 2);
    
    r_type = clang_getArgType(*type_p, i);
    
    lua_settop(L, 0);
    type_p = lua_newuserdata(L, sizeof(CXType));
    *type_p = r_type;
    help_setudatatype(L, TYPE_CXType);
    return 1;
}

static struct luaL_reg luaclang_type[] =
{
    {"getCanonicalType",            bind_getCanonicalType},
    {"getPointeeType",              bind_getPointeeType},
    {"getResultType",               bind_getResultType},
    {"getElementType",              bind_getElementType},
    {"getArrayElementType",         bind_getArrayElementType},
    {"isConstQualifiedType",        bind_isConstQualifiedType},
    {"isVolatileQualifiedType",     bind_isVolatileQualifiedType},
    {"isRestrictQualifiedType",     bind_isRestrictQualifiedType},
    {"getNumArgTypes",              bind_getNumArgTypes},
    {"isFunctionTypeVariadic",      bind_isFunctionTypeVariadic},
    {"isPODType",                   bind_isPODType},
    {"getNumElements",              bind_getNumElements},
    {"getArraySize",                bind_getArraySize},
    {"getArgType",                  bind_getArgType},
    {NULL, NULL},
};
/* End function bindings for CXType. */

/* {Begin function bindings for CXSourceLocation. */

static int bind_equalLocations(lua_State *L)
{
    CXSourceLocation *loc1, *loc2;

    loc1 = luaL_checkudata(L, 1, TYPE_CXSourceLocation);
    loc2 = luaL_checkudata(L, 2, TYPE_CXSourceLocation);

    unsigned int ret = clang_equalLocations(*loc1, *loc2);
    
    lua_settop(L, 0);
    if(ret)
        lua_pushinteger(L, 1);
    else
        lua_pushnil(L);
    return 1;
}

static int bind_getExpansion(lua_State *L)
{
    CXSourceLocation *loc;
    CXFile file;
    unsigned int line, column, offset;

    loc = luaL_checkudata(L, 1, TYPE_CXSourceLocation);

    // TODO: we should check whether the location is valid,
    // to avoid segmention fault.
    clang_getExpansionLocation(*loc, &file, &line, &column, &offset);

    lua_settop(L, 0);
    if(file == NULL)
        lua_pushnil(L);
    else
    {
        help_pushlightudata(L, file);
        help_setudatatype(L, TYPE_CXFile);
    }
    lua_pushinteger(L, line);
    lua_pushinteger(L, column);
    lua_pushinteger(L, offset);
    return 4;
}

static int bind_getPresumed(lua_State *L)
{
    CXSourceLocation *loc;
    CXString filename;
    unsigned int line, column;

    loc = luaL_checkudata(L, 1, TYPE_CXSourceLocation);

    // TODO: we should check whether the location is valid,
    // to avoid segmention fault.
    clang_getPresumedLocation(*loc, &filename, &line, &column);

    // TODO: should we check the filename?
    lua_settop(L, 0);
    lua_pushstring(L, clang_getCString(filename));
    clang_disposeString(filename);
    lua_pushinteger(L, line);
    lua_pushinteger(L, column);
    return 3;
}

static int bind_getSpelling(lua_State *L)
{
    CXSourceLocation *loc;
    CXFile file;
    unsigned int line, column, offset;

    loc = luaL_checkudata(L, 1, TYPE_CXSourceLocation);

    // TODO: we should check whether the location is valid,
    // to avoid segmention fault.
    clang_getSpellingLocation(*loc, &file, &line, &column, &offset);

    lua_settop(L, 0);
    if(file == NULL)
        lua_pushnil(L);
    else
    {
        help_pushlightudata(L, file);
        help_setudatatype(L, TYPE_CXFile);
    }
    lua_pushinteger(L, line);
    lua_pushinteger(L, column);
    lua_pushinteger(L, offset);
    return 4;
}

static struct luaL_reg luaclang_location[] =
{
    {"equal",              bind_equalLocations},
    {"getExpansion",       bind_getExpansion},
    {"getPresumed",        bind_getPresumed},
    {"getSpelling",        bind_getSpelling},
    {NULL, NULL},
};
/* End function bindings for CXSourceLocation. }*/

static void reg_cursor(lua_State *L)
{
    //int ret;
    // Register metatabel for CXCursor
    luaL_newmetatable(L, TYPE_CXCursor);
    lua_pushstring(L, "__index");
    lua_pushvalue(L, -2);
    lua_settable(L, -3);
    luaL_register(L, NULL, luaclang_cursor);

    //luaL_newmetatable(L, TYPE_CXString);
    //lua_pop(L, 1);

    luaL_newmetatable(L, TYPE_CXSourceLocation);
    lua_pop(L, 1);

    luaL_newmetatable(L, TYPE_CXType);
    lua_pushstring(L, "__index");
    lua_pushvalue(L, -2);
    lua_settable(L, -3);
    luaL_register(L, NULL, luaclang_type);

    luaL_newmetatable(L, TYPE_CXToken);
    lua_pop(L, 1);

    luaL_newmetatable(L, TYPE_CXTranslationUnit);
    lua_pop(L, 1);

    luaL_newmetatable(L, TYPE_CXFile);
    lua_pop(L, 1);

    luaL_newmetatable(L, TYPE_CXIndex);
    lua_pop(L, 1);

    luaL_newmetatable(L, TYPE_CXSourceLocation);
    lua_pushstring(L, "__index");
    lua_pushvalue(L, -2);
    lua_settable(L, -3);
    luaL_register(L, NULL, luaclang_location);

    luaL_newmetatable(L, TYPE_CXSourceRange);
    lua_pop(L, 1);
    //TODO: many type to be registered.
    
}

static void reg_cursorkind(lua_State *L)
{
    int i = 1;
    lua_newtable(L);
    LUA_ENUM(L, "UnexposedDecl", i++);
    LUA_ENUM(L, "StructDecl", i++);
    LUA_ENUM(L, "UnionDecl", i++);
    LUA_ENUM(L, "ClassDecl", i++);
    LUA_ENUM(L, "EnumDecl", i++);
    LUA_ENUM(L, "FieldDecl", i++);
    LUA_ENUM(L, "EnumConstantDecl", i++);
    LUA_ENUM(L, "FunctionDecl", i++);
    LUA_ENUM(L, "VarDecl", i++);
    LUA_ENUM(L, "ParmDecl", i++);
    LUA_ENUM(L, "ObjCInterfaceDecl", i++);
    LUA_ENUM(L, "ObjCCategoryDecl", i++);
    LUA_ENUM(L, "ObjCProtocolDecl", i++);
    LUA_ENUM(L, "ObjCPropertyDecl", i++);
    LUA_ENUM(L, "ObjCIvarDecl", i++);
    LUA_ENUM(L, "ObjCInstanceMethodDecl", i++);
    LUA_ENUM(L, "ObjCClassMethodDecl", i++);
    LUA_ENUM(L, "ObjCImplementationDecl", i++);
    LUA_ENUM(L, "ObjCCategoryImplDecl", i++);
    LUA_ENUM(L, "TypedefDecl", i++);
    LUA_ENUM(L, "CXXMethod", i++);
    LUA_ENUM(L, "Namespace", i++);
    LUA_ENUM(L, "LinkageSpec", i++);
    LUA_ENUM(L, "Constructor", i++);
    LUA_ENUM(L, "Destructor", i++);
    LUA_ENUM(L, "ConversionFunction", i++);
    LUA_ENUM(L, "TemplateTypeParameter", i++);
    LUA_ENUM(L, "NonTypeTemplateParameter", i++);
    LUA_ENUM(L, "TemplateTemplateParameter", i++);
    LUA_ENUM(L, "FunctionTemplate", i++);
    LUA_ENUM(L, "ClassTemplate", i++);
    LUA_ENUM(L, "ClassTemplatePartialSpecialization", i++);
    LUA_ENUM(L, "NamespaceAlias", i++);
    LUA_ENUM(L, "UsingDirective", i++);
    LUA_ENUM(L, "UsingDeclaration", i++);
    LUA_ENUM(L, "TypeAliasDecl", i++);
    LUA_ENUM(L, "ObjCSynthesizeDecl", i++);
    LUA_ENUM(L, "ObjCDynamicDecl", i++);
    LUA_ENUM(L, "CXXAccessSpecifier", i++);
    LUA_ENUM(L, "FirstDecl", CXCursor_UnexposedDecl);
    LUA_ENUM(L, "LastDecl", CXCursor_CXXAccessSpecifier);

    i = CXCursor_FirstRef;
    LUA_ENUM(L, "FirstRef", i);
    LUA_ENUM(L, "ObjCSuperClassRef", i++);
    LUA_ENUM(L, "ObjCProtocolRef", i++);
    LUA_ENUM(L, "ObjCClassRef", i++);
    LUA_ENUM(L, "TypeRef", i++);
    LUA_ENUM(L, "CXXBaseSpecifier", i++);
    LUA_ENUM(L, "TemplateRef", i++);
    LUA_ENUM(L, "NamespaceRef", i++);
    LUA_ENUM(L, "MemberRef", i++);
    LUA_ENUM(L, "LabelRef", i++);
    LUA_ENUM(L, "OverloadedDeclRef", i++);
    LUA_ENUM(L, "LastRef", CXCursor_OverloadedDeclRef);

    i = CXCursor_FirstInvalid;
    LUA_ENUM(L, "FirstInvalid", i);
    LUA_ENUM(L, "InvalidFile", i++);
    LUA_ENUM(L, "NoDeclFound", i++);
    LUA_ENUM(L, "NotImplemented", i++);
    LUA_ENUM(L, "InvalidCode", i++);

    i = CXCursor_PreprocessingDirective;
    LUA_ENUM(L, "PreprocessingDirective", i);
    i = CXCursor_MacroDefinition;
    LUA_ENUM(L, "MacroDefinition", i++);
    LUA_ENUM(L, "MacroExpansion", i++);
    LUA_ENUM(L, "MacroInstantiation", CXCursor_MacroExpansion);
    LUA_ENUM(L, "InclusionDirective", CXCursor_InclusionDirective);
    LUA_ENUM(L, "FirstPreprocessing", CXCursor_FirstPreprocessing);
    LUA_ENUM(L, "LastPreprocessing", CXCursor_LastPreprocessing);

    lua_setfield(L, -2, "cursorkind");
}

static void reg_typekind(lua_State *L)
{
    int i = 0;
    lua_newtable(L);
    LUA_ENUM(L, "Invalid", i++);
    LUA_ENUM(L, "Unexposed", i++);
    LUA_ENUM(L, "Void", i++);
    LUA_ENUM(L, "Bool", i++);
    LUA_ENUM(L, "Char_U", i++);
    LUA_ENUM(L, "UChar", i++);
    LUA_ENUM(L, "Char16", i++);
    LUA_ENUM(L, "Char32", i++);
    LUA_ENUM(L, "UShort", i++);
    LUA_ENUM(L, "UInt", i++);
    LUA_ENUM(L, "ULong", i++);
    LUA_ENUM(L, "ULongLong", i++);
    LUA_ENUM(L, "UInt128", i++);
    LUA_ENUM(L, "Char_S", i++);
    LUA_ENUM(L, "SChar", i++);
    LUA_ENUM(L, "WChar", i++);
    LUA_ENUM(L, "Short", i++);
    LUA_ENUM(L, "Int", i++);
    LUA_ENUM(L, "Long", i++);
    LUA_ENUM(L, "LongLong", i++);
    LUA_ENUM(L, "Int128", i++);
    LUA_ENUM(L, "Float", i++);
    LUA_ENUM(L, "Double", i++);
    LUA_ENUM(L, "LongDouble", i++);
    LUA_ENUM(L, "NullPtr", i++);
    LUA_ENUM(L, "Overload", i++);
    LUA_ENUM(L, "Dependent", i++);
    LUA_ENUM(L, "ObjCId", i++);
    LUA_ENUM(L, "ObjCClass", i++);
    LUA_ENUM(L, "ObjCSel", i++);

    LUA_ENUM(L, "FirstBuiltin", CXType_Void);
    LUA_ENUM(L, "LastBuiltin", CXType_ObjCSel);

    // TODO: Not completed
    lua_setfield(L, -2, "typekind");
}

void reg_visitresult(lua_State *L)
{
    int i = CXChildVisit_Break;
    lua_newtable(L);
    LUA_ENUM(L, "break",     i++);
    LUA_ENUM(L, "continue",  i++);
    LUA_ENUM(L, "recurse",   i++);

    lua_setfield(L, -2, "visitor");
}

int luaopen_luaclang(lua_State* L)
{

    reg_cursor(L);
    luaL_register(L, "clang", luaclang);
    reg_cursorkind(L);
    reg_typekind(L);
    reg_visitresult(L);
    return 1;
}
