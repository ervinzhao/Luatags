#CC=clang
CC=gcc
all:luaclang luaposix

luaclang:
	${CC} clangbind.c -shared -o luaclang.so -lclang -fPIC -Wall 

luaposix:
	${CC} lposix.c -shared -o luaposix.so -fPIC -Wall
