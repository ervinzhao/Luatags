#! /usr/bin/lua

package.path=string.gsub(arg[0], "[^%/]+$", "?.lua;")..package.path                                                                
package.cpath=string.gsub(arg[0], "[^%/]+$", "?.so;")..package.cpath
require("lfs")
require("luasql.sqlite3")
require("tagslib")
require("luaclang")
require("luaposix")


fifo_path = "/tmp/luatags"

ret = posix.mkfifo(fifo_path)
if ret ~= 0 then
    print("Error: open fifo failed!")
    os.exit(-1)
end

for key,value in pairs(posix) do
    print(key, '\t', value)
end
fifo = posix.open(fifo_path, {"RDONLY"})
print(fifo)
