#! /bin/sh


check_build()
{
    echo "Checking build..."
    if [ ! -f luabind/luaclang.so ]
    then
        echo "luabind/luaclang.so doesn't exist."
        exit 1
    fi
    if [ ! -f script/fakemake ]
    then
        echo "script/fakemake doesn't exist."
        exit 1
    fi
    if [ ! -f script/fakecc.lua ]
    then
        echo "script/fakecc.lua doesn't exist."
        exit 1
    fi
    if [ ! -f script/fakeld.lua ]
    then
        echo "script/fakeld.lua doesn't exist."
        exit 1
    fi
}

install()
{
    echo "Going to install..."
    if [ -z $1 ]
    then
        installpath="$HOME/luatags"
        echo "Use default prefix: $installpath"
        if [ ! -d $installpath ]
        then
            mkdir $installpath
        fi
    fi

    if [ ! -d $installpath ]
    then
        echo "Path is not a directory or doesn't exist."
        exit 1
    fi
    if [ ! -w $installpath ]
    then
        echo "Path is not writable."
        exit 1
    fi


    pathbin="$installpath/bin"
    if [ ! -d $pathbin ]
    then
        if [ -f $pathbin ] 
        then
            rm $pathbin
        fi
        mkdir $pathbin
        if [ 0 -ne $? ]
        then
            echo "mkdir failed: $pathbin"
            exit 1
        fi
    fi
    pathshare="$installpath/share"
    pathsharelua="$pathshare/lua/"
    pathshareluav="$pathshare/lua/5.1/"
    if [ ! -d $pathshare ]
    then
        mkdir $pathshare
    fi
    if [ ! -d $pathsharelua ]
    then
        mkdir $pathsharelua
    fi
    if [ ! -d $pathshareluav ]
    then
        mkdir $pathshareluav
    fi

    cp luabind/luaclang.so       $pathbin/
    cp luabind/luaposix.so       $pathbin/
    cp script/fakecc.lua         $pathbin/fakecc
    cp script/fakeld.lua         $pathbin/fakeld
    cp script/fakedaemon.lua     $pathbin/fakedaemon
    cp script/fakedaemonexit.lua $pathbin/fakedaemonexit
    cp script/fakemake           $pathbin/fakemake
    cp script/tagslib.so         $pathbin/tagslib.so
    cp script/test.lua           $pathbin/test.lua
    cp script/fakeparse.lua      $pathbin/fakeparse
    cp lualib/clangaux.lua       $pathshareluav/clangaux.lua

    chmod u+x $pathbin/fakedaemonexit
}


check_build

install $1
