#!/bin/bash

source debian/vars.sh

set -x

export bdir=`pwd`

echo "_SYSCONFDIR" $_sysconfdir
echo "DATADIR" $_datadir
echo "LOCALSTATEDIR" $_localstatedir
echo "LIBDIR" $_libdir
echo "UPSTREAMNAME" $upstream_name
echo "MAIN_VERSION" $main_version
echo "UNITDIR" $_unitdir
echo "LIBEXECDIR" $_libexecdir
echo "_MANDIR" $_mandir
echo "BDIR" $bdir

mkdir -p $DEB_INSTALL_ROOT$_sysconfdir/nginx
mkdir -p $DEB_INSTALL_ROOT/usr/share/doc/$upstream_name-$main_version

make DESTDIR=$DEB_INSTALL_ROOT INSTALLDIRS=vendor install

mkdir -p $DEB_INSTALL_ROOT$_datadir/nginx
mv $DEB_INSTALL_ROOT$_sysconfdir/nginx/html $DEB_INSTALL_ROOT$_datadir/nginx/

rm -f $DEB_INSTALL_ROOT$_sysconfdir/nginx/*.default
rm -f $DEB_INSTALL_ROOT$_sysconfdir/nginx/fastcgi.conf

mkdir -p $DEB_INSTALL_ROOT$_localstatedir/log/nginx/domains
mkdir -p $DEB_INSTALL_ROOT$_localstatedir/log/nginx/domains.rotated

mkdir -p $DEB_INSTALL_ROOT$_localstatedir/run/nginx
mkdir -p $DEB_INSTALL_ROOT$_localstatedir/cache/nginx

mkdir -p $DEB_INSTALL_ROOT$_libdir/nginx/modules

cd $DEB_INSTALL_ROOT$_sysconfdir/nginx && ln -s ../..$_libdir/nginx/modules modules && cd -

mkdir -p $DEB_INSTALL_ROOT$_datadir/doc/$upstream_name-$main_version/
install -m 644 -p ${SOURCE12} $DEB_INSTALL_ROOT${_datadir}/doc/${upstream_name}-${main_version}/

mkdir -p $DEB_INSTALL_ROOT$_sysconfdir/nginx/nginx.conf
mkdir -p $DEB_INSTALL_ROOT${_sysconfdir}/nginx/conf.d/modules
rm -f $DEB_INSTALL_ROOT${_sysconfdir}/nginx/nginx.conf
install -m 644 -p ${SOURCE4} $DEB_INSTALL_ROOT${_sysconfdir}/nginx/nginx.conf

perl -pi -e 's/^user\s+nginx;/user nobody;/g' $DEB_INSTALL_ROOT$_sysconfdir/nginx/nginx.conf

install -m 644 -p $SOURCE5 $DEB_INSTALL_ROOT$_sysconfdir/nginx/conf.d/default.conf
mkdir -p $DEB_INSTALL_ROOT$_sysconfdir/nginx/conf.d/includes-optional/
mkdir -p $DEB_INSTALL_ROOT$_sysconfdir/nginx/conf.d/server-includes/
mkdir -p $DEB_INSTALL_ROOT$_sysconfdir/nginx/conf.d/server-includes-standalone/
mkdir cpanel && cd cpanel && tar xzf $SOURCE14  && cd ..
cp -r cpanel/conf.d/* $DEB_INSTALL_ROOT$_sysconfdir/nginx/conf.d
mkdir -p $DEB_INSTALL_ROOT$_sysconfdir/nginx/ea-nginx
cp -r cpanel/ea-nginx/* $DEB_INSTALL_ROOT$_sysconfdir/nginx/ea-nginx


mkdir -p $DEB_INSTALL_ROOT/etc/chkserv.d
install -m 644 -p ${SOURCE15} $DEB_INSTALL_ROOT/etc/chkserv.d/nginx
mkdir -p $DEB_INSTALL_ROOT/usr/local/cpanel/scripts
install -m 755 -p ${SOURCE16} $DEB_INSTALL_ROOT/usr/local/cpanel/scripts/ea-nginx
install -m 755 -p ${SOURCE19} $DEB_INSTALL_ROOT/usr/local/cpanel/scripts/ea-nginx-userdata
install -m 755 -p ${SOURCE26} $DEB_INSTALL_ROOT/usr/local/cpanel/scripts/ea-nginx-logrotate

mkdir -p $DEB_INSTALL_ROOT/usr/local/cpanel/scripts
ln -s restartsrv_base $DEB_INSTALL_ROOT/usr/local/cpanel/scripts/restartsrv_nginx

mkdir -p $DEB_INSTALL_ROOT${_sysconfdir}/sysconfig
install -m 644 -p ${SOURCE3} $DEB_INSTALL_ROOT${_sysconfdir}/sysconfig/nginx
install -m 644 -p ${SOURCE7} $DEB_INSTALL_ROOT${_sysconfdir}/sysconfig/nginx-debug
install -p -D -m 0644 ${bdir}/objs/nginx.8 $DEB_INSTALL_ROOT${_mandir}/man8/nginx.8

# install systemd-specific files
mkdir -p $DEB_INSTALL_ROOT${_unitdir}
install -m644 $SOURCE8 $DEB_INSTALL_ROOT${_unitdir}/nginx.service
install -m644 $SOURCE11 $DEB_INSTALL_ROOT${_unitdir}/nginx-debug.service
mkdir -p $DEB_INSTALL_ROOT${_libexecdir}/initscripts/legacy-actions/nginx
install -m755 $SOURCE9 $DEB_INSTALL_ROOT${_libexecdir}/initscripts/legacy-actions/nginx/upgrade
install -m755 $SOURCE13 $DEB_INSTALL_ROOT${_libexecdir}/initscripts/legacy-actions/nginx/check-reload

# install log rotation stuff
mkdir -p $DEB_INSTALL_ROOT${_sysconfdir}/logrotate.d
install -m 644 -p ${SOURCE1} $DEB_INSTALL_ROOT${_sysconfdir}/logrotate.d/nginx

install -m755 ${bdir}/objs/nginx-debug $DEB_INSTALL_ROOT${_sbindir}/nginx-debug

mkdir -p $DEB_INSTALL_ROOT/var/cpanel/perl/Cpanel/ServiceManager/Services
install -m 600 -p ${SOURCE18} $DEB_INSTALL_ROOT/var/cpanel/perl/Cpanel/ServiceManager/Services/Nginx.pm

mkdir -p $DEB_INSTALL_ROOT/var/cpanel/perl5/lib
mkdir -p $DEB_INSTALL_ROOT/usr/local/cpanel/bin/admin/Cpanel
mkdir -p $DEB_INSTALL_ROOT/var/cpanel/perl/Cpanel/TaskProcessors/

install -p ${SOURCE22} $DEB_INSTALL_ROOT/var/cpanel/perl5/lib/NginxHooks.pm
install -p ${SOURCE23} $DEB_INSTALL_ROOT/var/cpanel/perl/Cpanel/TaskProcessors/NginxTasks.pm
install -p ${SOURCE24} $DEB_INSTALL_ROOT/usr/local/cpanel/bin/admin/Cpanel/nginx
install -p ${SOURCE25} $DEB_INSTALL_ROOT/usr/local/cpanel/bin/admin/Cpanel/nginx.conf

mkdir -p $DEB_INSTALL_ROOT/var/cache/ea-nginx/proxy

mkdir -p ${DEB_INSTALL_ROOT}/usr/local/cpanel/whostmgr/addonfeatures
install ${SOURCE28} ${DEB_INSTALL_ROOT}/usr/local/cpanel/whostmgr/addonfeatures/ea-nginx-toggle_nginx_caching

##########
# DAN EMERGENCY - BEGIN
##########

mkdir -p $DEB_INSTALL_ROOT/etc/dnf/universal-hooks/multi_pkgs/transaction/ea-__WILDCARD__nginx__WILDCARD__
install -p ${SOURCE27} $DEB_INSTALL_ROOT/etc/dnf/universal-hooks/multi_pkgs/transaction/ea-__WILDCARD__nginx__WILDCARD__/007-restartsrv_nginx

# These files perplex me.  On CentOS it does not exist throughout %build or
# %install, there are no %posts that I can see.   Yet this file is delivered.
# But I have no idea why or how.
mkdir -p debian/tmp/etc/nginx/conf.d/modules
echo "load_module modules/ngx_http_pipelog_module.so;" > debian/tmp/etc/nginx/conf.d/modules/ngx_http_pipelog_module.conf

# This one will surely fail, I cannot understand why this is delivered, nor
# where its contents came from, much less what the contents should be
cat <<EOF > debian/tmp/etc/nginx/conf.d/passenger.conf
passenger_root
/opt/cpanel/ea-ruby27/root/usr/libexec/../share/passenger/phusion_passenger/locations.ini;
passenger_enabled off;
passenger_user_switching on;
passenger_disable_security_update_check on;
passenger_instance_registry_dir
/opt/cpanel/ea-ruby27/root/usr/libexec/../../var/run/passenger-instreg;
passenger_ruby /opt/cpanel/ea-ruby27/root/usr/libexec/passenger-ruby27;
passenger_python /usr/bin/python;
EOF

##########
# DAN EMERGENCY - END
##########

mkdir -p debian/tmp/etc/nginx/ea-nginx/html
cp $SOURCE17 debian/tmp/etc/nginx/ea-nginx/html
mkdir -p debian/tmp/etc/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__nginx__WILDCARD__
cp $SOURCE27 debian/tmp/etc/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__nginx__WILDCARD__
mkdir -p debian/tmp/usr/sbin
cp debian/tmp/opt/cpanel/root/usr/sbin/nginx debian/tmp/usr/sbin
cp /usr/src/packages/BUILD/objs/nginx-debug debian/tmp/usr/sbin
gzip debian/tmp/usr/share/man/man8/nginx.8

rm -rf ${bdir}/_passenger_source_code

echo "FILE LIST" `pwd`
find /usr/src/packages/BUILD -type f -print | sort

