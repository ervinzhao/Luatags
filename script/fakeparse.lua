#! /usr/bin/lua

package.path=string.gsub(arg[0], "[^%/]+$", "?.lua;")..package.path
package.cpath=string.gsub(arg[0], "[^%/]+$", "?.so;")..package.cpath
require("lfs")
require("luasql.sqlite3")
require("tagslib")
require("luaclang")
--require("test")


sqlenv = luasql.sqlite3()

function parse_args()
end

if work_dir == nil then
    work_dir = lfs.currentdir()
end

argdb_path = work_dir.."/.luatags/args.db"
tagdb_path_save = work_dir.."/.luatags/tags.db"
--tagdb_path = ":memory:"
tagdb_path = "/tmp/tags.db"


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
else
    cursor:close()
end

tagdb_conn, err = sqlenv:connect(tagdb_path)
if tagdb_conn == nil then
    print("Can not open tags.db:")
    print(err)
    argdb_conn:close()
    os.exit(1)
end

function update_tag(tag, tag_conn)
    if tag.usr == "" then
        print("No USR, give up.")
        return
    end
    local sql = string.format("select usr,name,kind from symbols where usr='%s'", tag.usr)
    local cur,err = tag_conn:execute(sql)

    if cur == nil then
        print(err)
        return
    end

    local result = cur:fetch();
    local update_sql = nil
    if result ~= nil then
        if result[1] == "decl" then
            if tag.kind == "define" then
                update_sql = string.format(
                [[update symbols name='%s',kind='%s',type='%s',parent='%s',file='%s',line=%d
                where usr='%s']],
                tag.name, tag.kind, tag.type, tag.parent, tag.file, tag.line, tag.usr);
            end
        end
    else
        update_sql = string.format(
        [[insert into symbols values('%s', '%s', '%s', '%s', '%s', '%s', '%d')]],
        tag.usr, tag.name, tag.kind, tag.type, tag.parent, tag.file, tag.line)
    end

    cur:close()
    if update_sql then
--        print(update_sql)
        tag_conn:execute(update_sql)
    end
end

function parse_visitor(cursor, parent, fileinfo, tag_conn)
    local kind = cursor:getKind()
    local tag = {}


    if kind == clang.cursorkind.StructDecl
        or kind == clang.cursorkind.UnionDecl
        or kind == clang.cursorkind.ClassDecl
        or kind == clang.cursorkind.EnumDecl
        or king == clang.cursorkind.EnumConstantDecl
        or kind == clang.cursorkind.FunctionDecl
        or kind == clang.cursorkind.VarDecl
        or kind == clang.cursorkind.TypedefDecl
        then
        tag.name = cursor:getSpelling()
        local def
        if cursor:isDefinition() then
            -- tag.line = 
            def = cursor
            tag.kind = "define"
        else
            def = cursor:getDefinition()
            --return clang.visitor.continue
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
        tag.type = ""
        tag.parent = def:getSemanticParent():getSpelling()
        if tag.file == nil then
            --print(tag.name.."\t"..clang.getFileName(tag.file).."\t"..tostring(tag.line)..";")
            --print("USR:"..def:getUSR())
            tag.file = ""
        else
            tag.file = clang.getFileName(tag.file)
        end
        update_tag(tag, tag_conn)
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

function parse_file(fileinfo, tag_conn)
	local filepath = fileinfo[1]
	local filedir = fileinfo[2]
	if lfs.chdir(filedir) == nil then
		return nil
	end
    if lfs.attributes(fileinfo[1]) == nil then
        return nil
    end
    if not(string.format(fileinfo[1], "%.c$")
        or string.format(fileinfo[1], "%.cpp$")
        or string.format(fileinfo[1], "%.cxx$")) then
    end
	print("Filename:"..fileinfo[1])
    print("File dir:"..fileinfo[2])

	local index = clang.createIndex(0, 0)
	local tu = clang.createTUFromSourceFile(index, filepath, fileinfo[3])
	if tu == nil then
		-- TODO: LOG
        print("-------------------")
        clang.disposeIndex(index)
		return nil
	end

    local rootcursor = clang.getTUCursor(tu)
    clang.visitChildren(rootcursor, parse_visitor, fileinfo, tag_conn)
    clang.disposeTU(tu)
    clang.disposeIndex(index)
    return true
end

function prepare_tagdb(tag_conn)
    tag_conn:execute([[create table if not exists symbols
    (usr varchar(1024) primary key, name varchar(1024),
    kind char(16), type char(16),
    parent varchar(1024), file varchar(1024), line int)]])
end

function parse_all_files(arg_conn, tag_conn)
    local cursor = arg_conn:execute([[select * from args]])

    prepare_tagdb(tag_conn)
    
    local result = {}
    local count = 0
    result = cursor:fetch(result)
    while result ~= nil do
        local ret = parse_file(result, tag_conn)
        result = cursor:fetch(result)
        if count > 70 then
--            break
        end
--        count = count + 1
    end

    cursor:close()
    --local attach_db, err = sqlenv:connect(tagdb_path_save)
    --local attach = string.format("attach ':memory:' as tags")
    --print(attach)
    --attach_db:execute(attach)
end
parse_all_files(argdb_conn, tagdb_conn)
argdb_conn:close()
tagdb_conn:close()

