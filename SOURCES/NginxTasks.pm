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

    package Cpanel::TaskProcessors::NginxTasks::clear_user_cache;
    use parent 'Cpanel::TaskQueue::FastSpawn';

    our $ea_nginx_script = '/usr/local/cpanel/scripts/ea-nginx';

    sub is_valid_args {
        my ( $self, $task ) = @_;
        return 1 == $task->args;
    }

    sub _do_child_task {
        my ( $self, $task, $logger ) = @_;

        return if !-e $ea_nginx_script;
        require $ea_nginx_script;

        my ($user) = $task->args();

        local $@;
        eval { scripts::ea_nginx::clear_cache($user); };
        print STDERR "scripts::ea_nginx::clear_cache: ($user) $@" if $@;

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

{

    package Cpanel::TaskProcessors::NginxTasks::reload_logs;
    use parent 'Cpanel::TaskQueue::FastSpawn';

    sub overrides {
        my ( $self, $new, $old ) = @_;
        my $is_dupe = $self->is_dupe( $new, $old );
        return $is_dupe;
    }

    sub is_valid_args {
        my ( $self, $task ) = @_;
        return 0 == $task->args;
    }

    sub _do_child_task {
        my ( $self, $task, $logger ) = @_;

        my $nginx_pid = $self->get_nginx_pid();
        kill 'USR1', $nginx_pid;
        return;
    }

    sub get_nginx_pid {
        require Cpanel::LoadFile;

        my $pid_file = '/var/run/nginx.pid';
        my $pid      = Cpanel::LoadFile::load($pid_file);

        return $pid;
    }

}

{

    package Cpanel::TaskProcessors::NginxTasks::reload_service;
    use parent 'Cpanel::TaskQueue::FastSpawn';

    our $ea_nginx_script = '/usr/local/cpanel/scripts/ea-nginx';

    sub overrides {
        my ( $self, $new, $old ) = @_;
        my $is_dupe = $self->is_dupe( $new, $old );
        return $is_dupe;
    }

    sub is_valid_args {
        my ( $self, $task ) = @_;
        return 0 == $task->args;
    }

    sub _do_child_task {
        my ( $self, $task, $logger ) = @_;

        return if !-e $ea_nginx_script;
        require $ea_nginx_script;

        # Go through run to go through the lock code
        # and thus avoid potential race conditions where
        # multiple instances of the script are executing
        local $@;
        eval { scripts::ea_nginx::run('reload'); };
        print STDERR "scripts::ea_nginx::run('reload') $@" if $@;

        return;
    }

    sub is_task_deferred {
        my ( $self, $task, $defer_hash ) = @_;

        return 1 if $self->SUPER::is_task_deferred( $task, $defer_hash );

        return $self->_is_task_deferred_by_httpd_deferred_restart_time();
    }

    sub _is_task_deferred_by_httpd_deferred_restart_time {
        my ($self) = @_;

        my $pid_file = '/var/run/nginx.pid';

        require Cpanel::Config::LoadCpConf;
        my $cpconf = Cpanel::Config::LoadCpConf::loadcpconf();

        if ( $cpconf->{httpd_deferred_restart_time} ) {
            my $pidtime = ( stat $pid_file )[9];
            return   if !$pidtime;
            return 1 if $pidtime + $cpconf->{httpd_deferred_restart_time} > time();
        }

        return;
    }

}

=head2 to_register

rebuild_user - Rebuilds the Nginx config for a user

rebuild_config - Rebuilds the Nginx config for all users

rebuild_global - Rebuilds the Nginx global config

clear_user_cache - clears the cache for one user

reload_logs - sends SIGUSR1 to nginx which signals it to reload its logs

reload_service - reloads the nginx service

=cut

sub to_register {
    return (
        [ 'rebuild_user',     Cpanel::TaskProcessors::NginxTasks::rebuild_user->new() ],
        [ 'rebuild_config',   Cpanel::TaskProcessors::NginxTasks::rebuild_config->new() ],
        [ 'rebuild_global',   Cpanel::TaskProcessors::NginxTasks::rebuild_global->new() ],
        [ 'clear_user_cache', Cpanel::TaskProcessors::NginxTasks::clear_user_cache->new() ],
        [ 'reload_logs',      Cpanel::TaskProcessors::NginxTasks::reload_logs->new() ],
        [ 'reload_service',   Cpanel::TaskProcessors::NginxTasks::reload_service->new() ],
    );
}

1;
