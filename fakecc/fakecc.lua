#! /usr/bin/lua

package.path=string.gsub(arg[0], "[^%/]+$", "?.lua;")..package.path
package.cpath=string.gsub(arg[0], "[^%/]+$", "?.so;")..package.cpath
require("lfs")
require("luasql.sqlite3")
require("tagslib")

sqlenv = luasql.sqlite3()

help = {}
function help.set(list)
    local set = {}
    for _, e in ipairs(list) do
        set[e] = true 
    end
    return set
end

single_usefull = help.set{
    "-ansi", "-fno-asm", "-trigraphs", "-C",
    "-fsigned-bitfields", "-fsigned-char", "-funsigned-bitfields", "-funsigned-char",
}
double_usefull = help.set{
    "-Xpreprocessor", "-Xassembler", "-specs"
}
double_useless = help.set{
    "-aux-info", "-T", "-Xlinker", "-wrapper"
}
join_usefull = help.set{
    "-I", "-include", "-imacros", "-iprefix", "-idirafter",
    "-iwithprefix", "-iwithprefixbefore", "-isystem", "-imultilib", "-isysroot",
    "-B", "-x", "-specs="
}
join_useless = help.set{
    "-h", "-L", "-l",
    "-u", "-G", "-T", "-z",
    "-print-file-name"
} 

function parse_joined_arg(str)
    local ifjsarg, ifusefull, ifjoined
    for argname, _ in pairs(join_usefull) do
        local len = string.len(argname)
        if argname == string.sub(str, 1, len) then
            ifjsarg = true
            ifusefull = true
            if string.len(str) == len then
                ifjoined = true
            end
            break
        end
    end

    for argname, _ in pairs(join_useless) do
        local len = string.len(argname)
        if argname == string.sub(str, 1, len) then
            ifjsarg = true
            ifusefull = nil
            if string.len(str) == len then
                ifjoined = true
            end
            break
        end
    end

    return ifjsarg, ifusefull, ifjoined
end

function parse_arguments()

    local infiles = {}
    local argument = ""
    local outfile
    local outmode = "binary"
    local macros = {}

    -- parse arguments
    local count = table.maxn(arg)
    local i = 1
    while i <= count do
        if single_usefull[arg[i]] == true then
            argument = argument..arg[i].." "
        elseif double_usefull[arg[i]] == true then
            argument = argument..arg[i].." "..arg[i+1].." "
        elseif double_useless[arg[i]] == true then
            i = i+1
        else
            local ifjsarg, ifusefull, ifjoined
            ifjsarg, ifusefull, ifjoined = parse_joined_arg(arg[i])
            if ifjsarg == true then
                if ifusefull == true then
                    argument = argument..arg[i].." "
                    if ifjoined == nil then
                        argument = argument..arg[i+1].." "
                    end
                end
                if joined == nil then
                    i = i+1
                end
            else
                -- handle "-D" "-U" "-c" "-o" options
                -- handle other arguments and input files
                if arg[i] == "-c" then
                    outmode = ".o"
                elseif arg[i] == "-E" then
                    outmode = ".i"
                elseif arg[i] == "-S" then
                    outmode = ".s"
                elseif string.sub(arg[i], 1, 2) == "-o" then
                    if arg[i] == "-o" then
                        outfile = arg[i+1]
                        i = i+1
                    else
                        outfile = string.sub(arg[i], 3)
                    end
                elseif string.sub(arg[i], 1, 2) == "-D" 
                    or string.sub(arg[i], 1, 2) == "-U" then
                    if string.len(arg[i]) == 2 then
                        table.insert(macros, arg[i]..arg[i+1])
                        argument = argument..arg[i]..arg[i+1].." "
                        i = i+1
                    else
                        table.insert(macros, arg[i])
                        argument = argument..arg[i].." "
                    end
                elseif string.sub(arg[i], 1, 1) == "-" then
                    -- other arguments
                else
                    table.insert(infiles, arg[i])
                end
            end
        end
        i = i+1
    end

    -- handle output file
    if outfile == nil then
        if outmode == "binary" then
            outfile = "a.out"
        end
    end

    return infiles, argument, outfile, outmode
end

function parse_and_write(conn)

    -- make sure the table "args" exist.
    local ret, err = 
    conn:execute([[create table if not exists args
    (filename varchar(1024) primary key, dir varchar(1024),
    argument varchar(1024), output varchar(1024))]])
    if ret == nil then
        print(err)
        return 1
    end


    -- table of all input files
    local infiles = {}
    -- string of arguments
    local argument
    -- output file
    local outfile
    -- output mode
    local outmode

    infiles, argument, outfile, outmode = parse_arguments()

    if infiles == nil then
        return 1
    end
    local dir, err = lfs.currentdir()
    if dir == nil then
        print(err)
        return 1
    end

    for key, file in pairs(infiles) do
        local filerpath = tagslib.realpath(file)
        if filerpath == nil then
            infiles[key] = nil
        else
            infiles[key] = filerpath
        end

        if outfile == nil then
            outfile = string.gsub(file, "%.[%a]", outmode)
        end

        local sqldel = string.format(
            "delete from args where filename='%s'", filerpath)
        ret, err = conn:execute(sqldel)
        print(sqldel)
        local sqlstr = string.format(
            "insert into args values('%s', '%s', '%s', '%s')",
            filerpath, dir, argument, outfile)
        ret, err = conn:execute(sqlstr)
        print(sqlstr)
        if ret == nil then
            print("Error:", err)
        end
    end
    return 0
end

function main()
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

    local dbpath = tagspath.."/args.db"
    local conn = sqlenv:connect(dbpath)
    if conn == nil then
        print("Error: can not open database.")
        os.exit(1)
    end

    local ret = parse_and_write(conn)
    conn:close()
    return ret
end

local ret = main()
os.exit(ret)

