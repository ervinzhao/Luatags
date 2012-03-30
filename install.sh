#! /bin/sh


check_build()
{
    echo "Checking build..."
    if [ ! -f luabind/luaclang.so ]
    then
        echo "luabind/luaclang.so doesn't exist."
        exit 1
    fi
    if [ ! -f fakecc/fakemake ]
    then
        echo "fakecc/fakemake doesn't exist."
        exit 1
    fi
    if [ ! -f fakecc/fakecc.lua ]
    then
        echo "fakecc/fakecc.lua doesn't exist."
        exit 1
    fi
    if [ ! -f fakecc/fakeld.lua ]
    then
        echo "fakecc/fakeld.lua doesn't exist."
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

    cp luabind/luaclang.so       $pathbin/
    cp script/fakecc.lua         $pathbin/fakecc
    cp script/fakeld.lua         $pathbin/fakeld
    cp script/fakemake           $pathbin/fakemake
    cp script/tagslib.so         $pathbin/tagslib.so
    cp script/test.lua           $pathbin/test.lua
    cp script/fakeparse.lua   $pathbin/fakeparse
}


check_build

install $1
