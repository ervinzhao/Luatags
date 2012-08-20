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


sqlenv = luasql.sqlite3()


if work_dir == nil then
    work_dir = lfs.currentdir()
end

g_config = {}
g_config.db_files = "/.luatags/args.db"
g_config.db_refs  = "/.luatags/tags.db"    

config = {}
config.current_dir = lfs.currentdir()
--config.memory_path = ":memory:"
--tagdb_path = "/tmp/tags.db"

--[[
--file:    Parse single file.
--output:  Output database file.
--memory:  Use memory database of sqlite.
--no-parse:Don't parse source files.
--print-tags: Print tags to file 'tags' in current direcroty.
]]--
function parse_args()
    local options = {}
    options.jobs = 4
    options.table_max = 512
    local count = table.maxn(arg)
    local i = 1
    while i <= count do
        if arg[i] == "--file" then
            options.single_file = arg[i+1]
            i = i+1
        elseif arg[i] == "--output" then
            options.tagdb_path = arg[i+1]
            i = i+1
        elseif arg[i] == "--memory" then
            options.use_memory_db = true
        elseif arg[i] == "--no-parse" then
            options.no_parse = true
        elseif arg[i] == "--print-tags" then
            options.print_tags = true
        elseif arg[i] == "--debug" then
            options.debug_info = true
        elseif arg[i] == "--no-file-db" then
            options.no_file_db = true
        elseif arg[i] == "--source-dir" then
            options.source_dir = arg[i+1]
            i = i+1
        elseif arg[i] == "--target-dir" then
            options.target_dir= arg[i+1]
            i = i+1
        elseif arg[i] == "--jobs" then
            local jobs = tonumber(arg[i+1])
            if jobs ~=nil then
                options.jobs = jobs
            end
            i = i+1
        --[[elseif arg[i] == "--build-dir" then
            options.build_dir = arg[i+1] 
            i = i+1]]--
        end
        i = i+1
    end
    return options
end

function setup_path(config, options)
    if options.source_dir == nil and options.target_dir == nil then
        print("Error :Source directory or target directory must be set.")
        os.exit(1)
    elseif options.target_dir == nil then
        options.target_dir = options.source_dir
    end
    if lfs.attributes(options.target_dir, "mode") ~= "directory" then
        print("Error :")
        os.exit(1)
    end
    if options.source_dir ~= nil
        and lfs.attributes(options.source_dir, "mode") ~= "directory" then
        print("Error :")
        os.exit(1)
    end
    config.db_refs  = options.target_dir..g_config.db_refs
    if options.no_file_db == nil then
        config.db_files = options.target_dir..g_config.db_files
        if not posix.access(config.db_files, "r") then
            if options.single_file then
                return
            end
            print("Error :Could not find file database.")
            print("Path :", config.db_files)
            os.exit(1)
        end
    elseif options.source_dir == nil then
        print("Error :Source directory must be set when use --no-file-db option.")
        os.exit(1)
    end

end

function prepare_single_file(parse_info)
    local conn, err
    conn, err = sqlenv:connect(config.db_files)
    if conn == nil then
        return
    end
    filepath = tagslib.realpath(options.single_file)
    if filepath == nil then
        print("Error :Could not access file :", options.single_file)
        os.exit(1)
    end
    local cursor
    local sql = string.format([[
    select filename,filetype,dir,argument,output from args where filename='%s']],
    filepath)
    cursor, err = conn:execute(sql)
    if cursor == nil then
        print(err)
        return
    end
    parse_info.db_files_cursor = cursor
end

function prepare_files(parse_info, files_info)
    if options.single_file then
        prepare_single_file(parse_info)
        return
    end
    if options.no_file_db == nil then
        local conn
        local err
        conn, err = sqlenv:connect(config.db_files)
        if conn == nil then
            print("Error :Could not open file database.")
            os.exit(1)
        end
        local cursor, err = conn:execute([[
        select count(*) from sqlite_master where type='table' and name='args'
        ]])
        if tonumber(cursor:fetch()) ~= 1 then
            print("Error :Table args does not exist in file database.")
            os.exit(1)
        end
        cursor = conn:execute([[select filename,filetype,dir,argument,output from args]])

        parse_info.db_files_conn = conn
        parse_info.db_files_cursor = cursor
    end
end

function prepare_db_refs(parse_info)
    local conn
    local err
    conn = sqlenv:connect(config.db_refs)
    if conn == nil then
        print("Error :Could not open reference database.")
        os.exit(1)
    end
    conn:execute([[create table if not exists symbols
    (usr varchar(1024) primary key, name varchar(1024), membername varchar(1024),
    kind char(16), type char(32),
    parent varchar(1024), file varchar(1024), line int, linkage varchar(16))]])

    conn:execute([[create table if not exists headers
    (header varchar(1024), source varchar(1024), line int)]])

    parse_info.db_refs_conn = conn
end

function prepare_parse(parse_info)
end

function get_files_from_dir(parse_info, files_info, files_table)
end

function get_files_from_db(parse_info, files_info, files_table)
    local cursor = parse_info.db_files_cursor
    local result = {}
    local count = 0
    result = cursor:fetch(result)
    while result ~= nil do
        count = count + 1
        files_table[count] = std.tree.clone(result)
        result = cursor:fetch(result)
        if count >= options.table_max then
            break
        end
    end
    files_table.count = count
    if result == nil then
        files_info.done = true
    end
end

function get_files(parse_info, files_info, files_table)
    if options.single_file then
        local file = {}
        if parse_info.db_files_cursor then
            file = parse_info.db_files_cursor:fetch(file)
        else
            file[1] = tagslib.realpath(options.single_file)
            file[2] = "source"
            file[3] = "."
            file[4] = ""
            file[5] = ""
        end
        files_table[1] = file;
        files_table.count = 1;
        files_info.done = true
        return
    end
    if options.no_file_db then
        get_files_from_dir(parse_info, files_info, files_table)
    else
        get_files_from_db(parse_info, files_info, files_table)
    end
end

function write_to_pipe(obj, pipewrite)
    local obj_str = json.encode(obj)
    obj_str = obj_str.."\0"
    posix.write(pipewrite, obj_str)
end

function get_kind_string(kind)
    for key, value in pairs(clang.cursorkind) do
        if value == kind then
            return key
        end
    end
    return ""
end

function parse_visitor(cursor, parent, fileinfo, pipewrite)
    local kind = cursor:getKind()
    local tag = {}
    tag.cmd = "tag"


    if kind == clang.cursorkind.StructDecl
        or kind == clang.cursorkind.UnionDecl
        or kind == clang.cursorkind.ClassDecl
        or kind == clang.cursorkind.EnumDecl
        or kind == clang.cursorkind.FieldDecl
        or king == clang.cursorkind.EnumConstantDecl
        or kind == clang.cursorkind.FunctionDecl
        or kind == clang.cursorkind.VarDecl
        or kind == clang.cursorkind.TypedefDecl
        or kind == clang.cursorkind.MacroDefinition
        then
        tag.name = cursor:getSpelling()
        tag.linkage = clangaux.getLinkageString(cursor:getLinkage())
        local def
        if cursor:isDefinition() then
            --print(tag.name, "===")
            def = cursor
            tag.kind = "define"
        else
            --print(tag.name, "---")
            def = cursor:getDefinition()
            if def:isNull() then
                tag.kind = "decl"
                def = cursor
            else
                tag.kind = "define"
            end
        end
        tag.usr = def:getUSR()
        local loc = def:getLocation()
        tag.file, tag.line, tag.column = loc:getExpansion()
        tag.type = get_kind_string(kind)
        tag.parent = def:getSemanticParent():getSpelling()
        if tag.file == nil then
            --print(tag.name.."\t"..clang.getFileName(tag.file).."\t"..tostring(tag.line)..";")
            --print("USR:"..def:getUSR())
            tag.file = ""
        else
            tag.file = tagslib.realpath(clang.getFileName(tag.file))
        end

        if kind == clang.cursorkind.FieldDecl then
            tag.member = tag.name
            tag.name = ""
        elseif kind == clang.cursorkind.CXXMethod then
            tag.member = tag.name
        else
            tag.member = ""
        end

        write_to_pipe(tag, pipewrite)
    elseif kind == clang.cursorkind.InclusionDirective then
        tag.cmd = "header"
        tag.file = fileinfo[1]
        tag.header = cursor:getIncludedFile()
        if tag.header ~= nil then
            tag.header = tagslib.realpath(clang.getFileName(tag.header))
            local loc = cursor:getLocation()
            local file, column
            file, tag.line, column = loc:getExpansion()
            
            write_to_pipe(tag, pipewrite)
        end
    end

    if kind == clang.cursorkind.Namespace
        or kind == clang.cursorkind.StructDecl
        or kind == clang.cursorkind.UnionDecl
        or kind == clang.cursorkind.EnumDecl then
        if debug_info then
            print("Parent of "..cursor:getSpelling())
            print(cursor:getSemanticParent():getSpelling())
        end
        return clang.visitor.recurse
    end


    if kind == clang.cursorkind.UnexposedDecl then
    elseif kind == clang.cursorkind.StructDecl then
    elseif kind == clang.cursorkind.UnionDecl then
    elseif kind == clang.cursorkind.ClassDecl then
    elseif kind == clang.cursorkind.EnumDecl then
    elseif kind == clang.cursorkind.FieldDecl then
    elseif kind == clang.cursorkind.EnumConstantDecl then
    elseif kind == clang.cursorkind.FunctionDecl then
    elseif kind == clang.cursorkind.VarDecl then
    elseif kind == clang.cursorkind.ParmDecl then
    elseif kind == clang.cursorkind.TypedefDecl then
    elseif kind == clang.cursorkind.CXXMethod then
    elseif kind == clang.cursorkind.Namespace then
    elseif kind == clang.cursorkind.Constructor then
    elseif kind == clang.cursorkind.Destructor then
    elseif kind == clang.cursorkind.ConversionFunction then
    elseif kind == clang.cursorkind.TemplateTypeParameter then
    elseif kind == clang.cursorkind.NonTypeTemplateParameter then
    elseif kind == clang.cursorkind.TemplateTemplateParameter then
    elseif kind == clang.cursorkind.FunctionTemplate then
    elseif kind == clang.cursorkind.ClassTemplate then
    elseif kind == clang.cursorkind.ClassTemplatePartialSpecialization then
    elseif kind == clang.cursorkind.NamespaceAlias then
    elseif kind == clang.cursorkind.UsingDirective then
    elseif kind == clang.cursorkind.UsingDeclaration then
    elseif kind == clang.cursorkind.TypeAliasDecl then
    end
    return clang.visitor.continue
end


function do_parse_single_file(parse_info, fileinfo, pipewrite)
	local filepath = fileinfo[1]
	local filedir = fileinfo[3]
    --print(json.encode(fileinfo))
	if lfs.chdir(filedir) == nil then
		return nil
	end
    if lfs.attributes(fileinfo[1]) == nil then
        return nil
    end


	local index = clang.createIndex(0, 0)
	local tu = clang.createTUFromSourceFile(index, filepath, fileinfo[4])
	if tu == nil then
        clang.disposeIndex(index)
		return nil
	end

    local rootcursor = clang.getTUCursor(tu)
    clang.visitChildren(rootcursor, parse_visitor, fileinfo, pipewrite)
    clang.disposeTU(tu)
    clang.disposeIndex(index)
    return true
end

function do_parse_job(parse_info, files_table, first, last, pipewrite, pid)
    local i = first
    while i < (last+1) do
        do_parse_single_file(parse_info, files_table[i], pipewrite)
        i = i+1
    end

    local cmd_exit = {}
    cmd_exit.cmd = "exit"
    cmd_exit.pid = pid
    write_to_pipe(cmd_exit, pipewrite)
end

function table_count(t)
    local count = 0
    for k,v in pairs(t) do
        count = count + 1
    end
    return count
end

function handle_msg_header(header, conn)
    local sql = string.format([[select header,source from headers 
    where header='%s' and source='%s']], header.header, header.file)
    local cur,err = conn:execute(sql)

    if cur == nil then
        print(err)
        return
    end

    local result = {}
    result = cur:fetch(result)
    if result == nil then
        sql =string.format([[insert into headers (header, source, line)
        values('%s', '%s', %d)]], header.header, header.file, header.line)
    else
        sql = nil
    end

    cur:close()
    if sql ~= nil then
        conn:execute(sql)
    end
end

function handle_msg_tag(tag, tag_conn)
    if tag.usr == "" then
        --print("No USR, give up.")
        --print(json.encode(tag))
        return
    end
    local sql = string.format("select usr,name,kind from symbols where usr='%s'", tag.usr)
    local cur,err = tag_conn:execute(sql)

    if cur == nil then
        print(err)
        return
    end

    if debug_info then
        local debug = string.format("name: %s\tmember: %s\tfile: %s\tusr: %s\tkind: %s\ttype: %s",
            tag.name, tag.member, tag.file, tag.usr, tag.kind, tag.type)
        print(debug)
    end

    local result = {}
    result = cur:fetch(result);
    local update_sql = nil
    if result ~= nil then
        if debug_info then
            print("result kind: "..result[3])
        end

        if result[3] == "decl" then
            if tag.kind == "define" then
                update_sql = string.format(
                [[update symbols set name='%s',membername='%s',kind='%s',type='%s',parent='%s',file='%s',line=%d,
                linkage='%s' where usr='%s']],
                tag.name, tag.member, tag.kind, tag.type, tag.parent, tag.file, tag.line, tag.linkage, tag.usr);
            end
        else
            --print("-->>-->>", result[3])
        end
    else
        update_sql = string.format(
        [[insert into symbols (usr, name, membername, kind, type, parent, file, line, linkage)
        values('%s', '%s', '%s', '%s', '%s', '%s', '%s', %d, '%s')]],
        tag.usr, tag.name, tag.member, tag.kind, tag.type, tag.parent, tag.file, tag.line, tag.linkage)
        --print(update_sql)
    end

    cur:close()
    if update_sql then
        tag_conn:execute(update_sql)
    end
end

function handle_msg(msg_json, parse_info)
    --print("-->", msg_json)
    local msg = json.decode(msg_json)
    if msg.cmd == "exit" then
        return nil, msg.pid
    elseif msg.cmd == "tag" then
        handle_msg_tag(msg, parse_info.db_refs_conn)
    elseif msg.cmd == "header" then
        handle_msg_header(msg, parse_info.db_refs_conn)
    end
    parse_info.tran = parse_info.tran + 1
    if parse_info.tran >= 102400 then
        parse_info.db_refs_conn:execute("commit")
        parse_info.db_refs_conn:execute("begin")
    end
    return true
end

function get_msg_from_pipe(parse_info, piperead, buf)
    local msg, err
    local last_msg
    local ret, pid
    while true do
        if buf.last_msg ~= nil then
            msg = buf.last_msg
            buf.last_msg = nil
        else
            msg, err = posix.read(piperead, 512)
        end
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
                    ret, pid = handle_msg(msg_json, parse_info)
                    last_msg = string.sub(msg, last_pos+1, -1)
                    if string.len(last_msg) == 0 then
                        last_msg = nil
                    end
                    if ret == nil then
                        buf.last_msg = last_msg
                        return pid
                    end
                    msg = last_msg
                else
                    last_msg = msg
                    msg = nil
                end
            end
        else
            return nil
        end
    end
end

function update_database(parse_info, piperead)
    local buf = {}
    parse_info.db_refs_conn:execute("begin")
    parse_info.tran = 0
    while true do
        ret = get_msg_from_pipe(parse_info, piperead, buf)
        if ret == nil then
            break
        else
            parse_info.proc[ret] = nil
            if table_count(parse_info.proc) == 0 then
                break
            end
        end
    end
    parse_info.db_refs_conn:execute("commit")
end

function do_parse(parse_info, files_table)
    local first 
    local last = 0
    local jobs = 1
    local piperead, pipewrite
    piperead, pipewrite = posix.pipe()
    parse_info.proc = {}
    while jobs <= options.jobs do
        first = last + 1
        last = math.ceil(first + files_table.count/options.jobs)
        if last > files_table.count then
            last = files_table.count
        end
        local pid = posix.fork()
        if pid == 0 then
            pid = posix.getpid("pid")
            do_parse_job(parse_info, files_table, first, last, pipewrite, pid)
            os.exit(0)
        else
            parse_info.proc[pid] = true
        end
        jobs = jobs+1
    end
    update_database(parse_info, piperead)
    parse_info.proc = nil
end

options = parse_args()
setup_path(config, options)

files_table = {}
files_info  = {}
parse_info  = {}

prepare_files(parse_info, files_info)
prepare_db_refs(parse_info)
prepare_parse(parse_info)
repeat
    get_files(parse_info, files_info, files_table)
    do_parse(parse_info, files_table)
until files_info.done
os.exit(0)


function parse_file(fileinfo, tag_conn)
end


function parse_single_file(arg_conn, tag_conn, filename)
    local sql = string.format("select filename,dir,argument,output from args where filename='%s'", filename)
    local cursor = arg_conn:execute(sql)

    local result = {}
    result = cursor:fetch(result)
    if result == nil then
        print("No such file.")
        print("Use default arguments.")
        result = {}
        result[1] = filename
        result[2] = "."
        result[3] = ""
        parse_file(result, tag_conn)
        --os.exit()
    else
        parse_file(result, tag_conn)
    end

    cursor:close()
end

function print_tags_file(tag_conn)
    local sql = string.format([[select name,kind,type,file,line from symbols where name<>"" order by name]])
    local cursor = tag_conn:execute(sql)
    local tag_file = io.open("tags", "w+")
    tag_file:write("!_TAG_FILE_SORTED\t1\t\n")

    local result = {}
    result = cursor:fetch(result)
    while result ~= nil do
        --tag_file:write(result[1].."\t"..result[4].."\t"..result[5]..";\n")
        local tag_str = result[1].."\t"..result[4].."\t"..result[5]
        tag_str = tag_str..";\""

        local type_string = get_type_string(result[3])
        if type_string ~= "" then
            tag_str = tag_str.."\t".."kind:"..type_string
        end
        tag_str = tag_str.."\n"

        print(tag_str)
        tag_file:write(tag_str)
        result = cursor:fetch(result)
    end

    cursor:close()
    tag_file:close()
end

if no_parse == nil then
    if single_file then
        parse_single_file(argdb_conn, tagdb_conn, single_file)
    else
        parse_all_files(argdb_conn, tagdb_conn)
    end
end

lfs.chdir(work_dir)
if print_tags then
    print("Print tags file!")
    print_tags_file(tagdb_conn)
end

argdb_conn:close()
tagdb_conn:close()

