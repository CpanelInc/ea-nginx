package NginxHooks;

# cpanel - /var/cpanel/perl5/lib/NginxHooks.pm     Copyright 2019 cPanel, L.L.C.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use strict;
use warnings;

use Cpanel::AdminBin::Call ();
use Cpanel::Debug          ();

sub describe {
    my @phpfpm_actions = map {
        {
            'category' => 'Whostmgr',
            'event'    => $_,
            'stage'    => 'post',
            'hook'     => 'NginxHooks::_possible_php_fpm',
            'exectype' => 'module',
        }
    } (
        'Lang::PHP::set_vhost_versions',
    );
    my @script_php_fpm_config_actions = map {
        {
            'category' => 'scripts',
            'event'    => $_,
            'stage'    => 'post',
            'hook'     => 'NginxHooks::_php_fpm_config',
            'exectype' => 'module',
        }
    } (
        'php_fpm_config',
    );
    my @normal_actions = map {
        {
            'category' => 'Whostmgr',
            'event'    => $_,
            'stage'    => 'post',
            'hook'     => 'NginxHooks::_doit',
            'exectype' => 'module',
        }
    } (
        'Accounts::Create',
        'Accounts::Remove',
        'Accounts::suspendacct',
        'Accounts::unsuspendacct',
        'Accounts::Modify',
        'Domain::park',
        'Domain::unpark',
        'SSL::installssl',
        'AutoSSL::installssl',
        'SSL::delssl',
        'TweakSettings::Basic',
        'Hostname::change',
        'PipedLogConfiguration',
    );
    my @adminbin_actions = map {
        {
            'category' => 'Cpanel',
            'event'    => $_,
            'stage'    => 'post',
            'hook'     => 'NginxHooks::_do_adminbin',
            'exectype' => 'module',
        }
    } (
        'UAPI::SSL::delete_ssl',
        'UAPI::SSL::install_ssl',
        'UAPI::LangPHP::php_set_vhost_versions',
        'UAPI::WordPressInstanceManager::start_scan',
        'UAPI::SubDomain::addsubdomain',    # I do not see a delsubdomain
        'UAPI::Mime::add_redirect',
        'UAPI::Mime::delete_redirect',
        'UAPI::SSL::toggle_ssl_redirect_for_domains',
        'Api2::SubDomain::addsubdomain',
        'Api2::AddonDomain::addaddondomain',
        'Api2::Park::park',
        'Api1::Park::park',
        'Api2::SubDomain::delsubdomain',
        'Api2::AddonDomain::deladdondomain',
        'Api2::Park::unpark',
        'Api1::Park::unpark',
        'Api1::Htaccess::del_user',
        'Api1::Htaccess::set_pass',
        'Api1::Htaccess::set_protect',
        'Api1::Htaccess::set_index',
    );
    my @wordpress_actions = map {
        {
            'category' => 'Cpanel',
            'event'    => $_,
            'stage'    => 'post',
            'hook'     => 'NginxHooks::_do_wordpress',
            'exectype' => 'module',
        }
    } (
        'Api1::cPAddons::mainpg',
    );
    my $hook_ar = [
        @script_php_fpm_config_actions,
        @phpfpm_actions,
        @normal_actions,
        @adminbin_actions,
        @wordpress_actions,
    ];

    return $hook_ar;
}

sub get_time_to_wait {
    my ($get_long_time) = @_;

    $get_long_time ||= 0;

    require Cpanel::PHPFPM::Config;

    my $time_to_wait = 5;

    # due to the task queue dance that is played out, converting an account to
    # fpm can take upwards of 240 seconds, 300 pretty much guarantees it is
    # ready.  I wanted to pull from the PHPFPM::Constants, but alas it is not
    # a constant.

    $time_to_wait = 300 if ( $get_long_time || Cpanel::PHPFPM::Config::get_default_accounts_to_fpm() );
    return $time_to_wait;
}

sub _possible_php_fpm {
    local $@;
    eval {
        require Cpanel::ServerTasks;
        Cpanel::ServerTasks::schedule_task( ['NginxTasks'], get_time_to_wait(1), 'rebuild_config' );
    };
    return $@ ? ( 0, $@ ) : ( 1, "Success" );
}

sub _php_fpm_config {
    my ( $hook, $event ) = @_;

    local $@;

    if ( exists $event->{rebuild} && $event->{rebuild} ne "all" ) {
        require Cpanel::PHP::Config;

        my $php_config_ref = Cpanel::PHP::Config::get_php_config_for_domains( [ $event->{rebuild} ] );
        my $cpuser = $php_config_ref->{ $event->{rebuild} }->{username};

        Cpanel::Debug::log_info("_php_fpm_config: rebuild :$cpuser:");
        eval {
            require Cpanel::ServerTasks;
            Cpanel::ServerTasks::schedule_task( ['NginxTasks'], NginxHooks::get_time_to_wait(0), "rebuild_user $cpuser" );
        };
    }
    else {
        Cpanel::Debug::log_info("_php_fpm_config: rebuild all");
        eval {
            require Cpanel::ServerTasks;
            Cpanel::ServerTasks::schedule_task( ['NginxTasks'], get_time_to_wait(1), 'rebuild_config' );
        };
    }

    return $@ ? ( 0, $@ ) : ( 1, "Success" );
}

sub _doit {
    local $@;
    eval {
        require Cpanel::ServerTasks;

        Cpanel::ServerTasks::schedule_task( ['NginxTasks'], get_time_to_wait(0), 'rebuild_config' );
    };
    return $@ ? ( 0, $@ ) : ( 1, "Success" );
}

sub _do_adminbin {
    Cpanel::AdminBin::Call::call( 'Cpanel', 'nginx', 'UPDATE_CONFIG' );
    return;
}

sub _do_wordpress {
    my ( $hook, $event ) = @_;

    if ( exists $event->{args} ) {

        # Only react when the "addon" is WordPress.
        #
        # I do not know what "views" are relevant so we will act
        # on all of them.

        # the event hash ref looks like this
        #   {
        #     'args' => [
        #                 {
        #                   'addon' => 'cPanel::Blogs::WordPressX',
        #                   'view' => 'install',
        #                   'oneclick' => '1'
        #                 }
        #               ],
        #     'user' => 'cptest1',
        #     'output' => []
        #   }

        for my $arg ( @{ $event->{args} } ) {
            if ( exists $arg->{addon} && $arg->{addon} eq 'cPanel::Blogs::WordPressX' ) {
                Cpanel::AdminBin::Call::call( 'Cpanel', 'nginx', 'UPDATE_CONFIG' );
                last;
            }
        }
    }

    return;
}

sub rebuild_user {
    my ( $user, $logger ) = @_;

    return rebuild_config() if !$user;

    $logger->info("rebuild_user :$user:") if $logger;
    system( '/usr/local/cpanel/scripts/ea-nginx', 'config', $user );

    return;
}

sub rebuild_config {
    my ($logger) = @_;

    $logger->info("rebuild_config") if $logger;
    system( '/usr/local/cpanel/scripts/ea-nginx', 'config', '--all' );

    return;
}

1;

__END__

=head1 NAME

NginxHooks

=head1 SYNOPSIS

my $seconds_to_wait = NginxHooks::get_time_to_wait(1);

NginxHooks::_possible_php_fpm();

NginxHooks::_doit();

NginxHooks::_do_adminbin();

NginxHooks::rebuild_user( $user, $logger );

NginxHooks::rebuild_config($logger);

=head1 DESCRIPTION

NginxHooks responds to events in the cPanel system and rebuilds
the Nginx configuration as necessary.

NginxHooks.pm is deployed by the RPM to /var/cpanel/perl5/lib/.

cPanel recognizes that directory as a valid location for hooks modules.

During the installation of the RPM bin/manage_hooks is called to notify
cPanel of this hooks module.

The functions all respond either to the immediate hook itself, or from
the adminbin call (rebuild_user, rebuild_config).

=head1 SUBROUTINES

=head2 get_time_to_wait

Calculates the time to wait for a scheduled task to begin.  If you pass
the optional parameter (get_long_time) it will instead of calculating
will return the maximum time you should wait.

=over

=item C<$get_long_time> An optional parameter.  If true it will return
the maximum wait time.

=back

=head2 _possible_php_fpm

This schedules a rebuild of the Nginx configuration to happen in the
maximum amount of time, because this event could have turned PHP-FPM
on.

=head2 _doit

This schedules a rebuild of the Nginx configuration to happen in the
the amount of time that is necessary depending on whether PHP-FPM
is defaulted to on.

=head2 _do_adminbin

This is called from cpuser's account and raises the privilege using
the admin bin system.   This ultimately schedules a rebuild of the
Nginx configuration.

=head2 rebuild_user

This schedules a rebuild of the Nginx configuration for a cpuser.
This is called from the admin bin system.

=head2 rebuild_config

This schedules a rebuild of the Nginx configuration.
This is called from the admin bin system.

=cut

