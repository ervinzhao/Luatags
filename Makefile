all:luabind/clangbind.c
	make -C luabind
	make -C script

.PHONY:clean
clean:
	rm luabind/luaclang.so
	rm script/tagslib.so

.PHONY:install
install:
	@./install.sh "$(prefix)"
