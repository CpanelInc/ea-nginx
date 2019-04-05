#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/Cpanel-ServiceManager-Services-Nginx.t
#                                                  Copyright 2019 cPanel, L.L.C.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

## no critic qw(TestingAndDebugging::RequireUseStrict TestingAndDebugging::RequireUseWarnings)
use Test::Spec;    # automatically turns on strict and warnings

use FindBin;
use File::Glob ();

my %conf = (
    require => "$FindBin::Bin/../SOURCES/Nginx.pm",
    package => "Cpanel::ServiceManager::Services::Nginx",
);

require $conf{'require'};

use Test::MockFile ();
use Test::MockModule ();

no warnings qw(redefine once);

my @saferun_results;

describe "Basics On C6" => sub {
    describe "`_init`" => sub {
        share my %shared;

        around {
            my $mock_service_file = Test::MockFile->file( $Cpanel::ServiceManager::Services::Nginx::service_file); # is missing
            my $initd_file        = Test::MockFile->file( $Cpanel::ServiceManager::Services::Nginx::initd_file, "contents");

            $Cpanel::ServiceManager::Services::Nginx::_initted     = 0;
            $Cpanel::ServiceManager::Services::Nginx::is_systemctl = 0;

            $shared{'saferun_results'} = [];

            my $saferun = Test::MockModule->new ('Cpanel::SafeRun::Simple');
            $saferun->redefine ('saferun', sub {
                my (@args) = @_;
                push (@{$shared{'saferun_results'}}, join (',', @args));
            });

            yield;
        };

        it "on C6 is_systemctl = 0" => sub {
            Cpanel::ServiceManager::Services::Nginx::_init ();
            is ($Cpanel::ServiceManager::Services::Nginx::is_systemctl, 0, "_init: Properly identified as C6");
        };

        it "on C6 init set" => sub {
            Cpanel::ServiceManager::Services::Nginx::_init ();
            is ($Cpanel::ServiceManager::Services::Nginx::_initted,     1, "_init: Initted");
        };

        it "on C6 stop calls saferun once, and it's init.d" => sub {
            Cpanel::ServiceManager::Services::Nginx::stop ();
            is ($Cpanel::ServiceManager::Services::Nginx::_initted, 1, "stop: Initted");
            is (@{$shared{'saferun_results'}}, 1, "stop: Saferun called once");
            is ($shared{'saferun_results'}->[0], '/etc/init.d/nginx,stop', "stop: Saferun is used to call init.d script");
        };

        it "on C6 start calls saferun once, and it's init.d" => sub {
            Cpanel::ServiceManager::Services::Nginx::start ();
            is ($Cpanel::ServiceManager::Services::Nginx::_initted, 1, "start: Initted");
            is (@{$shared{'saferun_results'}}, 1, "start: Saferun called once");
            is ($shared{'saferun_results'}->[0], '/etc/init.d/nginx,start', "start: Saferun is used to call init.d script");
        };

        it "on C6 restart calls saferun once, and it's init.d" => sub {
            Cpanel::ServiceManager::Services::Nginx::restart ();
            is ($Cpanel::ServiceManager::Services::Nginx::_initted, 1, "restart: Initted");
            is (@{$shared{'saferun_results'}}, 1, "restart: Saferun called once");
            is ($shared{'saferun_results'}->[0], '/etc/init.d/nginx,reload', "restart: Saferun is used to call init.d script");
        };

        it "on C6 support_reload" => sub {
            my $ret = Cpanel::ServiceManager::Services::Nginx::support_reload ();
            is ($ret, 1, "support_reload: Properly returns 1");
        };

        it "status: missing pid_file" => sub {
            my $pid_file = Test::MockFile->file( $Cpanel::ServiceManager::Services::Nginx::pid_file); # is missing

            my $ret = Cpanel::ServiceManager::Services::Nginx::status ();
            is ($Cpanel::ServiceManager::Services::Nginx::_initted, 1, "status: Initted");
            is ($ret, 3, "status: no pid file returns 3");
        };

        it "status: missing proc_file" => sub {
            my $pid_file = Test::MockFile->file( $Cpanel::ServiceManager::Services::Nginx::pid_file, "1234\n");
            my $proc_file = Test::MockFile->file( '/proc/1234/exe'); # missing

            my $ret = Cpanel::ServiceManager::Services::Nginx::status ();
            is ($Cpanel::ServiceManager::Services::Nginx::_initted, 1, "status: Initted");
            is ($ret, 3, "status: no proc file returns 3");
        };

        it "status: proc file exists and returns /usr/sbin/nginx" => sub {
            my $cwd = Test::MockModule->new ('Cwd');
            $cwd->redefine ('abs_path', sub {
                return '/usr/sbin/nginx';
            });

            my $pid_file = Test::MockFile->file( $Cpanel::ServiceManager::Services::Nginx::pid_file, "1234\n");
            my $proc_file = Test::MockFile->file( '/proc/1234/exe', '/usr/sbin/nginx');

            my $ret = Cpanel::ServiceManager::Services::Nginx::status ();
            is ($Cpanel::ServiceManager::Services::Nginx::_initted, 1, "status: Initted");
            is ($ret, 0, "status: we are running returns 0");
        };

        it "status: proc file exists and returns somethingelse" => sub {
            my $cwd = Test::MockModule->new ('Cwd');
            $cwd->redefine ('abs_path', sub {
                return 'somethingelse';
            });

            my $pid_file = Test::MockFile->file( $Cpanel::ServiceManager::Services::Nginx::pid_file, "1234\n");
            my $proc_file = Test::MockFile->file( '/proc/1234/exe', '/usr/sbin/nginx');

            my $ret = Cpanel::ServiceManager::Services::Nginx::status ();
            is ($Cpanel::ServiceManager::Services::Nginx::_initted, 1, "status: Initted");
            is ($ret, 3, "status: if its not our process returns 3");
        };
    };
};

describe "Basics On C7" => sub {
    describe "`_init`" => sub {
        share my %shared;

        around {
            my $mock_service_file = Test::MockFile->file( $Cpanel::ServiceManager::Services::Nginx::service_file, "contents");
            my $initd_file        = Test::MockFile->file( $Cpanel::ServiceManager::Services::Nginx::initd_file); # missing

            $Cpanel::ServiceManager::Services::Nginx::_initted     = 0;
            $Cpanel::ServiceManager::Services::Nginx::is_systemctl = 0;

            $shared{'saferun_results'} = [];

            my $saferun = Test::MockModule->new ('Cpanel::SafeRun::Simple');
            $saferun->redefine ('saferun', sub {
                my (@args) = @_;
                push (@{$shared{'saferun_results'}}, join (',', @args));
            });

            yield;
        };

        it "on C7 is_systemctl = 1" => sub {
            Cpanel::ServiceManager::Services::Nginx::_init ();
            is ($Cpanel::ServiceManager::Services::Nginx::is_systemctl, 1, "_init: Properly identified as C7");
        };

        it "on C7 init set" => sub {
            Cpanel::ServiceManager::Services::Nginx::_init ();
            is ($Cpanel::ServiceManager::Services::Nginx::_initted,     1, "_init: Initted");
        };

        it "on C7 stop calls saferun once, and it's systemctl" => sub {
            Cpanel::ServiceManager::Services::Nginx::stop ();
            is ($Cpanel::ServiceManager::Services::Nginx::_initted, 1, "stop: Initted");
            is (@{$shared{'saferun_results'}}, 1, "stop: Saferun called once");
            is ($shared{'saferun_results'}->[0], '/usr/bin/systemctl,stop,nginx', "stop: Saferun is used to call systemctl");
        };

        it "on C7 start calls saferun once, and it's systemctl" => sub {
            Cpanel::ServiceManager::Services::Nginx::start ();
            is ($Cpanel::ServiceManager::Services::Nginx::_initted, 1, "start: Initted");
            is (@{$shared{'saferun_results'}}, 1, "start: Saferun called once");
            is ($shared{'saferun_results'}->[0], '/usr/bin/systemctl,start,nginx', "start: Saferun is used to call systemctl");
        };

        it "on C7 restart calls saferun once, and it's init.d" => sub {
            Cpanel::ServiceManager::Services::Nginx::restart ();
            is ($Cpanel::ServiceManager::Services::Nginx::_initted, 1, "restart: Initted");
            is (@{$shared{'saferun_results'}}, 1, "restart: Saferun called once");
            is ($shared{'saferun_results'}->[0], '/usr/bin/systemctl,reload,nginx', "restart: Saferun is used to call systemctl");
        };

        it "on C7 support_reload" => sub {
            my $ret = Cpanel::ServiceManager::Services::Nginx::support_reload ();
            is ($ret, 1, "support_reload: Properly returns 1");
        };

        # the remainder of the tests are just duplicates and do not assert
        # useful assertions that are not already asserted.
    };
};
runtests unless caller;
