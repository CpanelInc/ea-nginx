#
%define upstream_name nginx
%define nginx_home %{_localstatedir}/cache/nginx
%define nginx_user nobody
%define nginx_group nobody
%define nginx_loggroup adm

# distribution specific definitions
%define use_systemd (0%{?fedora} && 0%{?fedora} >= 18) || (0%{?rhel} && 0%{?rhel} >= 7) || (0%{?suse_version} >= 1315)

%define ea_openssl_ver 1.1.1d-1
Requires: ea-openssl11 >= %{ea_openssl_ver}
BuildRequires: ea-openssl11 >= %{ea_openssl_ver}
BuildRequires: ea-openssl11-devel >= %{ea_openssl_ver}

%if 0%{?rhel} == 6
%define _group System Environment/Daemons
Requires(pre): shadow-utils
Requires: initscripts >= 8.36
Requires(post): chkconfig
%endif

%if 0%{?rhel} == 7
BuildRequires: redhat-lsb-core
%define _group System Environment/Daemons
%define epoch 1
Epoch: %{epoch}
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

%if 0%{?suse_version} >= 1315
%define _group Productivity/Networking/Web/Servers
%define nginx_loggroup trusted
Requires(pre): shadow
Requires: systemd
BuildRequires: libopenssl-devel
BuildRequires: systemd
%endif

# end of distribution specific definitions

%define main_version 1.18.0

%define bdir %{_builddir}/%{upstream_name}-%{main_version}

%define WITH_CC_OPT $(echo %{optflags} $(pcre-config --cflags)) -fPIC -I/opt/cpanel/ea-openssl11/include
%define WITH_LD_OPT -Wl,-z,relro -Wl,-z,now -pie -L/opt/cpanel/ea-openssl11/%{_lib} -ldl -Wl,-rpath=/opt/cpanel/ea-openssl11/%{_lib}

%define BASE_CONFIGURE_ARGS $(echo "--prefix=%{_sysconfdir}/nginx --sbin-path=%{_sbindir}/nginx --modules-path=%{_libdir}/nginx/modules --conf-path=%{_sysconfdir}/nginx/nginx.conf --error-log-path=%{_localstatedir}/log/nginx/error.log --http-log-path=%{_localstatedir}/log/nginx/access.log --pid-path=%{_localstatedir}/run/nginx.pid --lock-path=%{_localstatedir}/run/nginx.lock --http-client-body-temp-path=%{_localstatedir}/cache/nginx/client_temp --http-proxy-temp-path=%{_localstatedir}/cache/nginx/proxy_temp --http-fastcgi-temp-path=%{_localstatedir}/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=%{_localstatedir}/cache/nginx/uwsgi_temp --http-scgi-temp-path=%{_localstatedir}/cache/nginx/scgi_temp --user=%{nginx_user} --group=%{nginx_group} --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-openssl-opt=enable-tls1_3 --with-openssl-opt=no-nextprotoneg")

Summary: High performance web server
Name: ea-nginx
Version: %{main_version}
# Doing release_prefix this way for Release allows for OBS-proof versioning, See EA-4544 for more details
%define release_prefix 1
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
Source10: nginx.suse.logrotate
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

License: 2-clause BSD-like license

BuildRoot: %{_tmppath}/%{upstream_name}-%{main_version}-%{release}-root
BuildRequires: zlib-devel
BuildRequires: pcre-devel

Provides: webserver

%description
nginx [engine x] is an HTTP and reverse proxy server, as well as
a mail proxy server.

%if 0%{?suse_version} >= 1315
%debug_package
%endif

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

%build
./configure %{BASE_CONFIGURE_ARGS} \
    --with-cc-opt="%{WITH_CC_OPT}" \
    --with-ld-opt="%{WITH_LD_OPT}" \
    --with-debug \
    --add-dynamic-module=ngx_http_pipelog_module
make %{?_smp_mflags}
%{__mv} %{bdir}/objs/nginx \
    %{bdir}/objs/nginx-debug
./configure %{BASE_CONFIGURE_ARGS} \
    --with-cc-opt="%{WITH_CC_OPT}" \
    --with-ld-opt="%{WITH_LD_OPT}" \
    --add-dynamic-module=ngx_http_pipelog_module
make %{?_smp_mflags}

cp -f %{SOURCE22} .
cp -f %{SOURCE23} .
cp -f %{SOURCE24} .
cp -f %{SOURCE25} .

%install
%{__rm} -rf $RPM_BUILD_ROOT
%{__make} DESTDIR=$RPM_BUILD_ROOT INSTALLDIRS=vendor install

%{__mkdir} -p $RPM_BUILD_ROOT%{_datadir}/nginx
%{__mv} $RPM_BUILD_ROOT%{_sysconfdir}/nginx/html $RPM_BUILD_ROOT%{_datadir}/nginx/

%{__rm} -f $RPM_BUILD_ROOT%{_sysconfdir}/nginx/*.default
%{__rm} -f $RPM_BUILD_ROOT%{_sysconfdir}/nginx/fastcgi.conf

%{__mkdir} -p $RPM_BUILD_ROOT%{_localstatedir}/log/nginx/domains
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
mkdir cpanel && cd cpanel && tar xzf %{SOURCE14}  && cd ..
cp -r cpanel/conf.d/* $RPM_BUILD_ROOT%{_sysconfdir}/nginx/conf.d

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
%if 0%{?suse_version}
%{__install} -m 644 -p %{SOURCE10} \
    $RPM_BUILD_ROOT%{_sysconfdir}/logrotate.d/nginx
%else
%{__install} -m 644 -p %{SOURCE1} \
    $RPM_BUILD_ROOT%{_sysconfdir}/logrotate.d/nginx
%endif

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

%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/cpanel-proxy-non-ssl.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/includes-optional/cpanel-fastcgi.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/includes-optional/cpanel-proxy.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/includes-optional/cpanel-cgi-location.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/includes-optional/cpanel-server-parsed-location.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/server-includes/cpanel-dcv.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/server-includes/cpanel-mailman-locations.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/server-includes/cpanel-redirect-locations.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/server-includes/cpanel-static-locations.conf
%config(noreplace) %attr(644, root, root) %{_sysconfdir}/nginx/conf.d/ea-nginx.conf
%attr(644, root, root) %{_sysconfdir}/nginx/conf.d/users.conf

%dir %{_sysconfdir}/nginx/ea-nginx
%attr(755, root, root) %{_sysconfdir}/nginx/ea-nginx/meta/apache
%config(noreplace) %{_sysconfdir}/nginx/ea-nginx/meta/apache_port.initial
%config(noreplace) %{_sysconfdir}/nginx/ea-nginx/meta/apache_ssl_port.initial
%config(noreplace) %{_sysconfdir}/nginx/ea-nginx/settings.json
%{_sysconfdir}/nginx/ea-nginx/cpanel-password-protected-dirs.tt
%{_sysconfdir}/nginx/ea-nginx/cpanel-php-location.tt
%{_sysconfdir}/nginx/ea-nginx/cpanel-wordpress-location.tt
%{_sysconfdir}/nginx/ea-nginx/ea-nginx.conf.tt
%{_sysconfdir}/nginx/ea-nginx/server.conf.tt
%{_sysconfdir}/nginx/ea-nginx/global-logging.tt

%attr(755, root, root) /usr/local/cpanel/scripts/ea-nginx
%attr(755, root, root) /usr/local/cpanel/scripts/ea-nginx-userdata
/usr/local/cpanel/scripts/restartsrv_nginx
/etc/chkserv.d/nginx

%{_sysconfdir}/nginx/modules

%config(noreplace) %{_sysconfdir}/nginx/nginx.conf
%config(noreplace) %{_sysconfdir}/nginx/conf.d/default.conf
%config(noreplace) %{_sysconfdir}/nginx/mime.types
%config(noreplace) %{_sysconfdir}/nginx/fastcgi_params
%config(noreplace) %{_sysconfdir}/nginx/scgi_params
%config(noreplace) %{_sysconfdir}/nginx/uwsgi_params
%config(noreplace) %{_sysconfdir}/nginx/koi-utf
%config(noreplace) %{_sysconfdir}/nginx/koi-win
%config(noreplace) %{_sysconfdir}/nginx/win-utf

%config(noreplace) %{_sysconfdir}/logrotate.d/nginx
%config(noreplace) %{_sysconfdir}/sysconfig/nginx
%config(noreplace) %{_sysconfdir}/sysconfig/nginx-debug
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

%dir %{_datadir}/nginx
%dir %{_datadir}/nginx/html
%{_datadir}/nginx/html/*

%attr(0755,root,root) %dir %{_localstatedir}/cache/nginx
%attr(0755,root,root) %dir %{_localstatedir}/log/nginx
%attr(0711,root,root) %dir %{_localstatedir}/log/nginx/domains

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

%pre
# we need to know the version of cPanel, the hooks cannot be deployed
# before version 11.80
cpversion=`/usr/local/cpanel/3rdparty/bin/perl -MCpanel::Version -e 'print Cpanel::Version::get_short_release_number()'`
if [ $cpversion -ge 80 ]; then
    # do not let nginx hooks run during upgrade. Use GTE because it can go higher,
    # but anything 2 or greater is still an upgrade.
    # Also deregister the hooks on this step, as that's the right point to do it
    if [ $1 -ge 2 ]; then
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
# Register the nginx service
if [ $1 -eq 1 ]; then
%if %{use_systemd}
    /usr/bin/systemctl preset nginx.service >/dev/null 2>&1 ||:
    /usr/bin/systemctl preset nginx-debug.service >/dev/null 2>&1 ||:
    /usr/bin/systemctl enable nginx.service >/dev/null 2>&1 ||:
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

# record the current value of fileprotect
if [ -e /var/cpanel/fileprotect ];
then
    touch /etc/nginx/ea-nginx/meta/fileprotect
else
    rm -f /etc/nginx/ea-nginx/meta/fileprotect
fi

# disable file protect

/usr/local/cpanel/bin/whmapi1 set_tweaksetting key=enablefileprotect value=0

%posttrans
# I move this to here, to deal with the craziness of the order of operations
# on yum upgrade and downgrades.
/usr/local/cpanel/scripts/ea-nginx config --all

cpversion=`/usr/local/cpanel/3rdparty/bin/perl -MCpanel::Version -e 'print Cpanel::Version::get_short_release_number()'`
if [ $cpversion -ge 80 ]; then
    # Remove "bad" hooks that were left around by a bad previous version of the RPM
    # Ignore failures in case you are on a version of cPanel too old for feature
    /usr/local/cpanel/bin/manage_hooks prune; /bin/true;
    /usr/local/cpanel/bin/manage_hooks add module NginxHooks
fi

%preun
# we need to know the version of cPanel, the hooks cannot be deployed
# before version 11.80
cpversion=`/usr/local/cpanel/3rdparty/bin/perl -MCpanel::Version -e 'print Cpanel::Version::get_short_release_number()'`
if [ $cpversion -ge 80 ]; then
    /usr/local/cpanel/bin/manage_hooks delete module NginxHooks
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

if [ -e /etc/nginx/ea-nginx/meta/fileprotect ]; then
    rm -f /etc/nginx/ea-nginx/meta/fileprotect
    /usr/local/cpanel/bin/whmapi1 set_tweaksetting key=enablefileprotect value=1
fi
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

if [ $1 -ge 1 ]; then
    /sbin/service nginx status  >/dev/null 2>&1 || exit 0
    /sbin/service nginx upgrade >/dev/null 2>&1 || echo \
        "Binary upgrade failed, please check nginx's error.log"
fi


%changelog
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

* Wed Oct 01 2019 Daniel Muey <dan@cpanel.net> - 1.17.4-2
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
