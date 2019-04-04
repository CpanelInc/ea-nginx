# cpanel - Cpanel/ServiceManager/Services/Nginx.pm
#                                                    Copyright 2019 cPanel, L.L.C.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

package Cpanel::ServiceManager::Services::Nginx;

use strict;

use Cpanel::Class;    #issafe #nomunge
use Cpanel::SafeRun::Simple;
use Cpanel::LoadFile;
use Cwd;

extends 'Cpanel::ServiceManager::Base';

our $_initted     = 0;
our $is_systemctl = 0;

our $service_file = '/usr/lib/systemd/system/nginx.service';
our $initd_file   = '/etc/init.d/nginx';
our $pid_file     = '/var/run/nginx.pid';
our $nginx_file   = '/usr/sbin/nginx';

sub _init {
    return if $_initted;
    $_initted = 1;
    if ( -e $service_file ) {
        $is_systemctl = 1;
    }
    elsif ( !-e $initd_file ) {
        die "Nginx seems to have been uninstalled\n";
    }
}

sub stop {
    my ( $self, %opts ) = @_;
    _init();

    if ($is_systemctl) {
        Cpanel::SafeRun::Simple::saferun( '/usr/bin/systemctl', 'stop', 'nginx' );
    }
    else {
        Cpanel::SafeRun::Simple::saferun( $initd_file, 'stop' );
    }

    return 1;
}

sub start {
    my ( $self, %opts ) = @_;
    _init();

    if ($is_systemctl) {
        Cpanel::SafeRun::Simple::saferun( '/usr/bin/systemctl', 'start', 'nginx' );
    }
    else {
        Cpanel::SafeRun::Simple::saferun( $initd_file, 'start' );
    }

    return 1;
}

sub restart {
    my ( $self, %opts ) = @_;
    _init();

    if ($is_systemctl) {
        Cpanel::SafeRun::Simple::saferun( '/usr/bin/systemctl', 'reload', 'nginx' );
    }
    else {
        Cpanel::SafeRun::Simple::saferun( $initd_file, 'reload' );
    }

    return 1;
}

sub support_reload { return 1; }

sub status {
    _init();

    if ( !-e $pid_file ) {
        print "nginx is not running\n";
        return 3;
    }

    my $pid = Cpanel::LoadFile::load($pid_file);
    chomp($pid);

    my $exe_path = "/proc/$pid/exe";

    if ( !-e $exe_path ) {
        print "nginx is not running\n";
        return 3;
    }

    my $path = Cwd::abs_path($exe_path);

    if ( $path eq $nginx_file ) {
        print "nginx (pid $pid) is running\n";
        return 0;
    }

    print "nginx is not running\n";
    return 3;
}

sub check {
    eval { status(); };
    if ($@) {
        die $@;
    }

    return 1;
}

no Cpanel::Class;    #issafe #nomunge

1;
