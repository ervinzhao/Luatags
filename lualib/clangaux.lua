
local clang = require("luaclang")

module("clangaux")

function getLinkageString(linkage)
    if linkage == clang.linkage.invalid then
        return "invalid"
    elseif linkage == clang.linkage.nolinkage then
        return "nolinkage"
    elseif linkage == clang.linkage.internal then
        return "internal"
    elseif linkage == clang.linkage.unique then
        return "unique"
    elseif linkage == clang.linkage.external then
        return "external"
    end
    return nil 
end

function getTypeString(kind_string)                                                                                        
    if kind_string == "ClassDecl" then
        return "c"
    elseif kind_string == "MacroDefinition" then
        return "d"
    elseif kind_string == "EnumConstantDecl" then
        return "e"
    elseif kind_string == "FunctionDecl"
        or kind_string == "CXXMethod" then
        return "f"
    elseif kind_string == "EnumDecl" then
        return "g"
    elseif kind_string == "FieldDecl" then
        return "m"
    elseif kind_string == "StructDecl" then
        return "s"
    elseif kind_string == "TypedefDecl" then
        return "t"
    elseif kind_string == "UnionDecl" then
        return "u"
    elseif kind_string == "VarDecl" then
        return "v"
    end 
    return ""
end

function getKindString(kind)                                                                                               
    --FIXME:Need a better implementation.
    for key, value in pairs(clang.cursorkind) do 
        if value == kind then
            return key
        end 
    end
    return ""
end 


