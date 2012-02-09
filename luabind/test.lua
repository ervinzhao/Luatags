#! /usr/bin/lua

require("luaclang")

function tu_visitor(cursor, parent)
    print(cursor:getSpelling())
    return clang.visitor.continue
end

index = clang.createIndex(0, 0)
tu = clang.createTUFromSourceFile(index, arg[1])
rootcursor = clang.getTUCursor(tu)

clang.visitChildren(rootcursor, tu_visitor )



