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

my %conf = (
    require => "$FindBin::Bin/../SOURCES/nginx-adminbin",
    package => 'bin::admin::Cpanel::nginx',
);

require $conf{require};

my $hooks_module = '/var/cpanel/perl5/lib/NginxHooks.pm';

package NginxHooks {
    sub get_time_to_wait { return 5; }
};

our $non_hook_method_data;
my $meth_map;
shared_examples_for "all subcommand based methods" => sub {
    it "should call its subcommand correctly" => sub {
        my $meth = $meth_map->[0];
        bin::admin::Cpanel::nginx->new()->$meth();
        is_deeply $non_hook_method_data->{run}, [ $meth_map->[1] ];
    };

    it "should not do debug when debug is false" => sub {
        my $meth = $meth_map->[0];
        bin::admin::Cpanel::nginx->new()->$meth();
        is_deeply $non_hook_method_data->{debug}, [];
    };

    it "should do debug when debug is true" => sub {
        local $Cpanel::Debug::level = 1;
        my $meth = $meth_map->[0];
        bin::admin::Cpanel::nginx->new()->$meth();
        is_deeply $non_hook_method_data->{debug}, [ ["$meth_map->[0]() called"] ];
    };

    it "should behave properly depending on feature" => sub {
        my $meth        = $meth_map->[0];
        my $should_exit = $meth_map->[2];
        my $feat        = Test::MockModule->new("Cpanel")->redefine( hasfeature => sub { 0 } );
        trap { bin::admin::Cpanel::nginx->new()->$meth(); };
        $should_exit ? ok( $trap->exit ) : ok( !$trap->exit );
    };
};

describe "nginx-adminbin" => sub {
    describe "_actions" => sub {
        it "should UPDATE_CONFIG CLEAR_CACHE RESET_CACHE_CONFIG ENABLE_CACHE DISABLE_CACHE" => sub {
            my @ret = bin::admin::Cpanel::nginx::_actions();
            is_deeply \@ret, [qw(UPDATE_CONFIG CLEAR_CACHE RESET_CACHE_CONFIG ENABLE_CACHE DISABLE_CACHE)];
        };
    };

    describe "UPDATE_CONFIG" => sub {
        share my %mi;
        around {
            %mi = %conf;

            local $mi{mocks} = {};

            $mi{mocks}->{debug}     = Test::MockModule->new('Cpanel::Debug');
            $mi{mocks}->{debug_log} = [];
            $mi{mocks}->{debug}->redefine(
                log_info => sub {
                    push( @{ $mi{mocks}->{debug_log} }, @_ );
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

            $mi{mocks}->{call} = Test::MockModule->new('Cpanel::AdminBin::Script::Call');
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

            $mi{mocks}->{object} = bin::admin::Cpanel::nginx->new();

            yield;
        };

        it "should rebuild sideshow_bob" => sub {
          SKIP: {
                skip "hooks are actually installed on this system", 1 if -e $hooks_module;

                # unfortuntely, the hooks module cannot be mockfiled
                _output_nginx_hooks();

                $mi{mocks}->{object}->UPDATE_CONFIG();

                my $expected = ['NginxTasks,5,rebuild_user sideshow_bob'];

                is_deeply( $mi{mocks}->{servertasks_tasks}, $expected );

                unlink $hooks_module;
            }
        };

        it "should debug log with level" => sub {
          SKIP: {
                skip "hooks are actually installed on this system", 1 if -e $hooks_module;

                # unfortuntely, the hooks module cannot be mockfiled
                _output_nginx_hooks();

                local $Cpanel::Debug::level = 1;

                $mi{mocks}->{object}->UPDATE_CONFIG();

                my $expected = ['UPDATE_CONFIG() called'];

                is_deeply( $mi{mocks}->{debug_log}, $expected );

                unlink $hooks_module;
            }
        };
    };

    describe "non-hook method" => sub {
        around {
            local $non_hook_method_data = { debug => [], run => [] };
            local $Cpanel::Debug::level = 0;

            my $mk_cp = Test::MockModule->new('Cpanel')->redefine( initcp => sub { } );
            my $mk_cd = Test::MockModule->new('Cpanel::Debug')->redefine( log_info => sub { push @{ $non_hook_method_data->{debug} }, \@_ } );
            my $mk_gu = Test::MockModule->new('Cpanel::AdminBin::Script::Call')->redefine( get_caller_username => sub { "trex$$" } )->redefine( new => sub { bless {}, shift } );

            local $INC{"scripts/ea_nginx.pm"} = 1;
            my $mk_rn = Test::MockModule->new('scripts::ea_nginx')->redefine( run => sub { push @{ $non_hook_method_data->{run} }, \@_ } );
            yield;
        };

        describe "CLEAR_CACHE" => sub {
            before all => sub { $meth_map = [ "CLEAR_CACHE" => [ clear_cache => "trex$$" ], 0 ] };
            it_should_behave_like "all subcommand based methods";
        };

        describe "RESET_CACHE_CONFIG" => sub {
            before all => sub { $meth_map = [ "RESET_CACHE_CONFIG" => [ cache => "trex$$", '--reset' ], 1 ] };
            it_should_behave_like "all subcommand based methods";
        };

        describe "ENABLE_CACHE" => sub {
            before all => sub { $meth_map = [ "ENABLE_CACHE" => [ cache => "trex$$", '--enabled=1' ], 1 ] };
            it_should_behave_like "all subcommand based methods";
        };

        describe "DISABLE_CACHE" => sub {
            before all => sub { $meth_map = [ "DISABLE_CACHE" => [ cache => "trex$$", '--enabled=0' ], 1 ] };
            it_should_behave_like "all subcommand based methods";
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

