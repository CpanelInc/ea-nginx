#
%define upstream_name nginx
%define nginx_home %{_localstatedir}/cache/nginx
%define nginx_user nobody
%define nginx_group nobody
%define nginx_loggroup adm

# distribution specific definitions
%define use_systemd (0%{?fedora} && 0%{?fedora} >= 18) || (0%{?rhel} && 0%{?rhel} >= 7) || (0%{?suse_version} >= 1315)

%define ea_openssl_ver 1.1.1d-1

%if 0%{?rhel} >= 8
# In C8 we use system openssl. See DESIGN.md in ea-openssl11 git repo for details
BuildRequires: openssl, openssl-devel
Requires: openssl
%else
Requires: ea-openssl11 >= %{ea_openssl_ver}
BuildRequires: ea-openssl11 >= %{ea_openssl_ver}
BuildRequires: ea-openssl11-devel >= %{ea_openssl_ver}
%endif

Requires: ea-apache24-mod_remoteip
Conflicts: ea-modsec30-connector-nginx < 1.0.3-2

%if 0%{?rhel} >= 8
# In C8 we use system openssl. See DESIGN.md in ea-openssl11 git repo for details
BuildRequires: libcurl
BuildRequires: libcurl-devel
%else
BuildRequires: ea-libcurl >= 7.68.0-2
BuildRequires: ea-libcurl-devel >= 7.68.0-2
%endif

%if 0%{?rhel} == 6
%define _group System Environment/Daemons
Requires(pre): shadow-utils
Requires: initscripts >= 8.36
Requires(post): chkconfig
%endif

# ea-nginx-passenger requires a certain ea-nginx version, which includes Epoch=1
%if 0%{?rhel} > 6
%define epoch 1
Epoch: %{epoch}
%endif

%if 0%{?rhel} == 7
BuildRequires: redhat-lsb-core
%define _group System Environment/Daemons
Requires(pre): shadow-utils
Requires: systemd
BuildRequires: systemd
%define os_minor %(lsb_release -rs | cut -d '.' -f 2)
%if %{os_minor} >= 4
%define dist .el7_4
%else
%define dist .el7
%endif
%endif

%if 0%{?rhel} == 8
%define _group System Environment/Daemons
Requires(pre): shadow-utils
Requires: systemd
BuildRequires: systemd
%define dist .el8
%endif

%if 0%{?suse_version} >= 1315
%define _group Productivity/Networking/Web/Servers
%define nginx_loggroup trusted
Requires(pre): shadow
Requires: systemd
BuildRequires: libopenssl-devel
BuildRequires: systemd
%endif

# end of distribution specific definitions

%define main_version 1.26.3

%define bdir %{_builddir}/%{upstream_name}-%{main_version}

%if 0%{?rhel} < 8
%define BASE_WITH_CC_OPT $(echo %{optflags} $(pcre-config --cflags)) -fPIC -I/opt/cpanel/ea-openssl11/include -I/opt/cpanel/libcurl/include
%define BASE_WITH_LD_OPT -Wl,-z,relro -Wl,-z,now -pie -L/opt/cpanel/ea-openssl11/%{_lib} -ldl -Wl,-rpath=/opt/cpanel/ea-openssl11/%{_lib} -L/opt/cpanel/libcurl/%{_lib} -Wl,-rpath=/opt/cpanel/libcurl/%{_lib} -Wl,-rpath=/opt/cpanel/ea-brotli/lib
%else
%if 0%{?rhel} < 9
%define BASE_WITH_CC_OPT $(echo %{optflags} $(pcre-config --cflags)) -fPIC
%define BASE_WITH_LD_OPT -Wl,-z,relro -Wl,-z,now -pie -ldl -Wl,-rpath=/opt/cpanel/ea-brotli/lib
%else
%define BASE_WITH_CC_OPT -std=gnu89
%define BASE_WITH_LD_OPT ""
%endif
%endif

%define WITH_CC_OPT $(echo "%{BASE_WITH_CC_OPT}")
%define WITH_LD_OPT $(echo "%{BASE_WITH_LD_OPT}")

%define BASE_CONFIGURE_ARGS $(echo "--prefix=%{_sysconfdir}/nginx --sbin-path=%{_sbindir}/nginx --modules-path=%{_libdir}/nginx/modules --conf-path=%{_sysconfdir}/nginx/nginx.conf --error-log-path=%{_localstatedir}/log/nginx/error.log --http-log-path=%{_localstatedir}/log/nginx/access.log --pid-path=%{_localstatedir}/run/nginx.pid --lock-path=%{_localstatedir}/run/nginx.lock --http-client-body-temp-path=%{_localstatedir}/cache/nginx/client_temp --http-proxy-temp-path=%{_localstatedir}/cache/nginx/proxy_temp --http-fastcgi-temp-path=%{_localstatedir}/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=%{_localstatedir}/cache/nginx/uwsgi_temp --http-scgi-temp-path=%{_localstatedir}/cache/nginx/scgi_temp --user=%{nginx_user} --group=%{nginx_group} --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-openssl-opt=enable-tls1_3 --with-openssl-opt=no-nextprotoneg")

Summary: High performance web server (caching reverse-proxy by default)
Name: ea-nginx
Version: %{main_version}
# Doing release_prefix this way for Release allows for OBS-proof versioning, See EA-4544 for more details
%define release_prefix 7
Release: %{release_prefix}%{?dist}.cpanel
Vendor: cPanel, L.L.C
URL: http://nginx.org/
Group: %{_group}

Provides: ea-nginx = %{version}-%{release}
Conflicts: nginx
AutoReq: no

Source0: http://nginx.org/download/nginx-%{version}.tar.gz
Source1: logrotate
Source2: nginx.init.in
Source3: nginx.sysconf
Source4: nginx.conf
Source5: nginx.vh.default.conf
Source7: nginx-debug.sysconf
Source8: nginx.service
Source9: nginx.upgrade.sh
Source11: nginx-debug.service
Source12: COPYRIGHT
Source13: nginx.check-reload.sh
Source14: cpanel.tar.gz
Source15: cpanel-chksrvd
Source16: cpanel-scripts-ea-nginx
Source17: FPM_50x.html
Source18: Nginx.pm
Source19: cpanel-scripts-ea-nginx-userdata
Source20: ngx_http_pipelog_module-ngx_http_pipelog_module.c
Source21: ngx_http_pipelog_module-config
Source22: NginxHooks.pm
Source23: NginxTasks.pm
Source24: nginx-adminbin
Source25: nginx-adminbin.conf
Source27: 007-restartsrv_nginx
Source28: whm_feature_addon
Source29: set_NGINX_CONFIGURE_array.sh

Patch1: 0001-Fix-auto-feature-test-C-code-to-not-fail-due-to-its-.patch

License: 2-clause BSD-like license

BuildRoot: %{_tmppath}/%{upstream_name}-%{main_version}-%{release}-root
BuildRequires: zlib-devel

%if 0%{?rhel} < 10
BuildRequires: pcre-devel
%else
BuildRequires: pcre2-devel
%endif

%if 0%{?rhel} > 6
BuildRequires: ea-ngx-brotli-src
%endif

%if 0%{?rhel} >= 6 && 0%{?rhel} < 10
BuildRequires: ea-brotli
%else
BuildRequires: brotli
%endif

Provides: webserver

%description
NGINX is a high performance web server that is
configured as a caching reverse-proxy by default.
This setup results in faster time to first byte
and often less load on a busy server.

%package ngxdev
Group: Development/Tools
Summary: Simplify making EA4 pkgs of NGINX modules
%if 0%{?rhel} < 10
Requires: pcre-devel
%else
Requires: pcre2-devel
%endif

%if 0%{?rhel} == 7
Requires: ea-openssl11, ea-openssl11-devel
%else
Requires: openssl, openssl-devel
%endif
Requires: openssl, openssl-devel
Requires: zlib-devel

%description -n ea-nginx-ngxdev
Provides tools to make it easier to make an EA4 pkg for an nginx module.

%prep
%setup -q -n nginx-%{version}
cp %{SOURCE2} .
sed -e 's|%%DEFAULTSTART%%|2 3 4 5|g' -e 's|%%DEFAULTSTOP%%|0 1 6|g' \
    -e 's|%%PROVIDES%%|nginx|g' < %{SOURCE2} > nginx.init
sed -e 's|%%DEFAULTSTART%%||g' -e 's|%%DEFAULTSTOP%%|0 1 2 3 4 5 6|g' \
    -e 's|%%PROVIDES%%|nginx-debug|g' < %{SOURCE2} > nginx-debug.init

%{__mkdir} -p ngx_http_pipelog_module/
cp %{SOURCE20} ngx_http_pipelog_module/ngx_http_pipelog_module.c
cp %{SOURCE21} ngx_http_pipelog_module/config

%if 0%{?rhel} > 6
%patch1 -p1 -b .fixautofeature
%endif

%build

%if 0%{?rhel} == 9
export CC=gcc
mkdir -p ngx_http_pipelog_module/
%endif

%if 0%{?rhel} > 6 && 0%{?rhel} < 10
export LDFLAGS="$LDFLAGS -Wl,-rpath=/opt/cpanel/ea-brotli/lib"
%endif

# build debug
./configure %{BASE_CONFIGURE_ARGS} \
    --with-cc-opt="%{WITH_CC_OPT}" \
    --with-ld-opt="%{WITH_LD_OPT}" \
    --with-debug \
%if 0%{?rhel} > 6
    --add-dynamic-module=/opt/cpanel/ea-ngx-brotli-src \
%endif
    --add-dynamic-module=ngx_http_pipelog_module
make %{?_smp_mflags}
%{__mv} %{bdir}/objs/nginx %{bdir}/objs/nginx-debug

# build actual
./configure %{BASE_CONFIGURE_ARGS} \
    --with-cc-opt="%{WITH_CC_OPT}" \
    --with-ld-opt="%{WITH_LD_OPT}" \
%if 0%{?rhel} > 6
    --add-dynamic-module=/opt/cpanel/ea-ngx-brotli-src \
%endif
    --add-dynamic-module=ngx_http_pipelog_module
make %{?_smp_mflags}

cp -f %{SOURCE22} .
cp -f %{SOURCE23} .
cp -f %{SOURCE24} .
cp -f %{SOURCE25} .
cp -f %{SOURCE29} .

%install
%{__rm} -rf $RPM_BUILD_ROOT

%{__mkdir} -p $RPM_BUILD_ROOT/opt/cpanel/ea-nginx-ngxdev
export SPACE_ESCAPED_WITH_CC_OPT=$(echo "%{WITH_CC_OPT}" | sed 's/ /+/g')
export SPACE_ESCAPED_WITH_LD_OPT=$(echo "%{WITH_LD_OPT}" | sed 's/ /+/g')
echo "%{BASE_CONFIGURE_ARGS} --with-cc-opt=$SPACE_ESCAPED_WITH_CC_OPT --with-ld-opt=$SPACE_ESCAPED_WITH_LD_OPT" > $RPM_BUILD_ROOT/opt/cpanel/ea-nginx-ngxdev/ngx-configure-args
echo -n %{version} > $RPM_BUILD_ROOT/opt/cpanel/ea-nginx-ngxdev/nginx-ver
/bin/cp -f %{SOURCE0} $RPM_BUILD_ROOT/opt/cpanel/ea-nginx-ngxdev/
%{__install} -p %{SOURCE29} $RPM_BUILD_ROOT/opt/cpanel/ea-nginx-ngxdev/

%{__make} DESTDIR=$RPM_BUILD_ROOT INSTALLDIRS=vendor install

%{__mkdir} -p $RPM_BUILD_ROOT%{_datadir}/nginx
%{__mv} $RPM_BUILD_ROOT%{_sysconfdir}/nginx/html $RPM_BUILD_ROOT%{_datadir}/nginx/

%{__rm} -f $RPM_BUILD_ROOT%{_sysconfdir}/nginx/*.default
%{__rm} -f $RPM_BUILD_ROOT%{_sysconfdir}/nginx/fastcgi.conf

%{__mkdir} -p $RPM_BUILD_ROOT%{_localstatedir}/log/nginx/domains
%{__mkdir} -p $RPM_BUILD_ROOT%{_localstatedir}/log/nginx/domains.rotated

%{__mkdir} -p $RPM_BUILD_ROOT%{_localstatedir}/run/nginx
%{__mkdir} -p $RPM_BUILD_ROOT%{_localstatedir}/cache/nginx

%{__mkdir} -p $RPM_BUILD_ROOT%{_libdir}/nginx/modules
cd $RPM_BUILD_ROOT%{_sysconfdir}/nginx && \
    %{__ln_s} ../..%{_libdir}/nginx/modules modules && cd -

%{__mkdir} -p $RPM_BUILD_ROOT%{_datadir}/doc/%{upstream_name}-%{main_version}
%{__install} -m 644 -p %{SOURCE12} \
    $RPM_BUILD_ROOT%{_datadir}/doc/%{upstream_name}-%{main_version}/

%{__mkdir} -p $RPM_BUILD_ROOT%{_sysconfdir}/nginx/conf.d/modules
%{__rm} $RPM_BUILD_ROOT%{_sysconfdir}/nginx/nginx.conf
%{__install} -m 644 -p %{SOURCE4} \
    $RPM_BUILD_ROOT%{_sysconfdir}/nginx/nginx.conf
perl -pi -e 's/^user\s+nginx;/user nobody;/g' $RPM_BUILD_ROOT%{_sysconfdir}/nginx/nginx.conf

%{__install} -m 644 -p %{SOURCE5} \
    $RPM_BUILD_ROOT%{_sysconfdir}/nginx/conf.d/default.conf

mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/nginx/conf.d/includes-optional/
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/nginx/conf.d/server-includes/
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/nginx/conf.d/server-includes-standalone/
mkdir cpanel && cd cpanel && tar xzf %{SOURCE14}  && cd ..
cp -r cpanel/conf.d/* $RPM_BUILD_ROOT%{_sysconfdir}/nginx/conf.d

# ZC-9800: deb conf file madness
mkdir -p $RPM_BUILD_ROOT/var/nginx/conf.d/includes-optional/
mv $RPM_BUILD_ROOT%{_sysconfdir}/nginx/conf.d/includes-optional/cpanel-proxy.conf $RPM_BUILD_ROOT/var/nginx/conf.d/includes-optional/cpanel-proxy.conf
ln -fs /var/nginx/conf.d/includes-optional/cpanel-proxy.conf $RPM_BUILD_ROOT/%{_sysconfdir}/nginx/conf.d/includes-optional/cpanel-proxy.conf

mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/nginx/ea-nginx
cp -r cpanel/ea-nginx/* $RPM_BUILD_ROOT%{_sysconfdir}/nginx/ea-nginx

mkdir -p $RPM_BUILD_ROOT/etc/chkserv.d
%{__install} -m 644 -p %{SOURCE15} $RPM_BUILD_ROOT/etc/chkserv.d/nginx
mkdir -p $RPM_BUILD_ROOT/usr/local/cpanel/scripts
%{__install} -m 755 -p %{SOURCE16} $RPM_BUILD_ROOT/usr/local/cpanel/scripts/ea-nginx
%{__install} -m 755 -p %{SOURCE19} $RPM_BUILD_ROOT/usr/local/cpanel/scripts/ea-nginx-userdata

ln -s restartsrv_base $RPM_BUILD_ROOT/usr/local/cpanel/scripts/restartsrv_nginx

%{__mkdir} -p $RPM_BUILD_ROOT%{_sysconfdir}/sysconfig
%{__install} -m 644 -p %{SOURCE3} \
    $RPM_BUILD_ROOT%{_sysconfdir}/sysconfig/nginx
%{__install} -m 644 -p %{SOURCE7} \
    $RPM_BUILD_ROOT%{_sysconfdir}/sysconfig/nginx-debug

%{__install} -p -D -m 0644 %{bdir}/objs/nginx.8 \
    $RPM_BUILD_ROOT%{_mandir}/man8/nginx.8

%{__mkdir} -m 755 -p $RPM_BUILD_ROOT%{_sysconfdir}/nginx/ea-nginx/html
%{__install} -m 644 -p %{SOURCE17} $RPM_BUILD_ROOT%{_sysconfdir}/nginx/ea-nginx/html/FPM_50x.html

%if %{use_systemd}
# install systemd-specific files
%{__mkdir} -p $RPM_BUILD_ROOT%{_unitdir}
%{__install} -m644 %SOURCE8 \
    $RPM_BUILD_ROOT%{_unitdir}/nginx.service
%{__install} -m644 %SOURCE11 \
    $RPM_BUILD_ROOT%{_unitdir}/nginx-debug.service
%{__mkdir} -p $RPM_BUILD_ROOT%{_libexecdir}/initscripts/legacy-actions/nginx
%{__install} -m755 %SOURCE9 \
    $RPM_BUILD_ROOT%{_libexecdir}/initscripts/legacy-actions/nginx/upgrade
%{__install} -m755 %SOURCE13 \
    $RPM_BUILD_ROOT%{_libexecdir}/initscripts/legacy-actions/nginx/check-reload
%else
# install SYSV init stuff
%{__mkdir} -p $RPM_BUILD_ROOT%{_initrddir}
%{__install} -m755 nginx.init $RPM_BUILD_ROOT%{_initrddir}/nginx
%{__install} -m755 nginx-debug.init $RPM_BUILD_ROOT%{_initrddir}/nginx-debug
%endif

# install log rotation stuff
%{__mkdir} -p $RPM_BUILD_ROOT%{_sysconfdir}/logrotate.d
%{__install} -m 644 -p %{SOURCE1} \
    $RPM_BUILD_ROOT%{_sysconfdir}/logrotate.d/nginx

%{__install} -m755 %{bdir}/objs/nginx-debug \
    $RPM_BUILD_ROOT%{_sbindir}/nginx-debug

%{__mkdir} -p $RPM_BUILD_ROOT/var/cpanel/perl/Cpanel/ServiceManager/Services
%{__install} -m 600 -p %{SOURCE18} $RPM_BUILD_ROOT/var/cpanel/perl/Cpanel/ServiceManager/Services/Nginx.pm

%{__mkdir} -p $RPM_BUILD_ROOT/var/cpanel/perl5/lib
%{__mkdir} -p $RPM_BUILD_ROOT/usr/local/cpanel/bin/admin/Cpanel
%{__mkdir} -p $RPM_BUILD_ROOT/var/cpanel/perl/Cpanel/TaskProcessors/

%{__install} -p %{SOURCE22} $RPM_BUILD_ROOT/var/cpanel/perl5/lib/NginxHooks.pm
%{__install} -p %{SOURCE23} $RPM_BUILD_ROOT/var/cpanel/perl/Cpanel/TaskProcessors/NginxTasks.pm
%{__install} -p %{SOURCE24} $RPM_BUILD_ROOT/usr/local/cpanel/bin/admin/Cpanel/nginx
%{__install} -p %{SOURCE25} $RPM_BUILD_ROOT/usr/local/cpanel/bin/admin/Cpanel/nginx.conf

mkdir -p $RPM_BUILD_ROOT/var/cache/ea-nginx/proxy

%if 0%{?rhel} >= 8
mkdir -p $RPM_BUILD_ROOT/etc/dnf/universal-hooks/multi_pkgs/transaction/ea-__WILDCARD__nginx__WILDCARD__
%{__install} -p %{SOURCE27} $RPM_BUILD_ROOT/etc/dnf/universal-hooks/multi_pkgs/transaction/ea-__WILDCARD__nginx__WILDCARD__/007-restartsrv_nginx
%else
mkdir -p $RPM_BUILD_ROOT/etc/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__nginx__WILDCARD__
%{__install} -p %{SOURCE27} $RPM_BUILD_ROOT/etc/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__nginx__WILDCARD__/007-restartsrv_nginx
%endif

mkdir -p %{buildroot}/usr/local/cpanel/whostmgr/addonfeatures
install %{SOURCE28} %{buildroot}/usr/local/cpanel/whostmgr/addonfeatures/ea-nginx-toggle_nginx_caching

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)

%{_sbindir}/nginx
%{_sbindir}/nginx-debug

%dir %{_sysconfdir}/nginx
%dir %{_sysconfdir}/nginx/conf.d
%dir %{_sysconfdir}/nginx/conf.d/modules
%ghost %attr(644, root, root) %{_sysconfdir}/nginx/conf.d/modules/ngx_http_pipelog_module.conf
%attr(700, nobody, root) /var/cache/ea-nginx/proxy

%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/cpanel-proxy-non-ssl.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/includes-optional/cpanel-fastcgi.conf
%{_sysconfdir}/nginx/conf.d/includes-optional/cpanel-proxy.conf
%attr(644, root, root) /var/nginx/conf.d/includes-optional/cpanel-proxy.conf
%config(noreplace) %attr(644, root, root) %{_sysconfdir}/nginx/conf.d/includes-optional/set-CACHE_KEY_PREFIX.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/includes-optional/cpanel-cgi-location.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/includes-optional/cpanel-server-parsed-location.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/includes-optional/force-non-www.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/includes-optional/force-www.conf
%config %attr(644, root, root) %{_sysconfdir}/nginx/conf.d/includes-optional/cloudflare.conf
%config %attr(600, root, root) %{_sysconfdir}/nginx/conf.d/includes-optional/cpanel-proxy-xt.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/server-includes-standalone/cpanel-dcv.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/server-includes-standalone/cpanel-mailman-locations.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/server-includes-standalone/cpanel-redirect-locations.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/server-includes/cpanel-static-locations.conf
%config %attr(644, root, root) %{_sysconfdir}/nginx/conf.d/ea-nginx.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/users.conf

%dir %{_sysconfdir}/nginx/ea-nginx
%attr(755, root, root) %{_sysconfdir}/nginx/ea-nginx/meta/apache
%attr(755, root, root) %{_sysconfdir}/nginx/ea-nginx/config-scripts/global/config-scripts-global-cloudflare
%config %{_sysconfdir}/nginx/ea-nginx/meta/apache_port.initial
%config %{_sysconfdir}/nginx/ea-nginx/meta/apache_ssl_port.initial
%config %{_sysconfdir}/nginx/ea-nginx/settings.json
%{_sysconfdir}/nginx/ea-nginx/cpanel-password-protected-dirs.tt
%{_sysconfdir}/nginx/ea-nginx/cpanel-php-location.tt
%{_sysconfdir}/nginx/ea-nginx/cpanel-wordpress-location.tt
%{_sysconfdir}/nginx/ea-nginx/ea-nginx.conf.tt
%{_sysconfdir}/nginx/ea-nginx/server.conf.tt
%{_sysconfdir}/nginx/ea-nginx/default.conf.tt
%config %{_sysconfdir}/nginx/ea-nginx/cache.json
%{_sysconfdir}/nginx/ea-nginx/global-logging.tt

%attr(755, root, root) /usr/local/cpanel/scripts/ea-nginx
%attr(755, root, root) /usr/local/cpanel/scripts/ea-nginx-userdata
%if 0%{?rhel} >= 8
%attr(755, root, root) /etc/dnf/universal-hooks/multi_pkgs/transaction/ea-__WILDCARD__nginx__WILDCARD__/007-restartsrv_nginx
%else
%attr(755, root, root) /etc/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__nginx__WILDCARD__/007-restartsrv_nginx
%endif

%attr(644, root, root) /usr/local/cpanel/whostmgr/addonfeatures/ea-nginx-toggle_nginx_caching

/usr/local/cpanel/scripts/restartsrv_nginx
/etc/chkserv.d/nginx

%{_sysconfdir}/nginx/modules

%config %{_sysconfdir}/nginx/nginx.conf
%config %{_sysconfdir}/nginx/conf.d/default.conf
%config %{_sysconfdir}/nginx/mime.types
%config %{_sysconfdir}/nginx/fastcgi_params
%config %{_sysconfdir}/nginx/scgi_params
%config %{_sysconfdir}/nginx/uwsgi_params
%config %{_sysconfdir}/nginx/koi-utf
%config %{_sysconfdir}/nginx/koi-win
%config %{_sysconfdir}/nginx/win-utf

%config %{_sysconfdir}/logrotate.d/nginx
%config %{_sysconfdir}/sysconfig/nginx
%config %{_sysconfdir}/sysconfig/nginx-debug
%if %{use_systemd}
%{_unitdir}/nginx.service
%{_unitdir}/nginx-debug.service
%dir %{_libexecdir}/initscripts/legacy-actions/nginx
%{_libexecdir}/initscripts/legacy-actions/nginx/*
%else
%{_initrddir}/nginx
%{_initrddir}/nginx-debug
%endif

%attr(0755,root,root) %dir %{_libdir}/nginx
%attr(0755,root,root) %dir %{_libdir}/nginx/modules
%attr(0755,root,root) %{_libdir}/nginx/modules/ngx_http_pipelog_module.so
%if 0%{?rhel} > 6
%attr(0755,root,root) %{_libdir}/nginx/modules/ngx_http_brotli_filter_module.so
%attr(0755,root,root) %{_libdir}/nginx/modules/ngx_http_brotli_static_module.so
%endif

%dir %{_datadir}/nginx
%dir %{_datadir}/nginx/html
%{_datadir}/nginx/html/*

%attr(0755,root,root) %dir %{_localstatedir}/cache/nginx
%attr(0755,root,root) %dir %{_localstatedir}/log/nginx
%attr(0711,root,root) %dir %{_localstatedir}/log/nginx/domains
%attr(0711,root,root) %dir %{_localstatedir}/log/nginx/domains.rotated

%dir %{_datadir}/doc/%{upstream_name}-%{main_version}
%doc %{_datadir}/doc/%{upstream_name}-%{main_version}/COPYRIGHT
%{_mandir}/man8/nginx.8*

%attr(755, root, root) %{_sysconfdir}/nginx/ea-nginx/html
%attr(644, root, root) %{_sysconfdir}/nginx/ea-nginx/html/FPM_50x.html

%attr(600, root, root) /var/cpanel/perl/Cpanel/ServiceManager/Services/Nginx.pm

%attr(0755, root, root) /var/cpanel/perl5/lib/NginxHooks.pm
%attr(0644, root, root) /var/cpanel/perl/Cpanel/TaskProcessors/NginxTasks.pm

%attr(0755,root,root) /usr/local/cpanel/bin/admin/Cpanel/nginx
%attr(0644,root,root) /usr/local/cpanel/bin/admin/Cpanel/nginx.conf

%files ngxdev
/opt/cpanel/ea-nginx-ngxdev

%pre
# Other nginx implementations can leave behind stray config files when they are removed.
# As such, we make a best effort to ensure a clean config when ea-nginx is installed
if [ $1 = 1 ]; then
    # Engintron will leave behind executable files in this directory which in turn are called via a cron job
    # The executables can and do create files in /etc/nginx/conf.d/ that will cause nginx to fail to start with
    # our implementation
    if [ -e /etc/nginx/utilities ]; then
        echo "Removing /etc/nginx_utilities.pre_install_ea_nginx_config"
        rm -rf /etc/nginx_utilities.pre_install_ea_nginx_config
        echo "Moving /etc/nginx/utilities aside to ensure valid config for ea-nginx since this is a new install"
        mv -fv /etc/nginx/utilities /etc/nginx_utilities.pre_install_ea_nginx_config ||:
    fi

    # Since any stray *.conf files in this directory will be picked up by nginx.conf,
    # we want to ensure that this directory is fresh on new installs
    if [ -e /etc/nginx/conf.d ]; then
        echo "Removing /etc/nginx_conf.d.pre_install_ea_nginx_config"
        rm -rf /etc/nginx_conf.d.pre_install_ea_nginx_config
        echo "Moving /etc/nginx/conf.d aside to ensure valid config for ea-nginx since this is a new install"
        mv -fv /etc/nginx/conf.d /etc/nginx_conf.d.pre_install_ea_nginx_config ||:
    fi

    # If modsec rulesets have been installed, they will create a symlink in '/etc/nginx/conf.d/modsec_vendor_configs/'
    # with conf files in it.  We need to make sure we do not blow away modsec rulesets here too.
    if [ -e /etc/nginx_conf.d.pre_install_ea_nginx_config/modsec_vendor_configs ]; then
        mkdir -p /etc/nginx/conf.d
        cp -r /etc/nginx_conf.d.pre_install_ea_nginx_config/modsec_vendor_configs /etc/nginx/conf.d/modsec_vendor_configs
    fi

    # We need to ensure that any config files that were present are still present
    # so that cpio does not fail to unpack
    if [ -e /etc/nginx_conf.d.pre_install_ea_nginx_config/includes-optional/cloudflare.conf ]; then
        mkdir -p /etc/nginx/conf.d/includes-optional
        cp /etc/nginx_conf.d.pre_install_ea_nginx_config/includes-optional/cloudflare.conf /etc/nginx/conf.d/includes-optional/cloudflare.conf
    fi
    if [ -e /etc/nginx_conf.d.pre_install_ea_nginx_config/ea-nginx.conf ]; then
        mkdir -p /etc/nginx/conf.d
        cp /etc/nginx_conf.d.pre_install_ea_nginx_config/ea-nginx.conf /etc/nginx/conf.d/ea-nginx.conf
    fi
    if [ -e /etc/nginx_conf.d.pre_install_ea_nginx_config/default.conf ]; then
        mkdir -p /etc/nginx/conf.d
        cp /etc/nginx_conf.d.pre_install_ea_nginx_config/default.conf /etc/nginx/conf.d/default.conf
    fi
    if [ -e /etc/nginx_conf.d.pre_install_ea_nginx_config/conf.d/includes-optional/set-CACHE_KEY_PREFIX.conf ]; then
        mkdir -p /etc/nginx/conf.d/includes-optional
        cp /etc/nginx_conf.d.pre_install_ea_nginx_config/set-CACHE_KEY_PREFIX.conf /etc/nginx/conf.d/includes-optional/set-CACHE_KEY_PREFIX.conf
    fi
fi

# we need to know the version of cPanel, the hooks cannot be deployed
# before version 11.80
cpversion=`/usr/local/cpanel/3rdparty/bin/perl -MCpanel::Version -e 'print Cpanel::Version::get_short_release_number()'`
if [ $cpversion -ge 80 ]; then
    # do not let nginx hooks run during upgrade. Use GTE because it can go higher,
    # but anything 2 or greater is still an upgrade.
    # Also deregister the hooks on this step, as that's the right point to do it

    # ZC-5816: both pre and preun remove our hooks.
    # meaning it would happen twice on downgrade/upgrade etc, seeing errors on
    # the 2nd removal.
    numhooks=`/usr/local/cpanel/bin/manage_hooks list 2> /dev/null | grep 'hook: NginxHooks::' | wc -l`
    if [ "$numhooks" -ge 1 ]; then
        /usr/local/cpanel/bin/manage_hooks delete module NginxHooks
    fi
fi

# Add the "nginx" user
getent group %{nginx_group} >/dev/null || groupadd -r %{nginx_group}
getent passwd %{nginx_user} >/dev/null || \
    useradd -r -g %{nginx_group} -s /sbin/nologin \
    -d %{nginx_home} -c "nginx user"  %{nginx_user}
exit 0

%post
# DRAGONS:  if you update this, then SOURCES/pkg.postinst needs updated with the same changes

# Register the nginx service
if [ $1 -eq 1 ]; then
%if %{use_systemd}
    /usr/bin/systemctl preset nginx.service >/dev/null 2>&1 ||:
    /usr/bin/systemctl preset nginx-debug.service >/dev/null 2>&1 ||:
    /usr/bin/systemctl enable nginx.service >/dev/null 2>&1 ||:
    /usr/bin/systemctl disable nginx-debug.service >/dev/null 2>&1 ||:
%else
    /sbin/chkconfig --add nginx
    /sbin/chkconfig --add nginx-debug
%endif
    # print site info
    cat <<BANNER
----------------------------------------------------------------------

Thanks for using nginx!

Please find the official documentation for nginx here:
* http://nginx.org/en/docs/

Please subscribe to nginx-announce mailing list to get
the most important news about nginx:
* http://nginx.org/en/support.html

Commercial subscriptions for nginx are available on:
* http://nginx.com/products/

----------------------------------------------------------------------
BANNER

    # Touch and set permisions on default log files on installation

    if [ -d %{_localstatedir}/log/nginx ]; then
        if [ ! -e %{_localstatedir}/log/nginx/access.log ]; then
            touch %{_localstatedir}/log/nginx/access.log
            %{__chmod} 640 %{_localstatedir}/log/nginx/access.log
            %{__chown} %{nginx_user}:%{nginx_loggroup} %{_localstatedir}/log/nginx/access.log
        fi

        if [ ! -e %{_localstatedir}/log/nginx/error.log ]; then
            touch %{_localstatedir}/log/nginx/error.log
            %{__chmod} 640 %{_localstatedir}/log/nginx/error.log
            %{__chown} %{nginx_user}:%{nginx_loggroup} %{_localstatedir}/log/nginx/error.log
        fi
    fi

/usr/local/cpanel/scripts/restartsrv_httpd --stop
%{_sysconfdir}/nginx/ea-nginx/meta/apache move_apache_to_alt_ports
echo "nginx:1" >> /etc/chkserv.d/chkservd.conf

fi

%if %{use_systemd}
    /usr/bin/systemctl start nginx.service >/dev/null 2>&1 ||:
%else
    /sbin/service nginx start  >/dev/null 2>&1 ||:
%endif

%posttrans
# DRAGONS:  if you update this, then SOURCES/pkg.postinst needs updated with the same changes

# I move this to here, to deal with the craziness of the order of operations
# on yum upgrade and downgrades.
# No need to restart nginx here since that is handled in the universal-hook
/usr/local/cpanel/scripts/ea-nginx config --all --no-reload

cpversion=`/usr/local/cpanel/3rdparty/bin/perl -MCpanel::Version -e 'print Cpanel::Version::get_short_release_number()'`
if [ $cpversion -ge 80 ]; then
    # Remove "bad" hooks that were left around by a bad previous version of the RPM
    # Ignore failures in case you are on a version of cPanel too old for feature
    /usr/local/cpanel/bin/manage_hooks prune; /bin/true;
    /usr/local/cpanel/bin/manage_hooks add module NginxHooks
fi

# Go ahead and enable fileprotect if we disabled it via this package and the
# ea-nginx-standlone package is not installed
# Note, ea-nginx-standalone owns /etc/nginx/ea-nginx/enable.standalone so it
# should only exist if that package is installed
if [[ -e /etc/nginx/ea-nginx/meta/fileprotect && ! -e /etc/nginx/ea-nginx/enable.standalone ]]; then
    rm -f /etc/nginx/ea-nginx/meta/fileprotect
    /usr/local/cpanel/bin/whmapi1 set_tweaksetting key=enablefileprotect value=1
fi

# also ensure that queueprocd is kicked so that it reads in the custom task
# processor that we wrote for it
/usr/local/cpanel/scripts/restartsrv queueprocd

# hook is not run for the transaction that installs it, so for good measure (ZC-7669)
%if 0%{?rhel} >= 8
    /etc/dnf/universal-hooks/multi_pkgs/transaction/ea-__WILDCARD__nginx__WILDCARD__/007-restartsrv_nginx
%else
    /etc/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__nginx__WILDCARD__/007-restartsrv_nginx
%endif

%preun
# we need to know the version of cPanel, the hooks cannot be deployed
# before version 11.80
cpversion=`/usr/local/cpanel/3rdparty/bin/perl -MCpanel::Version -e 'print Cpanel::Version::get_short_release_number()'`
if [ $cpversion -ge 80 ]; then
    # ZC-5816: both pre and preun remove our hooks.
    # meaning it would happen twice on downgrade/upgrade etc, seeing errors on
    # the 2nd removal.
    numhooks=`/usr/local/cpanel/bin/manage_hooks list 2> /dev/null | grep 'hook: NginxHooks::' | wc -l`
    if [ "$numhooks" -ge 1 ]; then
        /usr/local/cpanel/bin/manage_hooks delete module NginxHooks
    fi
fi

if [ $1 -eq 0 ]; then
%if %use_systemd
    /usr/bin/systemctl --no-reload disable nginx.service >/dev/null 2>&1 ||:
    /usr/bin/systemctl stop nginx.service >/dev/null 2>&1 ||:
%else
    /sbin/service nginx stop > /dev/null 2>&1
    /sbin/chkconfig --del nginx
    /sbin/chkconfig --del nginx-debug
%endif

/usr/local/cpanel/scripts/restartsrv_httpd --stop
/usr/local/cpanel/scripts/restartsrv_nginx --stop

sed -i '/nginx:1/d' /etc/chkserv.d/chkservd.conf

%{_sysconfdir}/nginx/ea-nginx/meta/apache move_apache_back_to_orig_ports

fi

%postun
%if %use_systemd
/usr/bin/systemctl daemon-reload >/dev/null 2>&1 ||:
%endif

# /etc/nginx/conf.d/modules/ngx_http_pipelog_module.conf is a %ghost so will get removed
# /etc/nginx/conf.d/global-logging.conf will be left behind and, if it has
#   piped logging enabled then its an invalid configuraiton *but* we don't have nginc
#  at this point and reinstalling should regen config so do we care?
rm -rf  /etc/nginx/conf.d/global-logging.conf

rm -rf /etc/nginx/ea-nginx/cpanel_localhost_header.json

if [ $1 -eq 0 ]; then
    rm -rf /var/log/nginx.uninstall ||:
    mv -fv /var/log/nginx /var/log/nginx.uninstall ||:
fi

if [ $1 -ge 1 ]; then
    /sbin/service nginx status  >/dev/null 2>&1 || exit 0
    /sbin/service nginx upgrade >/dev/null 2>&1 || echo \
        "Binary upgrade failed, please check nginx's error.log"
fi

%changelog
* Wed Jul 09 2025 Julian Brown <julian.brown@webpros.com> - 1.26.3-7
- ZC-12940: fix warnings from /etc/nginx/ea-nginx/meta/apache

* Mon Jun 02 2025 Dan Muey <daniel.muey@webpros.com> - 1.26.3-6
- ZC-12882: Re-order traffic log IPs format to match actual use

* Thu May 08 2025 Julian Brown <julian.brown@webpros.com> - 1.26.3-5
- ZC-12825: Correct traffic log issue when not using piped logs

* Wed Apr 09 2025 Chris Castillo <chris.castillo@webpros.com> - 1.26.3-4
- ZC-12765: Collect traffic logs.

* Thu Mar 27 2025 Chris Castillo <chris.castillo@webpros.com> - 1.26.3-3
- ZC-12245: Remove domlogs on account removal.

* Tue Feb 18 2025 Julian Brown <julian.brown@webpros.com> - 1.26.3-2
- ZC-12573: Create setting to include or not include cloudflare.conf

* Tue Feb 11 2025 Cory McIntire <cory.mcintire@webpros.com> - 1.26.3-1
- EA-12703: Update ea-nginx from v1.26.2 to v1.26.3
- Security: insufficient check in virtual servers handling with TLSv1.3
  SNI allowed to reuse SSL sessions in a different virtual server, to
  bypass client SSL certificates verification (CVE-2025-23419)

* Wed Aug 14 2024 Cory McIntire <cory@cpanel.net> - 1.26.2-1
- EA-12337: Update ea-nginx from v1.26.1 to v1.26.2
- *) Security: processing of a specially crafted mp4 file by the ngx_http_mp4_module might cause a worker process crash (CVE-2024-7347).
  Thanks to Nils Bars.

* Mon Jun 10 2024 Cory McIntire <cory@cpanel.net> - 1.26.1-1
- EA-12203: Update ea-nginx from v1.26.0 to v1.26.1

* Fri May 03 2024 Brian Mendoza <brian.mendoza@cpanel.net> - 1.26.0-2
- ZC-11741: Reload touch file mechanism

* Tue Apr 23 2024 Cory McIntire <cory@cpanel.net> - 1.26.0-1
- EA-12112: Update ea-nginx from v1.25.5 to v1.26.0

* Tue Apr 16 2024 Cory McIntire <cory@cpanel.net> - 1.25.5-1
- EA-12100: Update ea-nginx from v1.25.4 to v1.25.5

* Thu Mar 07 2024 Dan Muey <dan@cpanel.net> - 1.25.4-2
- ZC-11679: Account for circumstance where wwwacct.conf is missing
- ZC-11680: clear cache after lookup for pre-install /var override

* Wed Feb 14 2024 Cory McIntire <cory@cpanel.net> - 1.25.4-1
- EA-11973: Update ea-nginx from v1.25.3 to v1.25.4

* Mon Jan 22 2024 Dan Muey <dan@cpanel.net> - 1.25.3-2
- ZC-11555: No longer pull in Apache’s passenger in reverse proxy mode

* Thu Oct 26 2023 Cory McIntire <cory@cpanel.net> - 1.25.3-1
- EA-11772: Update ea-nginx from v1.25.2 to v1.25.3

* Mon Oct 02 2023 Travis Holloway <t.holloway@cpanel.net> - 1.25.2-6
- EA-11530: Do not disable file protect when in reverse proxy mode

* Tue Sep 12 2023 Tim Mullin <tim@cpanel.net> - 1.25.2-5
- EA-11648: Add hooks needed to update config when whmapi1 delete_domain is called

* Fri Sep 01 2023 Travis Holloway <t.holloway@cpanel.net> - 1.25.2-4
- EA-11657: Ensure nginx is hard restarted during deb/rpm transactions

* Wed Aug 30 2023 Dan Muey <dan@cpanel.net> - 1.25.2-3
- EA-11646: Clean up global passenger conf

* Mon Aug 28 2023 Travis Holloway <t.holloway@cpanel.net> - 1.25.2-2
- EA-11502: Do not mark cpanel-proxy.conf as a config file

* Thu Aug 24 2023 Cory McIntire <cory@cpanel.net> - 1.25.2-1
- EA-11631: Update ea-nginx from v1.25.1 to v1.25.2

* Mon Aug 21 2023 Dan Muey <dan@cpanel.net> - 1.25.1-4
- ZC-11149: support touchfile for nginx cpwrap that will ignore memory limits and set it to unlimited

* Mon Aug 07 2023 Brian Mendoza <brian.mendoza@cpanel.net> - 1.25.1-3
- ZC-10396: Remove ea-passenger-src dependency and other passenger code

* Thu Jul 20 2023 Travis Holloway <t.holloway@cpanel.net> - 1.25.1-2
- EA-11561: Make it so that scripts/ea-nginx is not aware of config syntax for template files

* Thu Jun 15 2023 Cory McIntire <cory@cpanel.net> - 1.25.1-1
- EA-11496: Update ea-nginx from v1.25.0 to v1.25.1
- EA-11512: Update config script to use new http2 directive instead of deprecated http2 on listen directive

* Tue Jun 13 2023 Brian Mendoza <brian.mendoza@cpanel.net> - 1.25.0-4
- ZC-10945: Implement findings from evaluating our web stack performance improvements

* Tue Jun 06 2023 Travis Holloway <t.holloway@cpanel.net> - 1.25.0-3
- EA-11462: Return a 403 for htaccess file location match

* Wed May 31 2023 Dan Muey <dan@cpanel.net> - 1.25.0-2
- ZC-10395: Remove modsec 3 from build

* Wed May 24 2023 Cory McIntire <cory@cpanel.net> - 1.25.0-1
- EA-11442: Update ea-nginx from v1.24.0 to v1.25.0

* Fri May 05 2023 Travis Holloway <t.holloway@cpanel.net> - 1.24.0-3
- EA-11397: Ensure deb package moves '/var/log/nginx' to '/var/log/nginx.uninstall' upon removal

* Tue Apr 25 2023 Travis Holloway <t.holloway@cpanel.net> - 1.24.0-2
- EA-11131: Ensure userdata reflects apache port changes when ea-nginx is removed
- EA-11132: Ensure '/var/log/nginx.uninstall' does not exist before moving active log files there

* Wed Apr 12 2023 Cory McIntire <cory@cpanel.net> - 1.24.0-1
- EA-11350: Update ea-nginx from v1.23.4 to v1.24.0

* Wed Apr 05 2023 Travis Holloway <t.holloway@cpanel.net> - 1.23.4-2
- EA-11324: Wrap docroot in quotes so that docroots that contain semicolons do not break the config

* Wed Mar 29 2023 Cory McIntire <cory@cpanel.net> - 1.23.4-1
- EA-11323: Update ea-nginx from v1.23.3 to v1.23.4

* Tue Mar 21 2023 Travis Holloway <t.holloway@cpanel.net> - 1.23.3-8
- EA-11298: Do not log microseconds to bytes log

* Mon Feb 27 2023 Travis Holloway <t.holloway@cpanel.net> - 1.23.3-7
- EA-11269: Reduce frequency of nginx restarts during cpanellogd's domain log processing when piped logging is enabled

* Tue Feb 07 2023 Dan Muey <dan@cpanel.net> - 1.23.3-6
- ZC-10615: Remove cleaning pipelog artifacts from init.d and chksrvd files

* Wed Feb 01 2023 Tim Mullin <tim@cpanel.net> - 1.23.3-5
- EA-11189: Exclude invalid certificate files from the Nginx config

* Mon Jan 16 2023 Travis Holloway <t.holloway@cpanel.net> - 1.23.3-4
- EA-11156: Avoid reloads while config subcommand is executing

* Wed Jan 04 2023 Brian Mendoza <brian.mendoza@cpanel.net> - 1.23.3-3
- ZC-10317: Update ngx_http_pipelog_module to v1.0.3
- ZC-10484: Remove SIGKILL from various nginx files
- ZC-10517: Address Ubuntu creating addiotional splitlog processes
- ZC-10593: Close out fd's during reload/shutdown
- EA-11088: Account for mail subdomains of addon and parked domains when configuring the server_name directive
- EA-11121: Add ipv6 subdomain to server_name directive when account has an ipv6 address assigned
- EA-10890: Refactor _render_and_append() to use more data from global config data

* Tue Dec 27 2022 Travis Holloway <t.holloway@cpanel.net> - 1.23.3-2
- EA-11087: Guard against bad userdata where a domain is considered an addon domain and subdomain

* Thu Dec 15 2022 Cory McIntire <cory@cpanel.net> - 1.23.3-1
- EA-11104: Update ea-nginx from v1.23.2 to v1.23.3

* Thu Dec 08 2022 Travis Holloway <t.holloway@cpanel.net> - 1.23.2-8
- EA-11078: Fix uninitialized value warning for non-user requests when the USER_ID touch file exists
- EA-11093: Increase nginx buffer when calculating server_names_hash_bucket_size
- EA-10891: Refactor logging initialization to be its own sub

* Fri Nov 18 2022 Travis Holloway <t.holloway@cpanel.net> - 1.23.2-7
- EA-11048: Move '/var/log/nginx' to a backup location during uninstall
- EA-11069: Increase open files limit for master and worker processes
- EA-10574: Remove deprecated configure option --with-ipv6
- EA-10874: Remove fallback logic in scripts::ea_nginx::_get_application_paths()

* Thu Nov 17 2022 Travis Holloway <t.holloway@cpanel.net> - 1.23.2-6
- EA-11049: Avoid server_names_hash warning

* Wed Nov 09 2022 Travis Holloway <t.holloway@cpanel.net> - 1.23.2-5
- EA-10769: Allow custom config files to be moved across partitions when ea-nginx is installed
- EA-11025: If user generated config is detected as bad after configuration, remove the config file to avoid taking all sites down

* Tue Nov 01 2022 Tim Mullin <tim@cpanel.net> - 1.23.2-4
- EA-11004: Fix Passenger restart failures after reboot
- EA-10670: Add better guards against bad userdata to configuration script

* Thu Oct 27 2022 Travis Holloway <t.holloway@cpanel.net> - 1.23.2-3
- EA-10977: Fix 'could not build optimal server_names_hash' warnings

* Fri Oct 21 2022 Tim Mullin <tim@cpanel.net> - 1.23.2-2
- EA-10999: Update logic to check if service is listening on ports 80 or 443
- EA-10985: Drop logrotate configuration for domain logs since cpanellogd handles the rotation

* Thu Oct 20 2022 Cory McIntire <cory@cpanel.net> - 1.23.2-1
- EA-11003: Update ea-nginx from v1.23.1 to v1.23.2

* Thu Oct 13 2022 Travis Holloway <t.holloway@cpanel.net> - 1.23.1-11
- EA-10963: Ensure valid nginx configuration when no accounts are created on the system

* Tue Oct 11 2022 Julian Brown <julian.brown@cpanel.net> - 1.23.1-10
- ZC-10336: Build on Alma Linux 9

* Fri Sep 30 2022 Travis Holloway <t.holloway@cpanel.net> - 1.23.1-9
- SEC-651: Add Stats hooks for cpanellogd to signal nginx to reload its log files after rotation

* Fri Sep 30 2022 Travis Holloway <t.holloway@cpanel.net> - 1.23.1-8
- EA-10959: Ensure valid nginx configuration when service subdomains are disabled

* Thu Sep 29 2022 Travis Holloway <t.holloway@cpanel.net> - 1.23.1-7
- Revert ZC-10009

* Thu Sep 29 2022 Julian Brown <julian.brown@cpanel.net> - 1.23.1-6
- ZC-10009: Add changes so that it builds on AlmaLinux 9

* Wed Sep 21 2022 Tim Mullin <tim@cpanel.net> - 1.23.1-5
- EA-10751: Leave X-Forwarded-Host blank for service subdomains

* Thu Sep 08 2022 Travis Holloway <t.holloway@cpanel.net> - 1.23.1-4
- EA-10671: Calculate 'server_names_hash_bucket_size' and 'server_names_hash_max_size' at config time
- EA-10913: Update ea-nginx.conf when adding/updating a config file for a single user

* Tue Aug 23 2022 Travis Holloway <t.holloway@cpanel.net> - 1.23.1-3
- EA-10892: Avoid configuring shared IPs in multiple server blocks when configuring nginx asynchronously

* Thu Aug 18 2022 Travis Holloway <t.holloway@cpanel.net> - 1.23.1-2
- EA-10835: Increase POD and unit test coverage / minor bug fixes/improvements

* Wed Jul 20 2022 Cory McIntire <cory@cpanel.net> - 1.23.1-1
- EA-10844: Update ea-nginx from v1.23.0 to v1.23.1

* Fri Jul 15 2022 Travis Holloway <t.holloway@cpanel.net> - 1.23.0-3
- EA-10824: Enforce 'scripts/ea-nginx config' to obtain lock before proceeding with config

* Wed Jul 06 2022 Travis Holloway <t.holloway@cpanel.net> - 1.23.0-2
- EA-10819: Provide flag to build nginx config synchronously

* Mon Jun 27 2022 Cory McIntire <cory@cpanel.net> - 1.23.0-1
- EA-10795: Update ea-nginx from v1.22.0 to v1.23.0

* Tue Jun 07 2022 Dan Muey <dan@cpanel.net> - 1.22.0-2
- ZC-9940: Change worker_processes default back to 1
- ZC-9940: Have worker_shutdown_timeout default to 10 seconds

* Thu May 26 2022 Cory McIntire <cory@cpanel.net> - 1.22.0-1
- EA-10736: Update ea-nginx from v1.21.6 to v1.22.0

* Mon May 02 2022 Dan Muey <dan@cpanel.net> - 1.21.6-13
- ZC-9931: Ensure that a pre-existing cache.json/settings.json is respected when ea-nginx is installed
- ZC-9371: enable keepalive support
- ZC-9939: optimize proxy sub-domain configuration
- ZC-9952: Allow setting `worker_shutdown_timeout` via /etc/nginx/ea-nginx/settings.json
- EA-10673: Increase `proxy_headers_hash_bucket_size` to 128 in cpanel-proxy-xt.conf

* Tue Apr 12 2022 Tim Mullin <tim@cpanel.net> - 1.21.6-12
- EA-10535: Fix SSL certificate handling for custom mail subdomains

* Wed Apr 06 2022 Dan Muey <dan@cpanel.net> - 1.21.6-11
- ZC-9698: Proxy robots.txt (and favicon) since it can be dynamic (e.g. wordpress + .htaccess)
- ZC-9844: Add flag file to use micro caching as the cache defaults

* Fri Mar 25 2022 Travis Holloway <t.holloway@cpanel.net> - 1.21.6-10
- EA-10590: Disable nginx-debug service on Ubuntu

* Wed Mar 23 2022 Dan Muey <dan@cpanel.net> - 1.21.6-9
- ZC-9645: Added ea-nginx-ngxdev to make it easier to make a pkg for an nginx modules

* Fri Mar 18 2022 Tim Mullin <tim@cpanel.net> - 1.21.6-8
- EA-10576: Fix server configuration template proxy caching setting

* Wed Mar 09 2022 Dan Muey <dan@cpanel.net> - 1.21.6-7
- ZC-9756: build brotli module

* Thu Mar 03 2022 Dan Muey <dan@cpanel.net> - 1.21.6-6
- ZC-9800: change edit of cpanel-proxy conf to include (akin to how we do cloudflare.conf)

* Mon Feb 28 2022 Travis Holloway <t.holloway@cpanel.net> - 1.21.6-5
- EA-10493: The server_name directive needs the public/external IP on systems configured to use a NAT

* Thu Feb 24 2022 Travis Holloway <t.holloway@cpanel.net> - 1.21.6-4
- EA-10515: Add symlink protection for DCV validation folders for service subdomains

* Thu Feb 17 2022 Dan Muey <dan@cpanel.net> - 1.21.6-3
- ZC-9750: Add support for secure use of proxying to Apache w/ mod_remoteip

* Thu Feb 17 2022 Travis Holloway <t.holloway@cpanel.net> - 1.21.6-2
- EA-10503: Update standalone config to ensure 404 for non-existent php files
- EA-10285: Have 'ea-nginx config --all' update user configs in parallel

* Wed Feb 09 2022 Travis Holloway <t.holloway@cpanel.net> - 1.21.6-1
- EA-10489: Update ea-nginx from v1.21.5 to v1.21.6

* Mon Jan 31 2022 Dan Muey <dan@cpanel.net> - 1.21.5-5
- ZC-9700: Do not use predictable cPanel-localhost header
- ZC-9700: ensure random value is regenerated if missing or older than 30 minutes; ensure users can not see the value
- EA-10464: Avoid redirect to https for service subdomain DCV validation

* Wed Jan 26 2022 Travis Holloway <t.holloway@cpanel.net> - 1.21.5-4
- EA-10294: Add caching mechanism for wordpress info

* Tue Jan 25 2022 Dan Muey <dan@cpanel.net> - 1.21.5-3
- ZC-9661: configure SSL w/ system cert when domain does not have its own cert

* Fri Jan 21 2022 Travis Holloway <t.holloway@cpanel.net> - 1.21.5-2
- EA-10283: Only perform regex check for WordPress login for domains that have at least one WordPress site installed

* Thu Jan 13 2022 Travis Holloway <t.holloway@cpanel.net> - 1.21.5-1
- EA-10428: Update ea-nginx from v1.21.4 to v1.21.5

* Thu Jan 13 2022 Stephen Bee <stephen@cpanel.net> - 1.21.4-10
- SEC-612: Deny access to /whm-server-status

* Tue Jan 11 2022 Tim Mullin <tim@cpanel.net> - 1.21.4-8
- SEC-611: Set the server_tokens directive to off in nginx.conf

* Tue Dec 28 2021 Dan Muey <dan@cpanel.net> - 1.21.4-7
- ZC-9428: Configure http2 support
- ZC-9615: IPv6 support for proxy subdomain redirect to https

* Thu Dec 16 2021 Dan Muey <dan@cpanel.net> - 1.21.4-6
- ZC-9343: Change worker_processes to auto
- ZC-9343: Allow setting `worker_processes` via /etc/nginx/ea-nginx/settings.json
- ZC-9343: When writing settings.json make it human readable
- ZC-7303: Support IP based requests (ZC-9586: only use an IP once)
- ZC-9384: Use mycpanel.pem if its there

* Wed Nov 24 2021 Dan Muey <dan@cpanel.net> - 1.21.4-5
- ZC-9527: set USER_ID for server block if uid given && not zero

* Mon Nov 22 2021 Travis Holloway <t.holloway@cpanel.net> - 1.21.4-4
- EA-10029: Get wordpress info from wp-toolkit if it is installed

* Thu Nov 11 2021 Travis Holloway <t.holloway@cpanel.net> - 1.21.4-3
- EA-10221: Always configure domains to support CloudFlare

* Thu Nov 04 2021 Travis Holloway <t.holloway@cpanel.net> - 1.21.4-2
- EA-10144: Set new default open files limit for worker processes

* Wed Nov 03 2021 Cory McIntire <cory@cpanel.net> - 1.21.4-1
- EA-10255: Update ea-nginx from v1.21.3 to v1.21.4

* Thu Oct 28 2021 Dan Muey <dan@cpanel.net> - 1.21.3-5
- ZC-9439: Set user/group for -ssl_log if it exists (i.e. piped logging is enabeld)

* Thu Oct 21 2021 Julian Brown <julian.brown@cpanel.net> - 1.21.3-4
- ZC-9382: Clear all user caches when default php is changed.

* Fri Sep 24 2021 Dan Muey <dan@cpanel.net> - 1.21.3-3
- ZC-9317: Stop using deprecated (and unused) module

* Mon Sep 20 2021 Dan Muey <dan@cpanel.net> - 1.21.3-2
- ZC-9260: Move standalone includes to seperate folder && bring in server includes on reverse proxy and standalone
- ZC-9261: Allow include to prefix `proxy_cache_key` based on any criteria

* Thu Sep 16 2021 Cory McIntire <cory@cpanel.net> - 1.21.3-1
- EA-10108: Update ea-nginx from v1.21.2 to v1.21.3

* Tue Sep 07 2021 Cory McIntire <cory@cpanel.net> - 1.21.2-1
- EA-10095: Update ea-nginx from v1.21.1 to v1.21.2

* Thu Sep 02 2021 Travis Holloway <t.holloway@cpanel.net> - 1.21.1-6
- EA-9957: Configure ssl_dhparam directive

* Tue Aug 24 2021 Travis Holloway <t.holloway@cpanel.net> - 1.21.1-5
- EA-9954: Add logic for server_names_hash_max_size and server_names_hash_bucket_size to syntax checker

* Fri Aug 06 2021 Travis Holloway <t.holloway@cpanel.net> - 1.21.1-4
- EA-9902: Do not cache the wordpress homepage when users are logged into wp-admin

* Thu Jul 29 2021 Dan Muey <dan@cpanel.net> - 1.21.1-3
- ZC-5555: Listen on IPv6 like we do IPv4

* Mon Jul 26 2021 Travis Holloway <t.holloway@cpanel.net> - 1.21.1-2
- EA-9875: Avoid race condition when binding to ports 80/443

* Thu Jul 15 2021 Travis Holloway <t.holloway@cpanel.net> - 1.21.1-1
- EA-9968: Update ea-nginx from v1.21.0 to v1.21.1

* Tue Jul 13 2021 Travis Holloway <t.holloway@cpanel.net> - 1.21.0-16
- EA-9946: Add syntax validation check to configuration script
- EA-9967: Ensure 'modsec_vendor_configs' is left in place on new installs

* Thu Jul 08 2021 Travis Holloway <t.holloway@cpanel.net> - 1.21.0-15
- EA-9944: Remove noreplace from nginx.conf and ea-nginx.conf
- EA-9945: Ensure clean '/etc/nginx' directory on new installs

* Wed Jul 07 2021 Daniel Muey <dan@cpanel.net> - 1.21.0-14
- ZC-9047: Add `toggle_nginx_caching` to WHM Feature Manager

* Tue Jun 29 2021 Travis Holloway <t.holloway@cpanel.net> - 1.21.0-13
- EA-9909: Add hard coded fallback values for keys in settings.json

* Thu Jun 24 2021 Daniel Muey <dan@cpanel.net> - 1.21.0-12
- ZC-9005: Do not hide Upgrade header when proxying websockets under main service subdomains
- ZC-9018: rebuild all users; reporting any issues at the end
- ZC-9020: Add cache related methods to adminbin

* Wed Jun 23 2021 Travis Holloway <t.holloway@cpanel.net> - 1.21.0-11
- EA-9874: Cache 301 redirects
- EA-9814: Set client_max_body_size to 128m

* Wed Jun 23 2021 Daniel Muey <dan@cpanel.net> - 1.21.0-10
- ZC-9009: Do not die when a domain’s PHP config is missing

* Mon Jun 21 2021 Daniel Muey <dan@cpanel.net> - 1.21.0-9
- ZC-8589: Improve proxy/SSL configuration

* Fri Jun 18 2021 Travis Holloway <t.holloway@cpanel.net> = 1.21.0-8
- EA-9879: Make timeout on request to determine if a domain is using CloudFlare threadsafe
- EA-9880: Move Accounts::Modify and Accounts::Remove from rebuild_user action to rebuild_all action

* Thu Jun 17 2021 Daniel Muey <dan@cpanel.net> - 1.21.0-7
- ZC-8831: clarify a variable name

* Thu Jun 17 2021 Travis Holloway <t.holloway@cpanel.net> - 1.21.0-6
- EA-9836: Add support for Let's Encrypt AutoSSL provider

* Tue Jun 15 2021 Travis Holloway <t.holloway@cpanel.net> - 1.21.0-5
- EA-9790: Only put SSL server block in place when it is desired

* Wed Jun 09 2021 Daniel Muey <dan@cpanel.net> - 1.21.0-4
- ZC-8934: Update some hooks to only operate on the user in question

* Tue Jun 08 2021 Travis Holloway <t.holloway@cpanel.net> - 1.21.0-3
- EA-9789: Silence logrotate script

* Tue Jun 01 2021 Cory McIntire <cory@cpanel.net> - 1.21.0-2
- EA-9812: NGINX fails to start when a folder contains a space

* Wed May 26 2021 Cory McIntire <cory@cpanel.net> - 1.21.0-1
- EA-9798: Update ea-nginx from v1.20.0 to v1.21.0
- EA-9791: Add alarm to request to determine if a domain is using CloudFlare

* Mon May 17 2021 Travis Holloway <t.holloway@cpanel.net> - 1.20.0-5
- EA-9774: Ensure logs are rotated daily

* Wed May 12 2021 Daniel Muey <dan@cpanel.net> - 1.20.0-4
- ZC-8830: Fix cache clearing bug w/ `cache`

* Mon May 10 2021 Daniel Muey <dan@cpanel.net> - 1.20.0-3
- ZC-8817: clear cache on certain ops

* Thu May 06 2021 Travis Holloway <t.holloway@cpanel.net> - 1.20.0-2
- EA-9757: Remove unnecessary proxy config setting for wordpress sites

* Fri Apr 23 2021 Cory McIntire <cory@cpanel.net> - 1.20.0-1
- EA-9706: Update ea-nginx from v1.19.10 to v1.20.0

* Thu Apr 15 2021 Travis Holloway <t.holloway@cpanel.net> - 1.19.10-2
- EA-9692: Ensure server blocks contain root path when in reverse proxy mode

* Wed Apr 14 2021 Travis Holloway <t.holloway@cpanel.net> - 1.19.10-1
- EA-9694: Update ea-nginx from v1.19.9 to v1.19.10

* Wed Apr 07 2021 Travis Holloway <t.holloway@cpanel.net> - 1.19.9-1
- EA-9683: Update ea-nginx from v1.19.8 to v1.19.9
- EA-9682: Create hook to rebuild config for tweak settings changes in WHM

* Tue Apr 06 2021 Travis Holloway <t.holloway@cpanel.net> - 1.19.8-5
- EA-9672: Decrease delay to rebuild config when creating new domains
- EA-9673: Honor proxysubdomains tweak setting when rebuilding config

* Tue Apr 06 2021 Daniel Muey <dan@cpanel.net> - 1.19.8-4
- ZC-8719: Add `mail` subdomain like it does `www`

* Thu Mar 18 2021 Tim Mullin <tim@cpanel.net> - 1.19.8-3
- EA-9652: Invoke whmapi1 with full cPanel path

* Thu Mar 11 2021 Daniel Muey <dan@cpanel.net> - 1.19.8-2
- ZC-8591: Add `/Microsoft-Server-ActiveSync` proxy

* Wed Mar 10 2021 Cory McIntire <cory@cpanel.net> - 1.19.8-1
- EA-9638: Update ea-nginx from v1.19.7 to v1.19.8

* Mon Mar 08 2021 Daniel Muey <dan@cpanel.net> - 1.19.7-5
- ZC-8541: Add sub command to scripts/ea-nginx to configure cacheing

* Thu Mar 04 2021 Julian Brown <julian.brown@cpanel.net> - 1.19.7-4
- ZC-8480: Move ea-nginx from experimental to EA4

* Wed Feb 24 2021 Julian Brown <julian.brown@cpanel.net> - 1.19.7-3
- ZC-8436: Hooks for suspend/unsuspend acct, changing ip, and refactor clear-cache for API
- ZC-8433: handle localhost/127.0.0.1/machines's hostname consistently
- ZC-8194: Add cloudflare config
- ZC-8510: do bandwidth notices and exceeding

* Mon Feb 22 2021 Daniel Muey <dan@cpanel.net> - 1.19.7-2
- ZC-8461: Support `cpanelwebcall` URI

* Mon Feb 22 2021 Cory McIntire <cory@cpanel.net> - 1.19.7-1
- EA-9589: Update ea-nginx from v1.19.6 to v1.19.7

* Wed Feb 10 2021 Tim Mullin <tim@cpanel.net> - 1.19.6-5
- EA-9562: Fix escaping in nginx.service file to work with CentOS 8

* Mon Feb 08 2021 Daniel Muey <dan@cpanel.net> - 1.19.6-4
- ZC-8389: Proxy service subdomains directly to cpsrvd under reverse proxy

* Fri Feb 05 2021 Daniel Muey <dan@cpanel.net> - 1.19.6-3
- ZC-8385: Set `proxy_cache_key` so that the user’s caches are keyed to the request’s FQDN

* Tue Feb 02 2021 Daniel Muey <dan@cpanel.net> - 1.19.6-2
- ZC-8356: Expose caching hard coded defaults to the class

* Thu Jan 14 2021 Daniel Muey <dan@cpanel.net> - 1.19.6-1
- EA-9498: Update ea-nginx from v1.19.3 to v1.19.6

* Fri Dec 18 2020 Daniel Muey <dan@cpanel.net> - 1.19.3-7
- ZC-8052: change to all-proxy; detect chaching and standalone and do needful

* Thu Dec 10 2020 Travis Holloway <t.holloway@cpanel.net> - 1.19.3-6
- ZC-8061: Build C7 against ea-ruby27

* Fri Dec 04 2020 Travis Holloway <t.holloway@cpanel.net> - 1.19.3-5
- ZC-8061: Build on C8

* Tue Oct 27 2020 Tim Mullin <tim@cpanel.net> - 1.19.3-4
- EA-9390: Fix build with latest ea-brotli (v1.0.9)

* Thu Oct 15 2020 Daniel Muey <dan@cpanel.net> - 1.19.3-3
- ZC-7761: Handle wildcard domains

* Mon Oct 05 2020 Daniel Muey <dan@cpanel.net> - 1.19.3-2
- ZC-7669: Add universal hook to hard restart nginx for any transaction involving any nginc related package

* Thu Oct 01 2020 Daniel Muey <dan@cpanel.net> - 1.19.3-1
- EA-9334: Update ea-nginx from v1.19.2 to v1.19.3

* Fri Sep 18 2020 Cory McIntire <cory@cpanel.net> - 1.19.2-1
- EA-9309: Update ea-nginx from v1.19.1 to v1.19.2

* Thu Sep 03 2020 Daniel Muey <dan@cpanel.net> - 1.19.1-10
- ZC-7493: Factor userdata `secruleengineoff` into user configuration

* Thu Aug 20 2020 Daniel Muey <dan@cpanel.net> - 1.19.1-9
- ZC-7379: Add global script support for config generation

* Tue Aug 18 2020 Daniel Muey <dan@cpanel.net> - 1.19.1-8
- ZC-7366: Add modsec 3.0 support

* Thu Jul 23 2020 Daniel Muey <dan@cpanel.net> - 1.19.1-7
- ZC-7220: Set `proxy_http_version` to 1.1 so that `Upgrade` works

* Thu Jul 23 2020 Daniel Muey <dan@cpanel.net> - 1.19.1-6
- ZC-7217: Fix changelog entry

* Mon Jul 20 2020 Dan Muey <dan@cpanel.net> - 1.19.1-5
- ZC-7191: re-enable graceful restarts

* Mon Jul 13 2020 Julian Brown <julian.brown@cpanel.net> - 1.19.1-4
- ZC-7129: Removing hooks twice on downgrade

* Mon Jul 13 2020  Dan Muey <dan@cpanel.net> - 1.19.1-3
- ZC-6985: fix `undefined status from Cpanel::ServiceManager::Services::Nginx for Server Status`
-    probably other issues as well

* Thu Jul 09 2020 Dan Muey <dan@cpanel.net> - 1.19.1-2
- ZC-6105: Add license for ngx_http_pipelog_module sources

* Thu Jul 09 2020 Cory McIntire <cory@cpanel.net> - 1.19.1-1
- EA-9149: Update ea-nginx from v1.19.0 to v1.19.1

* Wed Jul 01 2020 Tim Mullin <tim@cpanel.net> - 1.19.0-4
- EA-9123: Add cPanel-localhost as a proxy header

* Thu Jun 25 2020 Dan Muey <dan@cpanel.net> - 1.19.0-3
- ZC-7058: compile in passenger module && configure Application Manager apps

* Wed May 27 2020 Daniel Muey <dan@cpanel.net> - 1.19.0-2
- ZC-5534: process logs via logrotate akin to what cpanellogd does w/ Apache

* Tue May 26 2020 Cory McIntire <cory@cpanel.net> - 1.19.0-1
- EA-9080: Update ea-nginx from v1.18.0 to v1.19.0

* Thu May 07 2020 Daniel Muey <dan@cpanel.net> - 1.18.0-2
- ZC-4887: Add cPanel Redirects to nginx config

* Tue Apr 21 2020 Cory McIntire <cory@cpanel.net> - 1.18.0-1
- EA-9016: Update ea-nginx from v1.17.10 to v1.18.0
- Change Nginx.pm to use Moo

* Thu Apr 16 2020 Cory McIntire <cory@cpanel.net> - 1.17.10-1
- EA-9006: Update ea-nginx from v1.17.9 to v1.17.10

* Tue Apr 07 2020 Tim Mullin <tim@cpanel.net> - 1.17.9-3
- EA-8943: Fixed wildcard subdomains

* Fri Apr 03 2020 Tim Mullin <tim@cpanel.net> - 1.17.9-2
- EA-8934: Fixed server redirects for the hostname

* Tue Mar 03 2020 Cory McIntire <cory@cpanel.net> - 1.17.9-1
- EA-8894: Update ea-nginx from v1.17.8 to v1.17.9

* Wed Jan 22 2020 Cory McIntire <cory@cpanel.net> - 1.17.8-1
- EA-8840: Update ea-nginx from v1.17.6 to v1.17.8

* Thu Nov 21 2019 Cory McIntire <cory@cpanel.net> - 1.17.6-1
- EA-8755: Update ea-nginx from v1.17.5 to v1.17.6

* Mon Nov 18 2019 Travis Holloway <t.holloway@cpanel.net> - 1.17.5-2
- ZC-5789: Fix scripts/ea-nginx to work on LTS version

* Wed Oct 23 2019 Cory McIntire <cory@cpanel.net> - 1.17.5-1
- EA-8713: Update ea-nginx from v1.17.4 to v1.17.5

* Tue Oct 22 2019 Daniel Muey <dan@cpanel.net> - 1.17.4-3
- ZC-5738: Update template key `sslprotocol_list` to `sslprotocol_list_str`

* Tue Oct 01 2019 Daniel Muey <dan@cpanel.net> - 1.17.4-2
- ZC-4361: Update ea-openssl requirement to v1.1.1 (ZC-5583)

* Fri Sep 27 2019 Cory McIntire <cory@cpanel.net> - 1.17.4-1
- EA-8669: Update ea-nginx from v1.17.3 to v1.17.4

* Mon Sep 23 2019 Daniel Muey <dan@cpanel.net> - 1.17.3-6
- ZC-5574: Ensure ngx_http_pipelog_module processes are cleaned up
-   Work around https://github.com/pandax381/ngx_http_pipelog_module/issues/7

* Thu Sep 19 2019 Julian Brown <julian.brown@cpanel.net> - 1.17.3-5
- Hook into cPanel when anything changes update Nginx config.

* Wed Sep 18 2019 Dan Muey <dan@cpanel.net> - 1.17.3-4
- ZC-4961: Configure logging to match how we do it with Apache

* Mon Sep 16 2019 Julian Brown <julian.brown@cpanel.net> - 1.17.3-3
- ZC-5554 - Do config/restart in %posttrans

* Mon Sep 09 2019 Julian Brown <julian.brown@cpanel.net> - 1.17.3-2
- ZC-5423 - Apache not releasing 80/443 when installing ea-nginx

* Thu Aug 15 2019 Cory McIntire <cory@cpanel.net> - 1.17.3-1
- EA-8613: Update ea-nginx from v1.17.2 to v1.17.3

* Mon Jul 29 2019 Cory McIntire <cory@cpanel.net> - 1.17.2-1
- EA-8589: Update ea-nginx from v1.17.1 to v1.17.2

* Thu Jun 27 2019 Cory McIntire <cory@cpanel.net> - 1.17.1-1
- EA-8544: Update ea-nginx from v1.16.0 to v1.17.1

* Thu May 23 2019 Daniel Muey <dan@cpanel.net> - 1.16.0-2
- ZC-5014: Add cPanel Password Protected Directory support
- ZC-5151: Add CGI and Server-Parsed support via proxy

* Tue Apr 23 2019 Daniel Muey <dan@cpanel.net> - 1.16.0-1
- EA-8415: Update ea-nginx from v1.15.9 to v1.16.0

* Wed Apr 10 2019 Julian Brown <julian.brown@cpanel.net> - 1.15.9-4
- ZC-4975: Update custom 503 html file.

* Thu Mar 21 2019 Dan Muey <dan@cpanel.net> - 1.15.9-3
- ZC-4877: add initial user config script

* Thu Mar 14 2019 Dan Muey <dan@cpanel.net> - 1.15.9-2
- ZC-4868: Add cPanel specific configurations
- ZC-4867: start nginx (specfile already stops it if needed)
-          fix hard coded `nginx` user in log ownership
-          Add `Provides` and `Conflicts` for upstream
- ZC-4867: Move Apache to alternate port and back again
- ZC-4869: Add support for proxying to apache,
-          add mailman and DCV (.well-known) proxies
- ZC-4870/ZC-4871: tie into chkservd and restartsrv system
- ZC-4897: Account for current apache port settings that are above the root-only range
- ZC-4898: Do not move apache if it is already configured for nonstandard ports
- ZC-4869: do `proxy_set_header` for `Host` and `X-Real-IP` anywhere we `proxy_pass`
- ZC-4869: alias img-sys for mailman images

* Wed Mar 13 2019 Dan Muey <dan@cpanel.net> - 1.15.9-1
- cPanelize nginx SPEC file

* Tue Feb 26 2019 Konstantin Pavlov <thresh@nginx.com>
- 1.15.9

* Tue Dec 25 2018 Konstantin Pavlov <thresh@nginx.com>
- 1.15.8

* Tue Nov 27 2018 Konstantin Pavlov <thresh@nginx.com>
- 1.15.7

* Tue Nov 06 2018 Konstantin Pavlov <thresh@nginx.com>
- 1.15.6
- Fixes CVE-2018-16843
- Fixes CVE-2018-16844
- Fixes CVE-2018-16845

* Tue Oct 02 2018 Konstantin Pavlov <thresh@nginx.com>
- 1.15.5

* Tue Sep 25 2018 Konstantin Pavlov <thresh@nginx.com>
- 1.15.4

* Tue Aug 28 2018 Konstantin Pavlov <thresh@nginx.com>
- 1.15.3

* Tue Jul 24 2018 Konstantin Pavlov <thresh@nginx.com>
- 1.15.2

* Tue Jul 03 2018 Konstantin Pavlov <thresh@nginx.com>
- 1.15.1

* Tue Jun 05 2018 Konstantin Pavlov <thresh@nginx.com>
- 1.15.0

* Mon Apr 09 2018 Konstantin Pavlov <thresh@nginx.com>
- 1.13.12

* Tue Apr 03 2018 Konstantin Pavlov <thresh@nginx.com>
- 1.13.11

* Tue Mar 20 2018 Konstantin Pavlov <thresh@nginx.com>
- 1.13.10

* Tue Feb 20 2018 Konstantin Pavlov <thresh@nginx.com>
- 1.13.9

* Tue Dec 26 2017 Konstantin Pavlov <thresh@nginx.com>
- 1.13.8

* Tue Nov 21 2017 Konstantin Pavlov <thresh@nginx.com>
- 1.13.7

* Tue Oct 10 2017 Konstantin Pavlov <thresh@nginx.com>
- 1.13.6

* Tue Sep  5 2017 Konstantin Pavlov <thresh@nginx.com>
- 1.13.5

* Tue Aug  8 2017 Sergey Budnevitch <sb@nginx.com>
- 1.13.4

* Tue Jul 11 2017 Konstantin Pavlov <thresh@nginx.com>
- 1.13.3
- Fixes CVE-2017-7529

* Tue Jun 27 2017 Konstantin Pavlov <thresh@nginx.com>
- 1.13.2

* Tue May 30 2017 Konstantin Pavlov <thresh@nginx.com>
- 1.13.1

* Tue Apr 25 2017 Konstantin Pavlov <thresh@nginx.com>
- 1.13.0

* Tue Apr  4 2017 Konstantin Pavlov <thresh@nginx.com>
- 1.11.13
- CentOS7/RHEL7: made upgrade loops/timeouts configurable via
  /etc/sysconfig/nginx.
- Bumped upgrade defaults to five loops one second each.

* Fri Mar 24 2017 Konstantin Pavlov <thresh@nginx.com>
- 1.11.12

* Tue Mar 21 2017 Konstantin Pavlov <thresh@nginx.com>
- 1.11.11

* Tue Feb 14 2017 Konstantin Pavlov <thresh@nginx.com>
- 1.11.10

* Tue Jan 24 2017 Konstantin Pavlov <thresh@nginx.com>
- 1.11.9
- Extended hardening build flags.
- Added check-reload target to init script / systemd service.

* Tue Dec 27 2016 Konstantin Pavlov <thresh@nginx.com>
- 1.11.8

* Tue Dec 13 2016 Konstantin Pavlov <thresh@nginx.com>
- 1.11.7

* Tue Nov 15 2016 Konstantin Pavlov <thresh@nginx.com>
- 1.11.6

* Mon Oct 10 2016 Andrei Belov <defan@nginx.com>
- 1.11.5

* Tue Sep 13 2016 Konstantin Pavlov <thresh@nginx.com>
- 1.11.4.
- njs updated to 0.1.2.

* Tue Jul 26 2016 Konstantin Pavlov <thresh@nginx.com>
- 1.11.3.
- njs updated to 0.1.0.
- njs stream dynamic module added to nginx-module-njs package.
- geoip stream dynamic module added to nginx-module-geoip package.

* Tue Jul  5 2016 Konstantin Pavlov <thresh@nginx.com>
- 1.11.2
- njs updated to ef2b708510b1.

* Tue May 31 2016 Konstantin Pavlov <thresh@nginx.com>
- 1.11.1

* Tue May 24 2016 Sergey Budnevitch <sb@nginx.com>
- Fixed logrotate error if nginx is not running
- 1.11.0

* Tue Apr 19 2016 Konstantin Pavlov <thresh@nginx.com>
- 1.9.15
- njs updated to 1c50334fbea6.

* Tue Apr  5 2016 Konstantin Pavlov <thresh@nginx.com>
- 1.9.14

* Tue Mar 29 2016 Konstantin Pavlov <thresh@nginx.com>
- 1.9.13
- Added perl and njs dynamic modules
- Fixed Requires section for dynamic modules on CentOS7/RHEL7

* Wed Feb 24 2016 Sergey Budnevitch <sb@nginx.com>
- common configure args are now in macros
- xslt, image-filter and geoip dynamic modules added
- 1.9.12

* Tue Feb  9 2016 Sergey Budnevitch <sb@nginx.com>
- dynamic modules path and symlink in %{_sysconfdir}/nginx added
- 1.9.11

* Tue Jan 26 2016 Konstantin Pavlov <thresh@nginx.com>
- 1.9.10

* Wed Dec  9 2015 Konstantin Pavlov <thresh@nginx.com>
- 1.9.9

* Tue Dec  8 2015 Konstantin Pavlov <thresh@nginx.com>
- 1.9.8
- http_slice module enabled

* Tue Nov 17 2015 Konstantin Pavlov <thresh@nginx.com>
- 1.9.7

* Tue Oct 27 2015 Sergey Budnevitch <sb@nginx.com>
- 1.9.6

* Tue Sep 22 2015 Andrei Belov <defan@nginx.com>
- 1.9.5
- http_spdy module replaced with http_v2 module

* Tue Aug 18 2015 Konstantin Pavlov <thresh@nginx.com>
- 1.9.4

* Tue Jul 14 2015 Sergey Budnevitch <sb@nginx.com>
- 1.9.3

* Tue May 26 2015 Sergey Budnevitch <sb@nginx.com>
- 1.9.1

* Tue Apr 28 2015 Sergey Budnevitch <sb@nginx.com>
- 1.9.0
- thread pool support added
- stream module added
- example_ssl.conf removed

* Tue Apr  7 2015 Sergey Budnevitch <sb@nginx.com>
- 1.7.12

* Tue Mar 24 2015 Sergey Budnevitch <sb@nginx.com>
- 1.7.11

* Tue Feb 10 2015 Sergey Budnevitch <sb@nginx.com>
- 1.7.10

* Tue Dec 23 2014 Sergey Budnevitch <sb@nginx.com>
- 1.7.9

* Tue Dec  2 2014 Sergey Budnevitch <sb@nginx.com>
- 1.7.8

* Tue Sep 30 2014 Sergey Budnevitch <sb@nginx.com>
- 1.7.6

* Tue Sep 16 2014 Sergey Budnevitch <sb@nginx.com>
- epoch added to the EPEL7/CentOS7 spec to override EPEL one
- 1.7.5

* Tue Aug  5 2014 Sergey Budnevitch <sb@nginx.com>
- 1.7.4

* Tue Jul  8 2014 Sergey Budnevitch <sb@nginx.com>
- 1.7.3

* Tue Jun 17 2014 Sergey Budnevitch <sb@nginx.com>
- 1.7.2

* Tue May 27 2014 Sergey Budnevitch <sb@nginx.com>
- 1.7.1
- incorrect sysconfig filename finding in the initscript fixed

* Thu Apr 24 2014 Konstantin Pavlov <thresh@nginx.com>
- 1.7.0

* Tue Apr  8 2014 Sergey Budnevitch <sb@nginx.com>
- 1.5.13
- built spdy module on rhel/centos 6

* Tue Mar 18 2014 Sergey Budnevitch <sb@nginx.com>
- 1.5.12
- spec cleanup
- openssl version dependence added
- upgrade() function in the init script improved
- warning added when binary upgrade returns non-zero exit code

* Tue Mar  4 2014 Sergey Budnevitch <sb@nginx.com>
- 1.5.11

* Tue Feb  4 2014 Sergey Budnevitch <sb@nginx.com>
- 1.5.10

* Wed Jan 22 2014 Sergey Budnevitch <sb@nginx.com>
- 1.5.9

* Tue Dec 17 2013 Sergey Budnevitch <sb@nginx.com>
- 1.5.8
- fixed invalid week days in the changelog

* Tue Nov 19 2013 Sergey Budnevitch <sb@nginx.com>
- 1.5.7

* Tue Oct  1 2013 Sergey Budnevitch <sb@nginx.com>
- 1.5.6

* Tue Sep 17 2013 Andrei Belov <defan@nginx.com>
- 1.5.5

* Tue Aug 27 2013 Sergey Budnevitch <sb@nginx.com>
- 1.5.4
- auth request module added

* Tue Jul 30 2013 Sergey Budnevitch <sb@nginx.com>
- 1.5.3

* Tue Jul  2 2013 Sergey Budnevitch <sb@nginx.com>
- 1.5.2

* Tue Jun  4 2013 Sergey Budnevitch <sb@nginx.com>
- 1.5.1

* Mon May  6 2013 Sergey Budnevitch <sb@nginx.com>
- 1.5.0

* Tue Apr 16 2013 Sergey Budnevitch <sb@nginx.com>
- 1.3.16

* Tue Mar 26 2013 Sergey Budnevitch <sb@nginx.com>
- 1.3.15
- gunzip module added
- set permissions on default log files at installation

* Tue Feb 12 2013 Sergey Budnevitch <sb@nginx.com>
- excess slash removed from --prefix
- 1.2.7

* Tue Dec 11 2012 Sergey Budnevitch <sb@nginx.com>
- 1.2.6

* Tue Nov 13 2012 Sergey Budnevitch <sb@nginx.com>
- 1.2.5

* Tue Sep 25 2012 Sergey Budnevitch <sb@nginx.com>
- 1.2.4

* Tue Aug  7 2012 Sergey Budnevitch <sb@nginx.com>
- 1.2.3
- nginx-debug package now actually contains non stripped binary

* Tue Jul  3 2012 Sergey Budnevitch <sb@nginx.com>
- 1.2.2

* Tue Jun  5 2012 Sergey Budnevitch <sb@nginx.com>
- 1.2.1

* Mon Apr 23 2012 Sergey Budnevitch <sb@nginx.com>
- 1.2.0

* Thu Apr 12 2012 Sergey Budnevitch <sb@nginx.com>
- 1.0.15

* Thu Mar 15 2012 Sergey Budnevitch <sb@nginx.com>
- 1.0.14
- OpenSUSE init script and SuSE specific changes to spec file added

* Mon Mar  5 2012 Sergey Budnevitch <sb@nginx.com>
- 1.0.13

* Mon Feb  6 2012 Sergey Budnevitch <sb@nginx.com>
- 1.0.12
- banner added to install script

* Thu Dec 15 2011 Sergey Budnevitch <sb@nginx.com>
- 1.0.11
- init script enhancements (thanks to Gena Makhomed)
- one second sleep during upgrade replaced with 0.1 sec usleep

* Tue Nov 15 2011 Sergey Budnevitch <sb@nginx.com>
- 1.0.10

* Tue Nov  1 2011 Sergey Budnevitch <sb@nginx.com>
- 1.0.9
- nginx-debug package added

* Tue Oct 11 2011 Sergey Budnevitch <sb@nginx.com>
- spec file cleanup (thanks to Yury V. Zaytsev)
- log dir permitions fixed
- logrotate creates new logfiles with nginx owner
- "upgrade" argument to init-script added (based on fedora one)

* Sat Oct  1 2011 Sergey Budnevitch <sb@nginx.com>
- 1.0.8
- built with mp4 module

* Fri Sep 30 2011 Sergey Budnevitch <sb@nginx.com>
- 1.0.7

* Tue Aug 30 2011 Sergey Budnevitch <sb@nginx.com>
- 1.0.6
- replace "conf.d/*" config include with "conf.d/*.conf" in default nginx.conf

* Wed Aug 10 2011 Sergey Budnevitch
- Initial release
