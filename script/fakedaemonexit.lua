#! /usr/bin/lua

package.path=string.gsub(arg[0], "[^%/]+$", "?.lua;")..package.path                                                                
package.cpath=string.gsub(arg[0], "[^%/]+$", "?.so;")..package.cpath
require("luaposix")
require("json")

if posix.access(arg[1]) then
    fifo, err = posix.open(arg[1], {"WRONLY"})
    if fifo ~= nil then
        msg = {}
        msg.cmd = "exit"
        msg_str = json.encode(msg)
        msg_str = msg_str.."\0"
        posix.sleep(1)
        posix.write(fifo, msg_str)

        posix.close(fifo)
    else
        print(err)
    end
end
