all:luabind/clangbind.c
	make -C luabind
	make -C fakecc

.PHONY:clean
clean:
	rm luabind/luaclang.so
	rm fakecc/tagslib.so

.PHONY:install
install:
	@./install.sh "$(prefix)"
