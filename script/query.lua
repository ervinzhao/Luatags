#! /usr/bin/lua                                                                                                              

package.path=string.gsub(arg[0], "[^%/]+$", "?.lua;")..package.path
package.cpath=string.gsub(arg[0], "[^%/]+$", "?.so;")..package.cpath
require("lfs")
require("luasql.sqlite3")
require("tagslib")
require("luaclang")
require("clangaux")
require("luaposix")
require("json")
require("std")

if arg[1] == nil then
    print("Need an argument for query.")
end
sql = [[select name,kind,type,file,line from symbols where name='%s']]
sql = string.format(sql, arg[1])

db_path = ".luatags/tags.db"
sqlenv = luasql.sqlite3()

conn, err = sqlenv:connect(db_path)
if conn == nil then
    print(err)
    os.exit(1)
end

cursor, err = conn:execute(sql)
if cursor == nil then
    print("Could not find symbol: ", arg[1])
    os.exit(1)
end

result = {}
result = cursor:fetch(result)
while result ~= nil do
    print("Symbol name\t\t:", result[1])
    print("Symbol kind\t\t:", result[2])
    print("Symbol type\t\t:", result[3])
    print("Symbol in file\t\t:", result[4])
    print("Symbol at line of file\t:", result[5])

    result = cursor:fetch(result)
end
