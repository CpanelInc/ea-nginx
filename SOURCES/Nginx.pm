# cpanel - Cpanel/ServiceManager/Services/Nginx.pm
#                                                  Copyright 2020 cPanel, L.L.C.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

package Cpanel::ServiceManager::Services::Nginx;

use strict;
use warnings;

use Moo;
use Cpanel::SafeRun::Simple;

extends 'Cpanel::ServiceManager::Base';
has '+support_reload' => ( is => 'ro', default => 1 );

sub restart_gracefully {
    my ( $self, %opts ) = @_;

    if ( ref( $self->service_manager ) eq 'Cpanel::ServiceManager::Manager::Systemd' ) {
        Cpanel::SafeRun::Simple::saferun( '/usr/bin/systemctl', 'reload', 'nginx' );
    }
    else {
        Cpanel::SafeRun::Simple::saferun( '/etc/init.d/nginx', 'reload' );
    }

    return 1;
}

1;

