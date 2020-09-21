package Cpanel::TaskProcessors::NginxTasks;

# cpanel - Cpanel/TaskProcessors/NginxTasks.pm     Copyright 2019 cPanel, L.L.C.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use strict;
use warnings;

=head1 NAME

Cpanel::TaskProcessors::NginxTasks

=cut

{

    package Cpanel::TaskProcessors::NginxTasks::rebuild_user;
    use parent 'Cpanel::TaskQueue::FastSpawn';

    sub is_valid_args {
        my ( $self, $task ) = @_;
        return 1 == $task->args;
    }

    sub _do_child_task {
        my ( $self, $task, $logger ) = @_;

        local @INC = ( '/var/cpanel/perl5/lib', @INC );
        require NginxHooks;

        my ($user) = $task->args();

        local $@;
        eval { NginxHooks::rebuild_user( $user, $logger ); };
        print STDERR "NginxTasks::rebuild_user: ($user) $@" if $@;

        return;
    }

}

{

    package Cpanel::TaskProcessors::NginxTasks::rebuild_config;
    use parent 'Cpanel::TaskQueue::FastSpawn';

    sub is_valid_args {
        my ( $self, $task ) = @_;
        return 0 == $task->args;
    }

    sub _do_child_task {
        my ( $self, $task, $logger ) = @_;

        local @INC = ( '/var/cpanel/perl5/lib', @INC );
        require NginxHooks;
        local $@;
        eval { NginxHooks::rebuild_config($logger); };
        print STDERR "NginxTasks::rebuild_config: $@" if $@;

        return;
    }

}

{

    package Cpanel::TaskProcessors::NginxTasks::rebuild_global;
    use parent 'Cpanel::TaskQueue::FastSpawn';

    sub is_valid_args {
        my ( $self, $task ) = @_;
        return 0 == $task->args;
    }

    sub _do_child_task {
        my ( $self, $task, $logger ) = @_;

        local @INC = ( '/var/cpanel/perl5/lib', @INC );
        require NginxHooks;
        local $@;
        eval { NginxHooks::rebuild_global($logger); };
        print STDERR "NginxTasks::rebuild_global: $@" if $@;

        return;
    }

}

=head2 to_register

rebuild_user - Rebuilds the Nginx config for a user

rebuild_config - Rebuilds the Nginx config for all users

=cut

sub to_register {
    return (
        [ 'rebuild_user',   Cpanel::TaskProcessors::NginxTasks::rebuild_user->new() ],
        [ 'rebuild_config', Cpanel::TaskProcessors::NginxTasks::rebuild_config->new() ],
        [ 'rebuild_global', Cpanel::TaskProcessors::NginxTasks::rebuild_global->new() ],
    );
}

1;
