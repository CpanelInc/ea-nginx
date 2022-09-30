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
        'Lang::PHP::ini_set_content',
        'Lang::PHP::set_system_default_version',
        'Lang::PHP::ini_set_directives',
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
    my @modsecurity_category = map {
        {
            'category' => 'ModSecurity',
            'event'    => $_,
            'stage'    => 'post',

            # NOTE: this is an admin bin, but is called on the raised
            # privileges side

            'hook'     => 'NginxHooks::_modsecurity_user',
            'exectype' => 'module',
        }
    } (
        'adjust_secruleengineoff',
    );
    my @modsec_vendor = map {
        {
            'category' => 'scripts',
            'event'    => $_,
            'stage'    => 'post',
            'hook'     => 'NginxHooks::_rebuild_global',
            'exectype' => 'module',
        }
    } (
        'modsec_vendor::add',
        'modsec_vendor::remove',
        'modsec_vendor::update',
        'modsec_vendor::enable',
        'modsec_vendor::disable',
        'modsec_vendor::enable_updates',
        'modsec_vendor::disable_updates',
        'modsec_vendor::enable_configs',
        'modsec_vendor::disable_configs',
    );
    my @build_apache_conf = map {
        {
            'category' => 'scripts',
            'event'    => $_,
            'stage'    => 'post',
            'hook'     => 'NginxHooks::_rebuild_config_all',
            'exectype' => 'module',
        }
    } (
        'build_apache_conf',
    );
    my @global_actions = map {
        {
            'category' => 'Whostmgr',
            'event'    => $_,
            'stage'    => 'post',
            'hook'     => 'NginxHooks::_rebuild_global',
            'exectype' => 'module',
        }
    } (
        'ModSecurity::modsec_add_rule',
        'ModSecurity::modsec_add_vendor',
        'ModSecurity::modsec_assemble_config_text',
        'ModSecurity::modsec_batch_settings',
        'ModSecurity::modsec_clone_rule',
        'ModSecurity::ModsecCpanelConf::manipulate',
        'ModSecurity::modsec_deploy_all_rule_changes',
        'ModSecurity::modsec_deploy_rule_changes',
        'ModSecurity::modsec_deploy_settings_changes',
        'ModSecurity::modsec_disable_rule',
        'ModSecurity::modsec_disable_vendor',
        'ModSecurity::modsec_disable_vendor_configs',
        'ModSecurity::modsec_disable_vendor_updates',
        'ModSecurity::modsec_discard_rule_changes',
        'ModSecurity::modsec_edit_rule',
        'ModSecurity::modsec_enable_vendor',
        'ModSecurity::modsec_enable_vendor_configs',
        'ModSecurity::modsec_enable_vendor_updates',
        'ModSecurity::modsec_make_config_active',
        'ModSecurity::modsec_make_config_inactive',
        'ModSecurity::modsec_remove_rule',
        'ModSecurity::modsec_remove_setting',
        'ModSecurity::modsec_remove_vendor',
        'ModSecurity::modsec_set_config_text',
        'ModSecurity::modsec_set_setting',
        'ModSecurity::modsec_undisable_rule',
        'ModSecurity::modsec_update_vendor',
    );
    my @just_clear_cache_actions = map {
        {
            'category' => 'Whostmgr',
            'event'    => $_,
            'stage'    => 'post',
            'hook'     => 'NginxHooks::_just_clear_user_cache',
            'exectype' => 'module',
        }
    } (
        'Accounts::suspendacct',
        'Accounts::unsuspendacct',
    );
    my @rebuild_user_actions = map {
        {
            'category' => 'Whostmgr',
            'event'    => $_,
            'stage'    => 'post',
            'hook'     => 'NginxHooks::_rebuild_user',
            'exectype' => 'module',
        }
    } (
        'Accounts::Create',
        'Accounts::SiteIP::set',
        'AutoSSL::installssl',
        'SSL::delssl',
        'SSL::installssl',
        'Domain::park',
        'Domain::unpark',
    );
    my @normal_actions = map {
        {
            'category' => 'Whostmgr',
            'event'    => $_,
            'stage'    => 'post',
            'hook'     => 'NginxHooks::_rebuild_config_all',
            'exectype' => 'module',
        }
    } (
        'Accounts::Modify',
        'Accounts::Remove',
        'Hostname::change',
        'PipedLogConfiguration',
        'TweakSettings::Basic',
        'TweakSettings::Main',
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
        'Api1::Htaccess::del_user',
        'Api1::Htaccess::set_index',
        'Api1::Htaccess::set_pass',
        'Api1::Htaccess::set_protect',
        'Api1::Park::park',
        'Api1::Park::unpark',
        'Api2::AddonDomain::addaddondomain',
        'Api2::AddonDomain::deladdondomain',
        'Api2::Park::park',
        'Api2::Park::unpark',
        'Api2::SubDomain::addsubdomain',
        'Api2::SubDomain::delsubdomain',
        'UAPI::LangPHP::php_set_vhost_versions',
        'UAPI::LangPHP::php_ini_set_user_content',
        'UAPI::LangPHP::php_ini_set_user_basic_directives',
        'UAPI::Mime::add_redirect',
        'UAPI::Mime::delete_redirect',
        'UAPI::SSL::delete_ssl',
        'UAPI::SSL::install_ssl',
        'UAPI::SSL::toggle_ssl_redirect_for_domains',
        'UAPI::SubDomain::addsubdomain',    # I do not see a delsubdomain
        'UAPI::WordPressInstanceManager::start_scan',
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
    my @cpanellogd_user_actions = map {
        {
            'category' => 'Stats',
            'event'    => $_,
            'stage'    => 'post',
            'hook'     => 'NginxHooks::_do_reload_logs_adminbin',
            'exectype' => 'module',
        }
    } (
        'RunUser',
    );
    my @cpanellogd_actions = map {
        {
            'category' => 'Stats',
            'event'    => $_,
            'stage'    => 'post',
            'hook'     => 'NginxHooks::_reload_logs',
            'exectype' => 'module',
        }
    } (
        'RunAll',
    );
    my $hook_ar = [
        @adminbin_actions,
        @build_apache_conf,
        @global_actions,
        @modsecurity_category,
        @modsec_vendor,
        @normal_actions,
        @rebuild_user_actions,
        @phpfpm_actions,
        @script_php_fpm_config_actions,
        @wordpress_actions,
        @just_clear_cache_actions,
        @cpanellogd_user_actions,
        @cpanellogd_actions,
    ];

    return $hook_ar;
}

sub get_time_to_wait {
    my ($get_long_time) = @_;

    $get_long_time ||= 0;

    require Cpanel::PHPFPM::Config;
    require Cpanel::PHPFPM::Constants;

    my $time_to_wait      = 5;
    my $delay_for_rebuild = $Cpanel::PHPFPM::Constants::delay_for_rebuild if $Cpanel::PHPFPM::Constants::delay_for_rebuild;
    $delay_for_rebuild ||= 10;    # based on the constant value in 96

    $time_to_wait += $delay_for_rebuild if ( $get_long_time || Cpanel::PHPFPM::Config::get_default_accounts_to_fpm() );
    return $time_to_wait;
}

sub _possible_php_fpm {
    my ( $hook, $event ) = @_;

    require Cpanel::Form::Param;

    my $prm     = Cpanel::Form::Param->new( { parseform_hr => $event } );
    my @domains = $prm->param('vhost');
    my @users;

    if (@domains) {
        require Cpanel::PHP::Config;

        my $php_config_ref = Cpanel::PHP::Config::get_php_config_for_domains( \@domains );
        my %users_hash;
        foreach my $domain ( keys %{$php_config_ref} ) {
            $users_hash{ $php_config_ref->{$domain}->{username} } = 1;
        }
        push( @users, keys %users_hash );
    }

    if (@users) {
        local $@;
        eval {
            require Cpanel::ServerTasks;
            foreach my $user (@users) {
                Cpanel::ServerTasks::schedule_task( ['NginxTasks'], get_time_to_wait(1), "rebuild_user $user" );
            }
        };
        return $@ ? ( 0, $@ ) : ( 1, "Success" );
    }
    else {
        local $@;
        eval {
            require Cpanel::ServerTasks;
            Cpanel::ServerTasks::schedule_task( ['NginxTasks'], get_time_to_wait(1), 'rebuild_config' );
        };
        return $@ ? ( 0, $@ ) : ( 1, "Success" );
    }
}

sub _modsecurity_user {
    my ( $hook, $event ) = @_;

    local $@;

    if ( exists $event->{user} ) {
        my $cpuser = $event->{user};

        Cpanel::Debug::log_info("_modsecurity_user: adjust_secruleengineoff :$cpuser:");
        eval {
            require Cpanel::ServerTasks;
            Cpanel::ServerTasks::schedule_task( ['NginxTasks'], NginxHooks::get_time_to_wait(0), "rebuild_user $cpuser" );
        };
    }

    return $@ ? ( 0, $@ ) : ( 1, "Success" );
}

sub _php_fpm_config {
    my ( $hook, $event ) = @_;

    local $@;

    if ( exists $event->{rebuild} && $event->{rebuild} ne "all" ) {
        require Cpanel::PHP::Config;

        my $php_config_ref = Cpanel::PHP::Config::get_php_config_for_domains( [ $event->{rebuild} ] );
        my $cpuser         = $php_config_ref->{ $event->{rebuild} }->{username};

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

sub _just_clear_user_cache {
    my ( $hook, $event ) = @_;

    my $user = $event->{args}->{user};

    if ($user) {
        eval {
            require Cpanel::ServerTasks;

            # 2 seconds seems like a good minimal time to wait
            Cpanel::ServerTasks::schedule_task( ['NginxTasks'], 2, "clear_user_cache $user" );
        };
    }
    else {
        return ( 0, "Missing User" );
    }

    return $@ ? ( 0, $@ ) : ( 1, "Success" );
}

sub _rebuild_user {
    my ( $hook, $event ) = @_;

    my $cpuser;
    my $domain;

    if ( exists $event->{user} ) {
        $cpuser = $event->{user};
        Cpanel::Debug::log_info("_rebuild_user: 001 User :$cpuser:");
    }

    if ( !$cpuser && exists $event->{domain} ) {
        require Cpanel::PHP::Config;

        $domain = $event->{domain};

        Cpanel::Debug::log_info("_rebuild_user: 002 Domain :$domain:");

        my @domains        = ($domain);
        my $php_config_ref = Cpanel::PHP::Config::get_php_config_for_domains( \@domains );

        $cpuser = $php_config_ref->{$domain}->{username} if exists $php_config_ref->{$domain}->{username};

        Cpanel::Debug::log_info("_rebuild_user: 003 User :$cpuser:") if defined $cpuser;
    }

    if ( !defined $cpuser && exists $event->{domainowner} ) {
        $cpuser = $event->{domainowner};
    }

    if ( defined $cpuser ) {
        Cpanel::Debug::log_info("_rebuild_user: 004 User :$cpuser:");
        eval {
            require Cpanel::ServerTasks;
            Cpanel::ServerTasks::schedule_task( ['NginxTasks'], NginxHooks::get_time_to_wait(0), "rebuild_user $cpuser" );
        };

        return $@ ? ( 0, $@ ) : ( 1, "Success" );
    }

    Cpanel::Debug::log_info("_rebuild_user: User Not Found, Fallback to rebuild_all");
    return _rebuild_config_all( $hook, $event );
}

sub _rebuild_config_all {
    my ( $hook, $event ) = @_;

    local $@;
    eval {
        require Cpanel::ServerTasks;

        Cpanel::ServerTasks::schedule_task( ['NginxTasks'], get_time_to_wait(0), 'rebuild_config' );
    };

    return $@ ? ( 0, $@ ) : ( 1, "Success" );
}

sub _rebuild_global {
    local $@;
    eval {
        require Cpanel::ServerTasks;

        Cpanel::ServerTasks::schedule_task( ['NginxTasks'], get_time_to_wait(0), 'rebuild_global' );
    };
    return $@ ? ( 0, $@ ) : ( 1, "Success" );
}

sub _reload_logs {
    local $@;
    eval {
        require Cpanel::ServerTasks;
        Cpanel::ServerTasks::schedule_task( ['NginxTasks'], 5, 'reload_logs' );
    };
    return $@ ? ( 0, $@ ) : ( 1, "Success" );
}

sub _do_reload_logs_adminbin {
    Cpanel::AdminBin::Call::call( 'Cpanel', 'nginx', 'RELOAD_LOGS' );
    return;
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

sub rebuild_global {
    my ($logger) = @_;

    $logger->info("rebuild_config") if $logger;
    system( '/usr/local/cpanel/scripts/ea-nginx', 'config', '--global' );

    return;
}

1;

__END__

=head1 NAME

NginxHooks

=head1 SYNOPSIS

my $seconds_to_wait = NginxHooks::get_time_to_wait(1);

NginxHooks::_possible_php_fpm();

NginxHooks::_rebuild_config_all();

NginxHooks::_rebuild_global();

NginxHooks::_do_adminbin();

NginxHooks::_reload_logs();

NginxHooks::_do_reload_logs_adminbin();

NginxHooks::rebuild_user( $user, $logger );

NginxHooks::rebuild_config($logger);

NginxHooks::rebuild_global($logger);

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

=head2 _rebuild_config_all

This schedules a rebuild of the Nginx configuration to happen in the
the amount of time that is necessary depending on whether PHP-FPM
is defaulted to on.  This will configure the global options and also
for all the users.

=head2 _rebuild_global

This schedules a rebuild of the Nginx configuration to happen in the
the amount of time that is necessary. This will configure the global
options only.

=head2 _do_adminbin

This is called from cpuser's account and raises the privilege using
the admin bin system.   This ultimately schedules a rebuild of the
Nginx configuration.

=head2 rebuild_user

Action from the Task system.
Rebuilds the ea-nginx config for a user.

=head2 rebuild_config

Action from the Task system.
Rebuilds the ea-nginx config for all users.

=head2 rebuild_global

Action from the Task system.
Rebuilds the ea-nginx global configs only.

=head2 _reload_logs

This schedules sending a signal to the nginx process that tells it to reload
its logs.

=head2 _do_reload_logs_adminbin

This is called from cpuser's account and raises the privilege using the admin
bin system.  This ultimately schedules sending a signal to the nginx process
that tells it to reload its logs.

=cut

