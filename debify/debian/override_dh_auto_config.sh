#!/bin/bash

source debian/vars.sh

set -x

export bdir=`pwd`
echo "PWD" `pwd`
ls -d *
ls -ld /usr/include/linux/aio_abi.h

cp $SOURCE2 .
sed -e 's|%%DEFAULTSTART%%|2 3 4 5|g' -e 's|%%DEFAULTSTOP%%|0 1 6|g' \
    -e 's|%%PROVIDES%%|nginx|g' < $SOURCE2 > nginx.init
sed -e 's|%%DEFAULTSTART%%||g' -e 's|%%DEFAULTSTOP%%|0 1 2 3 4 5 6|g' \
    -e 's|%%PROVIDES%%|nginx-debug|g' < $SOURCE2 > nginx-debug.init

mkdir -p ngx_http_pipelog_module/
cp $SOURCE20 ngx_http_pipelog_module/ngx_http_pipelog_module.c
cp $SOURCE21 ngx_http_pipelog_module/config

export LDFLAGS="$LDFLAGS $WITH_LD_OPT"
export CFLAGS="$CFLAGS $WITH_CC_OPT -I/usr/include/x86_64-linux-gnu -I/usr/include"
export EXTRA_CFLAGS=$CFLAGS
export EXTRA_CXXFLAGS=$CFLAGS
export EXTRA_LDFLAGS=$LDFLAGS

#sed -i '6iset -x' configure
#sed -i '42iecho ""; echo "SHOW"; cat -n $NGX_AUTOTEST.c; echo "END SHOW"' auto/feature
#sed -i '51iecho "ERR"; cat $NGX_AUTOCONF_ERR; echo ""; echo "XXX: 001"; echo $ngx_test; echo "XXX: 002"; echo ""; echo "XXX: 003"' auto/feature

#build debug
./configure $BASE_CONFIGURE_ARGS \
    --with-cc-opt="$WITH_CC_OPT" \
    --with-ld-opt="$WITH_LD_OPT" \
    --with-debug \
    --with-ipv6 \
    --add-dynamic-module=/opt/cpanel/ea-ngx-brotli-src \
    --add-dynamic-module=ngx_http_pipelog_module

make

mv $bdir/objs/nginx $bdir/objs/nginx-debug

# build actual
./configure $BASE_CONFIGURE_ARGS \
    --with-cc-opt="$WITH_CC_OPT" \
    --with-ld-opt="$WITH_LD_OPT" \
    --with-ipv6 \
    --add-dynamic-module=/opt/cpanel/ea-ngx-brotli-src \
    --add-dynamic-module=ngx_http_pipelog_module

make

cp -f $SOURCE22 .
cp -f $SOURCE23 .
cp -f $SOURCE24 .
cp -f $SOURCE25 .
