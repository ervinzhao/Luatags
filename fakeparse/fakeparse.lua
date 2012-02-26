#! /usr/bin/lua

--package.path=string.gsub(arg[0], "[^%/]+$", "?.lua;")..package.path
--package.path=string.gsub(arg[0], "[^%/]+$", "?.so;")..package.path
require("lfs")
require("luasql.sqlite3")
require("tagslib")
require("test")


sqlevn = luasql.sqlite3()


print(package.path)
print(package.cpath)

print(arg[0])
str = string.gsub(arg[0], "[^%/]+%.lua$", "?.lua")
print(str)
