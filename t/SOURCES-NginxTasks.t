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
    require => "$FindBin::Bin/../SOURCES/NginxTasks.pm",
);

require $conf{require};

my $hooks_module = '/var/cpanel/perl5/lib/NginxHooks.pm';

my @access;

package NginxHooks {
    my $should_die = 0;

    sub set_should_die {
        my ($val) = @_;
        $should_die = $val;
        return;
    }

    sub rebuild_user {
        my ( $user, $logger ) = @_;
        die "rebuild_user" if $should_die;
        push( @access, "rebuild_user :$user:" );
        return;
    }

    sub rebuild_config {
        my ($logger) = @_;
        die "rebuild_config" if $should_die;
        push( @access, "rebuild_config" );
        return;
    }
};

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

describe "rebuild user" => sub {
    share my %mi;
    around {
        %mi = %conf;

        local $mi{mocks} = {};

        @access              = ();
        $mi{mocks}->{object} = Cpanel::TaskProcessors::NginxTasks::rebuild_user->new();
        $mi{mocks}->{task}   = My::TestTask->new();

        NginxHooks::set_should_die(0);

        yield;
    };

    describe "_do_child_task" => sub {
        it "should make one call into NginxHooks::rebuild_user" => sub {
          SKIP: {
                skip "hooks are actually installed on this system", 1 if -e $hooks_module;

                # unfortuntely, the hooks module cannot be mockfiled
                _output_nginx_hooks();

                $mi{mocks}->{task}->add_args('ricky_bobby');
                $mi{mocks}->{object}->_do_child_task( $mi{mocks}->{task}, "logger" );

                is( @access, 1 );

                unlink $hooks_module;
            }
        };

        it "should make one call to rebuild_user with arg ricky_bobby" => sub {
          SKIP: {
                skip "hooks are actually installed on this system", 1 if -e $hooks_module;

                # unfortuntely, the hooks module cannot be mockfiled
                _output_nginx_hooks();

                $mi{mocks}->{task}->add_args('ricky_bobby');
                $mi{mocks}->{object}->_do_child_task( $mi{mocks}->{task}, "logger" );

                is( $access[0], 'rebuild_user :ricky_bobby:' );

                unlink $hooks_module;
            }
        };

        it "should trap a die" => sub {
          SKIP: {
                skip "hooks are actually installed on this system", 1 if -e $hooks_module;

                # unfortuntely, the hooks module cannot be mockfiled
                _output_nginx_hooks();

                $mi{mocks}->{task}->add_args('ricky_bobby');

                NginxHooks::set_should_die(1);

                trap {
                    $mi{mocks}->{object}->_do_child_task( $mi{mocks}->{task}, "logger" );
                };

                like $trap->stderr, qr/NginxTasks::rebuild_user: \(ricky_bobby\) rebuild_user at/i;

                unlink $hooks_module;
            }
        };
    };

    describe "is_valid_args" => sub {
        it "should return false when there are no args" => sub {
            ok( !$mi{mocks}->{object}->is_valid_args( $mi{mocks}->{task} ) );
        };

        it "should return false when there are more than one arg" => sub {
            $mi{mocks}->{task}->add_args( "howdy", "all" );
            ok( !$mi{mocks}->{object}->is_valid_args( $mi{mocks}->{task} ) );
        };

        it "should return true when there is only one arg" => sub {
            $mi{mocks}->{task}->add_args("ricky_bobby");
            ok( $mi{mocks}->{object}->is_valid_args( $mi{mocks}->{task} ) );
        };
    };
};

describe "rebuild config" => sub {
    share my %mi;
    around {
        %mi = %conf;

        local $mi{mocks} = {};

        @access              = ();
        $mi{mocks}->{object} = Cpanel::TaskProcessors::NginxTasks::rebuild_config->new();
        $mi{mocks}->{task}   = My::TestTask->new();

        NginxHooks::set_should_die(0);

        yield;
    };

    describe "_do_child_task" => sub {
        it "should make one call into NginxHooks::rebuild_config" => sub {
          SKIP: {
                skip "hooks are actually installed on this system", 1 if -e $hooks_module;

                # unfortuntely, the hooks module cannot be mockfiled
                _output_nginx_hooks();

                $mi{mocks}->{object}->_do_child_task( $mi{mocks}->{task}, "logger" );

                is( @access, 1 );

                unlink $hooks_module;
            }
        };

        it "should make one call to rebuild_config" => sub {
          SKIP: {
                skip "hooks are actually installed on this system", 1 if -e $hooks_module;

                # unfortuntely, the hooks module cannot be mockfiled
                _output_nginx_hooks();

                $mi{mocks}->{object}->_do_child_task( $mi{mocks}->{task}, "logger" );

                is( $access[0], 'rebuild_config' );

                unlink $hooks_module;
            }
        };

        it "should trap a die" => sub {
          SKIP: {
                skip "hooks are actually installed on this system", 1 if -e $hooks_module;

                # unfortuntely, the hooks module cannot be mockfiled
                _output_nginx_hooks();

                NginxHooks::set_should_die(1);

                trap {
                    $mi{mocks}->{object}->_do_child_task( $mi{mocks}->{task}, "logger" );
                };

                like $trap->stderr, qr/NginxTasks::rebuild_config: rebuild_config at/i;

                unlink $hooks_module;
            }
        };
    };

    describe "is_valid_args" => sub {
        it "should return true when there are no args" => sub {
            ok( $mi{mocks}->{object}->is_valid_args( $mi{mocks}->{task} ) );
        };

        it "should return false when there are any args" => sub {
            $mi{mocks}->{task}->add_args( "howdy", "all" );
            ok( !$mi{mocks}->{object}->is_valid_args( $mi{mocks}->{task} ) );
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

};

    close $fh;
    return;
}

describe "to_register" => sub {
    it "should an array ref as we expect" => sub {
        my @array = Cpanel::TaskProcessors::NginxTasks::to_register();

        foreach my $record (@array) {
            $record->[1] = ref( $record->[1] );
        }

        my $expected = [
            [
                'rebuild_user',
                'Cpanel::TaskProcessors::NginxTasks::rebuild_user'
            ],
            [
                'rebuild_config',
                'Cpanel::TaskProcessors::NginxTasks::rebuild_config'
            ],
            [
                'rebuild_global',
                'Cpanel::TaskProcessors::NginxTasks::rebuild_global'
            ],

        ];

        is_deeply( \@array, $expected );
    };
};

runtests unless caller;

