#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/SOURCES-cpanel-scripts-ea-nginx.t     Copyright 2019 cPanel, L.L.C.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

## no critic qw(TestingAndDebugging::RequireUseStrict TestingAndDebugging::RequireUseWarnings)
use Test::Spec;    # automatically turns on strict and warnings

use FindBin;

use Cpanel::ServerTasks ();
use Cpanel::Debug       ();

use Test::MockModule;
use Test::MockFile;

use File::Temp;
use Path::Tiny;

my %conf = (
    require => [
        "$FindBin::Bin/../SOURCES/NginxTasks.pm",
        "$FindBin::Bin/../SOURCES/cpanel-scripts-ea-nginx",
    ],
);

require $conf{require}->[0];
require $conf{require}->[1];

my $hooks_module = '/var/cpanel/perl5/lib/NginxHooks.pm';

package My::TestTask {

    sub new {
        my ($class) = @_;
        my $self = {};
        $self->{args} = [];
        return bless $self, $class;
    }

    sub clear_args {
        my ($self) = @_;
        $self->{args} = [];
        return;
    }

    sub add_args {
        my ( $self, @args ) = @_;
        push( @{ $self->{args} }, @args );
        return;
    }

    sub args {
        my ($self) = @_;
        return @{ $self->{args} };
    }
};

# recently, clear_cache parameters were changed and would have
# caused NginxTasks to fail but that was not evident from the
# unit tests.  This test is intended to be deeper and will catch
# issues with parameter changes.

describe "clear_user_cache" => sub {
    share my %mi;
    around {
        %mi = %conf;

        local $mi{mocks} = {};

        $mi{mocks}->{globs} = [];

        no warnings qw(redefine once);
        local *scripts::ea_nginx::_delete_glob = sub {
            my ($glob) = @_;
            push( @{ $mi{mocks}->{globs} }, $glob );
            return;
        };

        local $Cpanel::TaskProcessors::NginxTasks::clear_user_cache::ea_nginx_script = "$FindBin::Bin/../SOURCES/cpanel-scripts-ea-nginx";

        $mi{mocks}->{object} = Cpanel::TaskProcessors::NginxTasks::clear_user_cache->new();
        $mi{mocks}->{task}   = My::TestTask->new();

        yield;
    };

    describe "_do_child_task" => sub {
        it "should call clear_cache with one user" => sub {
          SKIP: {
                skip "hooks are actually installed on this system", 1 if -e $hooks_module;

                $mi{mocks}->{task}->add_args('ricky_bobby');
                $mi{mocks}->{object}->_do_child_task( $mi{mocks}->{task}, "logger" );

                is( @{ $mi{mocks}->{globs} }, 1 );
            }
        };

        it "should call clear_cache with the correct user" => sub {
          SKIP: {
                skip "hooks are actually installed on this system", 1 if -e $hooks_module;

                $mi{mocks}->{task}->add_args('ricky_bobby');
                $mi{mocks}->{object}->_do_child_task( $mi{mocks}->{task}, "logger" );

                is( $mi{mocks}->{globs}->[0], '/var/cache/ea-nginx/*/ricky_bobby/*' );
            }
        };
    };
};

runtests unless caller;

