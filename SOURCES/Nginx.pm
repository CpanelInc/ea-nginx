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
use Cpanel::LoadFile;
use Cwd;

extends 'Cpanel::ServiceManager::Base';

=head1 NAME

Cpanel::ServiceManager::Services::Nginx

=head1 SYNOPSIS

restartsrv driver for the 'Nginx' service.

=head1 DESCRIPTION

    exec('/usr/local/cpanel/scripts/restarsrv_nginx');

=cut

sub support_reload { return 1; }

# This should not be necessary but the Cpanel::ServiceManager::Base system is weird.
# Something in ULC is calling service_status (the attr that holds the value of the last call to status())
# before calling status() (the method which populates the service_status attr)
sub service_status {
    my ($self) = @_;

    if ( !defined $self->SUPER::service_status ) {
        $self->SUPER::service_status( $self->status );
    }

    return $self->SUPER::service_status;
}

1;
