#!/bin/bash

mkdir ./nginx-build
pushd ./nginx-build

export NGINX_VER=$(cat /opt/cpanel/ea-nginx-ngxdev/nginx-ver)
tar xzf /opt/cpanel/ea-nginx-ngxdev/nginx-$NGINX_VER.tar.gz --strip-components 1

# SOURCES/0001-Fix-auto-feature-test-C-code-to-not-fail-due-to-its-.patch
perl -pi -e 's{(#include <sys/types.h>)}{#include <stdio.h>\n$1}' auto/feature

export NGINX_CONFIGURE=();
for flag in $(cat /opt/cpanel/ea-nginx-ngxdev/ngx-configure-args)
do
   if [[ $flag == --with-http_ssl_module* ]]; then
      # OBS has no /usr/bin/apt
      if [[ -v DEB_INSTALL_ROOT ]]; then
          continue
      fi
   fi

   export SPACE_UNESCAPED_FLAG=$(echo $flag|sed 's/+/ /g')
   NGINX_CONFIGURE+=("$SPACE_UNESCAPED_FLAG");
done

# OBS has no /usr/bin/apt
if [[ -v DEB_INSTALL_ROOT ]]; then
   NGINX_CONFIGURE+=(--without-http_rewrite_module --without-http_gzip_module);
fi
