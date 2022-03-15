#!/bin/bash

mkdir ./nginx-build
pushd ./nginx-build

export NGINX_VER=$(cat /opt/cpanel/ea-nginx-ngxdev/nginx-ver)
tar xzf /opt/cpanel/ea-nginx-ngxdev/nginx-$NGINX_VER.tar.gz --strip-components 1

export NGINX_CONFIGURE=();
for flag in $(cat /opt/cpanel/ea-nginx-ngxdev/ngx-configure-args)
do
   export SPACE_UNESCAPED_FLAG=$(echo $flag|sed 's/+/ /g');
   NGINX_CONFIGURE+=("$SPACE_UNESCAPED_FLAG");
done
