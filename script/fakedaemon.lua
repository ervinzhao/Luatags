#! /usr/bin/lua

package.path=string.gsub(arg[0], "[^%/]+$", "?.lua;")..package.path                                                                
package.cpath=string.gsub(arg[0], "[^%/]+$", "?.so;")..package.cpath
require("lfs")
require("luasql.sqlite3")
require("tagslib")
require("luaposix")
require("json")


sqlenv = luasql.sqlite3()
fifo_path = "/tmp/luatags"
db_file_path = nil
db_tmp_path = "/tmp/args.db"

if posix.access(fifo_path, "f") then
    os.remove(fifo_path)
end

ret = posix.mkfifo(fifo_path)
if ret ~= 0 then
    print("Error: make fifo failed!")
    os.exit(-1)
end

function prepare_db_file()
    local outpath = os.getenv("FAKEOUTPUT")
    if outpath == nil then
        print("Error: bad path to output.")
        os.exit(1)
    end

    local pathmod = lfs.attributes(outpath, "mode")
    if pathmod ~= "directory" then
        print("Error: path is not a directory.")
        os.exit(1)
    end

    -- make sure ".luatags" exist.
    local tagspath = outpath.."/.luatags"
    local tagsmod  = lfs.attributes(tagspath, "mode")
    if tagsmod ~= nil then
        if tagsmod ~= "directory" then
            os.remove(tagspath)
            lfs.mkdir(tagspath)
        end
    else
        lfs.mkdir(tagspath)
    end

    db_file_path = tagspath.."/args.db"
    local dbpath = db_tmp_path
    
    if posix.access(db_file_path, "r") then
        os.rename(db_file_path, db_tmp_path)
    end

    local conn = sqlenv:connect(dbpath)
    if conn == nil then
        print("Error: can not open database.")
        os.exit(1)
    end
    return conn
end

function prepare_db_table(conn)
    -- make sure the table "args" exist.
    local ret, err = 
    conn:execute([[create table if not exists args
    (filename varchar(1024) primary key, dir varchar(1024),
    argument varchar(1024), output varchar(1024))]])
    if ret == nil then
        print(err)
        return 1
    end

end

function handle_arguments(argument, conn)
    local sqldel = string.format(                                                                                              
        "delete from args where filename='%s'", argument.filerpath)
    local ret, err = conn:execute(sqldel)
    print(sqldel)
    local sqlstr = string.format(
        "insert into args values('%s', '%s', '%s', '%s')",
        argument.filerpath, argument.dir, argument.argument, argument.outfile)
    ret, err = conn:execute(sqlstr)
    print(sqlstr)
    if ret == nil then
        print("Error:", err)
    end
end


function handle_msg(msg, conn) 
    local msg_table = json.decode(msg)
    if msg_table == nil then 
        print("Error: bad message:\t", msg)
        return true 
    end
    if msg_table.cmd == "exit" then
        conn:close()
        return nil
    end
    if msg_table.cmd == "argument" then
        handle_arguments(msg_table, conn)
    end
    return true
end

function main_loop(fd, conn)
    local last_msg
    while true do
        local msg, err
        local ret
        msg, err = posix.read(fd, 512)
        if string.len(msg) == 0 then
            posix.sleep(1)
        elseif msg ~= nil then
            if last_msg ~= nil then
                msg = last_msg..msg
                last_msg = nil
            end
            while msg ~= nil do
                local last_pos = string.find(msg, "\0")
                if last_pos ~= nil then
                    local msg_json = string.sub(msg, 1, last_pos-1)
                    ret = handle_msg(msg_json, conn)
                    last_msg = string.sub(msg, last_pos+1, -1)
                    msg = last_msg
                else
                    last_msg = msg
                    msg = nil
                end
            end
        else
            print("oooooooooooooo")
        end
        if ret == nil then
            return
        end
    end
end

function do_atexit(fifo, fifo_wr, conn)
    conn:close()
    posix.close(fifo)
    posix.close(fifo_wr)
    os.execute("mv "..db_tmp_path.." "..db_file_path)
    os.remove(fifo_path)
    print("fakedaemon exit normally.")
end

fifo, err = posix.open(fifo_path, {"RDONLY"})
if fifo ~= nil then
    fifo_wr, err = posix.open(fifo_path, {"WRONLY"})
    if fifo_wr == nil then
        print(err)
        exit(-1)
    end
    local conn = prepare_db_file()
    prepare_db_table(conn)
    main_loop(fifo, conn)
    do_atexit(fifo, fifo_wr, conn)
else
    print("Error: open fifo failed!")
    print(err)
end

