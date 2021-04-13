#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/SOURCES-cpanel-scripts-ea-nginx.t     Copyright 2019 cPanel, L.L.C.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

## no critic qw(TestingAndDebugging::RequireUseStrict TestingAndDebugging::RequireUseWarnings)
use Test::Spec;    # automatically turns on strict and warnings

use FindBin;

use Cpanel::ServerTasks       ();
use Cpanel::PHPFPM::Config    ();
use Cpanel::AdminBin::Call    ();
use Cpanel::PHPFPM::Constants ();

use Test::MockModule;
use Test::MockFile;

our $system_calls   = [];
our $system_rv      = 0;
our $current_system = sub {
    push @{$system_calls}, [@_];
    $? = $system_rv;
    return $system_rv;
};
use Test::Mock::Cmd 'system' => sub { $current_system->(@_) };

our @glob_res;

my %conf = (
    require => "$FindBin::Bin/../SOURCES/NginxHooks.pm",
    package => "NginxHooks",
);

require $conf{require};

my @log_output;
my $delay_time = $Cpanel::PHPFPM::Constants::delay_for_rebuild + 5;

package test::logger {

    sub new {
        my $self = {};
        bless $self, 'test::logger';
        return $self;
    }

    sub info {
        my ( $self, $msg ) = @_;
        push( @log_output, $msg );
        return;
    }
}

describe "NginxHooks" => sub {
    describe "get_time_to_wait" => sub {
        share my %mi;
        around {
            %mi = %conf;

            local $mi{mocks} = {};

            $mi{mocks}->{phpfpm_config}        = Test::MockModule->new('Cpanel::PHPFPM::Config');
            $mi{mocks}->{phpfpm_config_status} = 0;
            $mi{mocks}->{phpfpm_config}->redefine(
                get_default_accounts_to_fpm => sub {
                    return $mi{mocks}->{phpfpm_config_status};
                }
            );

            yield;
        };

        it "should return 5 if phpfpm is not default and not long time set" => sub {
            my $ret = NginxHooks::get_time_to_wait(0);
            is( $ret, 5 );
        };

        it "should return 5 if phpfpm is not default and long time is undef" => sub {
            my $ret = NginxHooks::get_time_to_wait();
            is( $ret, 5 );
        };

        it "should return $delay_time if phpfpm is not default and long time set" => sub {
            my $ret = NginxHooks::get_time_to_wait(1);
            is( $ret, $delay_time );
        };

        it "should return $delay_time if phpfpm is default and not long time set" => sub {
            $mi{mocks}->{phpfpm_config_status} = 1;
            my $ret = NginxHooks::get_time_to_wait(0);
            is( $ret, $delay_time );
        };

        it "should return $delay_time if phpfpm is default and long time set" => sub {
            $mi{mocks}->{phpfpm_config_status} = 1;
            my $ret = NginxHooks::get_time_to_wait(1);
            is( $ret, $delay_time );
        };
    };

    describe "_possible_php_fpm" => sub {
        share my %mi;
        around {
            %mi = %conf;

            local $mi{mocks} = {};

            $mi{mocks}->{phpfpm_config} = Test::MockModule->new('Cpanel::PHPFPM::Config');
            $mi{mocks}->{phpfpm_config}->redefine(
                get_default_accounts_to_fpm => sub {
                    return 1;
                }
            );

            $mi{mocks}->{servertasks}           = Test::MockModule->new('Cpanel::ServerTasks');
            $mi{mocks}->{servertasks_tasks}     = [];
            $mi{mocks}->{servertasks_shoulddie} = 0;
            $mi{mocks}->{servertasks}->redefine(
                schedule_task => sub {
                    my ( $ar, $time_to_wait, $task ) = @_;
                    my $str = join( ',', @{$ar}, $time_to_wait, $task );
                    push( @{ $mi{mocks}->{servertasks_tasks} }, $str );
                    die "a horrible death" if ( $mi{mocks}->{servertasks_shoulddie} );
                    return;
                }
            );

            yield;
        };

        it "should do the thing if happy path" => sub {
            my ( $ret, $msg ) = NginxHooks::_possible_php_fpm();
            my $expected_ar = ["NginxTasks,$delay_time,rebuild_config"];

            is_deeply( $mi{mocks}->{servertasks_tasks}, $expected_ar );
        };

        it "should return success on happy path" => sub {
            my ( $ret, $msg ) = NginxHooks::_possible_php_fpm();
            is( $ret, 1 );
        };

        it "should return failure if scheduler fails" => sub {
            $mi{mocks}->{servertasks_shoulddie} = 1;
            my ( $ret, $msg ) = NginxHooks::_possible_php_fpm();
            is( $ret, 0 );
        };
    };

    describe "_doit" => sub {
        share my %mi;
        around {
            %mi = %conf;

            local $mi{mocks} = {};

            $mi{mocks}->{phpfpm_config} = Test::MockModule->new('Cpanel::PHPFPM::Config');
            $mi{mocks}->{phpfpm_config}->redefine(
                get_default_accounts_to_fpm => sub {
                    return 1;
                }
            );

            $mi{mocks}->{servertasks}           = Test::MockModule->new('Cpanel::ServerTasks');
            $mi{mocks}->{servertasks_tasks}     = [];
            $mi{mocks}->{servertasks_shoulddie} = 0;
            $mi{mocks}->{servertasks}->redefine(
                schedule_task => sub {
                    my ( $ar, $time_to_wait, $task ) = @_;
                    my $str = join( ',', @{$ar}, $time_to_wait, $task );
                    push( @{ $mi{mocks}->{servertasks_tasks} }, $str );
                    die "a horrible death" if ( $mi{mocks}->{servertasks_shoulddie} );
                    return;
                }
            );

            yield;
        };

        it "should do the thing if happy path" => sub {
            my ( $ret, $msg ) = NginxHooks::_possible_php_fpm();
            my $expected_ar = ["NginxTasks,$delay_time,rebuild_config"];

            is_deeply( $mi{mocks}->{servertasks_tasks}, $expected_ar );
        };

        it "should return success on happy path" => sub {
            my ( $ret, $msg ) = NginxHooks::_possible_php_fpm();
            is( $ret, 1 );
        };

        it "should return failure if scheduler fails" => sub {
            $mi{mocks}->{servertasks_shoulddie} = 1;
            my ( $ret, $msg ) = NginxHooks::_possible_php_fpm();
            is( $ret, 0 );
        };
    };

    describe "_do_adminbin" => sub {
        share my %mi;
        around {
            %mi = %conf;

            local $mi{mocks} = {};

            $mi{mocks}->{adminbin_tasks} = [];
            $mi{mocks}->{adminbin}       = Test::MockModule->new('Cpanel::AdminBin::Call');
            $mi{mocks}->{adminbin}->redefine(
                call => sub {
                    push( @{ $mi{mocks}->{adminbin_tasks} }, join( ',', @_ ) );
                    return 1;
                }
            );

            yield;
        };

        it "should call adminbin" => sub {
            NginxHooks::_do_adminbin();
            my $expected_ar = ['Cpanel,nginx,UPDATE_CONFIG'];

            is_deeply( $mi{mocks}->{adminbin_tasks}, $expected_ar );
        };
    };

    describe "_do_wordpress" => sub {
        share my %mi;
        around {
            %mi = %conf;

            local $mi{mocks} = {};

            $mi{mocks}->{adminbin_tasks} = [];
            $mi{mocks}->{adminbin}       = Test::MockModule->new('Cpanel::AdminBin::Call');
            $mi{mocks}->{adminbin}->redefine(
                call => sub {
                    push( @{ $mi{mocks}->{adminbin_tasks} }, join( ',', @_ ) );
                    return 1;
                }
            );

            yield;
        };

        it "should call adminbin" => sub {
            NginxHooks::_do_wordpress(
                {
                    'category'      => 'Cpanel',
                    'point'         => 'main',
                    'event'         => 'Api1::cPAddons::mainpg',
                    'stage'         => 'post',
                    'escalateprivs' => 1
                },
                {
                    'args' => [
                        {
                            'addon'    => 'cPanel::Blogs::WordPressX',
                            'view'     => 'install',
                            'oneclick' => '1'
                        }
                    ],
                    'user'   => 'cptest1',
                    'output' => []
                }
            );

            my $expected_ar = ['Cpanel,nginx,UPDATE_CONFIG'];

            is_deeply( $mi{mocks}->{adminbin_tasks}, $expected_ar );
        };

        it "should NOT call adminbin" => sub {
            NginxHooks::_do_wordpress(
                {
                    'category'      => 'Cpanel',
                    'point'         => 'main',
                    'event'         => 'Api1::cPAddons::mainpg',
                    'stage'         => 'post',
                    'escalateprivs' => 1
                },
                {
                    'args' => [
                        {
                            'addon'    => 'cPanel::Blogs::SomethingElse',
                            'view'     => 'install',
                            'oneclick' => '1'
                        }
                    ],
                    'user'   => 'cptest1',
                    'output' => []
                }
            );

            my $expected_ar = [];

            is_deeply( $mi{mocks}->{adminbin_tasks}, $expected_ar );
        };
    };

    describe "just_clear_cache" => sub {
        share my %mi;
        around {
            %mi = %conf;

            local $mi{mocks} = {};

            $mi{mocks}->{servertasks}           = Test::MockModule->new('Cpanel::ServerTasks');
            $mi{mocks}->{servertasks_tasks}     = [];
            $mi{mocks}->{servertasks_shoulddie} = 0;
            $mi{mocks}->{servertasks}->redefine(
                schedule_task => sub {
                    my ( $ar, $time_to_wait, $task ) = @_;
                    my $str = join( ',', @{$ar}, $time_to_wait, $task );
                    push( @{ $mi{mocks}->{servertasks_tasks} }, $str );
                    die "a horrible death" if ( $mi{mocks}->{servertasks_shoulddie} );
                    return;
                }
            );

            yield;
        };

        it "should schedule a clear_cache" => sub {
            my $hook  = { event => 'Accounts::suspendacct' };
            my $event = { args  => { user => 'rickybobby' } };

            my ( $ret, $msg ) = NginxHooks::_just_clear_user_cache( $hook, $event );

            my $expected_ar = [
                'NginxTasks,2,clear_user_cache rickybobby',
            ];

            is_deeply( $mi{mocks}->{servertasks_tasks}, $expected_ar );
        };

        it "should schedule a clear_cache" => sub {
            my $hook  = { event => 'Accounts::unsuspendacct' };
            my $event = { args  => { user => 'rickybobby' } };

            my ( $ret, $msg ) = NginxHooks::_just_clear_user_cache( $hook, $event );

            my $expected_ar = [
                'NginxTasks,2,clear_user_cache rickybobby',
            ];

            is_deeply( $mi{mocks}->{servertasks_tasks}, $expected_ar );
        };
    };

    describe "rebuild_user" => sub {
        share my %mi;
        around {
            %mi = %conf;

            local $mi{mocks} = {};
            @log_output   = ();
            $system_calls = [];

            $mi{mocks}->{logger} = test::logger->new();

            yield;
        };

        it "should call script to configure user" => sub {
            NginxHooks::rebuild_user('billthecat');
            my $expected = [
                [
                    '/usr/local/cpanel/scripts/ea-nginx',
                    'config',
                    'billthecat'
                ]
            ];

            is_deeply( $system_calls, $expected );
        };

        it "should not log when logger undef" => sub {
            NginxHooks::rebuild_user('billthecat');
            is_deeply( \@log_output, [] );
        };

        it "should log when logger is passed" => sub {
            NginxHooks::rebuild_user( 'billthecat', $mi{mocks}->{logger} );
            is_deeply( \@log_output, ['rebuild_user :billthecat:'] );
        };

        it "should call rebuild_config if no user passed" => sub {
            NginxHooks::rebuild_user();
            my $expected = [
                [
                    '/usr/local/cpanel/scripts/ea-nginx',
                    'config',
                    '--all'
                ]
            ];

            is_deeply( $system_calls, $expected );
        };
    };

    describe "rebuild_config" => sub {
        share my %mi;
        around {
            %mi = %conf;

            local $mi{mocks} = {};
            @log_output   = ();
            $system_calls = [];

            $mi{mocks}->{logger} = test::logger->new();

            yield;
        };

        it "should call script to configure user" => sub {
            NginxHooks::rebuild_config();
            my $expected = [
                [
                    '/usr/local/cpanel/scripts/ea-nginx',
                    'config',
                    '--all'
                ]
            ];

            is_deeply( $system_calls, $expected );
        };

        it "should log when logger is passed" => sub {
            NginxHooks::rebuild_config( $mi{mocks}->{logger} );
            is_deeply( \@log_output, ['rebuild_config'] );
        };
    };
};

runtests unless caller;

