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

=head1 NAME

Cpanel::ServiceManager::Services::Nginx

=head1 SYNOPSIS

restartsrv driver for the 'apache_php_fpm' service.

=head1 DESCRIPTION

    exec('/usr/local/cpanel/scripts/restarsrv_apache_php_fpm');

=head1 SUBROUTINES

=head2 _init

Handles initialization, which at the moment is just whether this
system supports systemd or init.d.

If Nginx is not installed this routine will die.

=cut

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

=head2 stop

Stops nginx. Returns 1 unless something throws an exception.

=cut

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

=head2 start

Starts nginx. Returns 1 unless something throws an exception.

=cut

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

=head2 restart

Restarts nginx.  In the parlance of the nginx scripts, this is really a "reload"
so call reload.

=cut

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

=head2 support_reload

Nginx supports the reload option.

=cut

sub support_reload { return 1; }

=head2 status

Determine if nginx is running or not.

=cut

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

no Cpanel::Class;    #issafe #nomunge

1;
