#! /usr/bin/lua

package.path=string.gsub(arg[0], "[^%/]+$", "?.lua;")..package.path
package.cpath=string.gsub(arg[0], "[^%/]+$", "?.so;")..package.cpath
require("lfs")
require("luasql.sqlite3")
require("tagslib")
--require("test")


sqlenv = luasql.sqlite3()

function parse_args()
end

if work_dir == nil then
    work_dir = lfs.currentdir()
end

argdb_path = work_dir.."/.luatags/args.db"
tagdb_path = work_dir.."/.luatags/tags.db"


argdb_conn, err = sqlenv:connect(argdb_path)
if argdb_conn == nil then
    print("Can not open args.db:")
    print(err)
    os.exit(1)
end
local cursor = argdb_conn:execute([[
select count(*) from sqlite_master where type='table' and name='args'
]])
if tonumber(cursor:fetch()) ~= 1 then
    print("Table args does not exist.")
    os.exit(1)
end

tagdb_path, err = sqlenv:connect(tagdb_path)
if argdb_conn == nil then
    print("Can not open tags.db:")
    print(err)
    argdb_conn:close()
    os.exit(1)
end

function parse_file(fileinfo, tag_conn)
    print(fileinfo[1])
end
function parse_all_files(arg_conn, tag_conn)
    local cursor = arg_conn:execute([[select * from args]])
    
    local result = {}
    result = cursor:fetch(result)
    while result ~= nil do
        parse_file(result, tag_conn)
        result = cursor:fetch(result)
    end
end
parse_all_files(argdb_conn, tagdb_conn)


