#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/SOURCES-cpanel-scripts-ea-nginx.t     Copyright 2019 cPanel, L.L.C.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

## no critic qw(TestingAndDebugging::RequireUseStrict TestingAndDebugging::RequireUseWarnings)
use Test::Spec;    # automatically turns on strict and warnings

use FindBin;

use Cpanel::ServerTasks    ();
use Cpanel::Debug          ();

use Test::MockModule;
use Test::MockFile;

my %conf = (
    require => "$FindBin::Bin/../SOURCES/nginx-adminbin",
    package => 'bin::admin::Cpanel::nginx',
);

require $conf{require};

my $hooks_module = '/var/cpanel/perl5/lib/NginxHooks.pm';

package NginxHooks {
    sub get_time_to_wait { return 5; }
};

describe "nginx-adminbin" => sub {
    describe "_actions" => sub {
        it "should UPDATE_CONFIG" => sub {
            my $ret = bin::admin::Cpanel::nginx::_actions ();
            is( $ret, 'UPDATE_CONFIG' );
        };
    };

    describe "UPDATE_CONFIG" => sub {
        share my %mi;
        around {
            %mi = %conf;

            local $mi{mocks} = {};

            $mi{mocks}->{debug}                = Test::MockModule->new('Cpanel::Debug');
            $mi{mocks}->{debug_log}            = [];
            $mi{mocks}->{debug}->redefine(
                log_info => sub {
                    push (@{ $mi{mocks}->{debug_log} }, @_);
                    return;
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

            $mi{mocks}->{call}                 = Test::MockModule->new('Cpanel::AdminBin::Script::Call');
            $mi{mocks}->{call}->redefine(
                get_caller_username => sub {
                    return 'sideshow_bob';
                },
                new => sub {
                    my ($class) = @_;
                    my $self = {};
                    return bless $self, $class;
                }
            );

            $mi{mocks}->{object} = bin::admin::Cpanel::nginx->new ();

            yield;
        };

        it "should rebuild sideshow_bob" => sub {
            SKIP: {
                skip "hooks are actually installed on this system", 1 if -e $hooks_module;

                # unfortuntely, the hooks module cannot be mockfiled
                _output_nginx_hooks ();

                $mi{mocks}->{object}->UPDATE_CONFIG ();

                my $expected = [
                    'NginxTasks,5,rebuild_user sideshow_bob'
                ];

                is_deeply ($mi{mocks}->{servertasks_tasks}, $expected);

                unlink $hooks_module;
            };
        };

        it "should debug log with level" => sub {
            SKIP: {
                skip "hooks are actually installed on this system", 1 if -e $hooks_module;

                # unfortuntely, the hooks module cannot be mockfiled
                _output_nginx_hooks ();

                local $Cpanel::Debug::level = 1;

                $mi{mocks}->{object}->UPDATE_CONFIG ();

                my $expected = [
                    'UPDATE_CONFIG: called'
                ];

                is_deeply ($mi{mocks}->{debug_log}, $expected);

                unlink $hooks_module;
            };
        };
    };

};

# ug cannot mockfile the perl module, sorry
sub _output_nginx_hooks {
    system 'mkdir -p /var/cpanel/perl5/lib';
    open my $fh, '>', $hooks_module or die "Cannot create hooks :$!:";
    print $fh q{
package of::no::consequence;

sub dontcare {
    return;
}

1;

__END__
};

    close $fh;
    return;
}

runtests unless caller;

