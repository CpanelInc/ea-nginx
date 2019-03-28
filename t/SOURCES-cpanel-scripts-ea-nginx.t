#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/SOURCES-cpanel-scripts-ea-nginx.t     Copyright 2019 cPanel, L.L.C.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

## no critic qw(TestingAndDebugging::RequireUseStrict TestingAndDebugging::RequireUseWarnings)
use Test::Spec;    # automatically turns on strict and warnings

use FindBin;
use File::Glob ();

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
    require => "$FindBin::Bin/../SOURCES/cpanel-scripts-ea-nginx",
    package => "scripts::ea_nginx",
);
require $conf{require};

spec_helper "/usr/local/cpanel/t/small/.spec_helpers/App-CmdDispatch_based_modulinos.pl";

use Test::MockFile ();

my ( @_write_user_conf, @_reload );
my $orig__write_user_conf = \&scripts::ea_nginx::_write_user_conf;
my $orig__reload          = \&scripts::ea_nginx::_reload;
no warnings "redefine";
*scripts::ea_nginx::_write_user_conf = sub { push @_write_user_conf, [@_] };
*scripts::ea_nginx::_reload          = sub { push @_reload,          [@_] };
use warnings "redefine";

shared_examples_for "any sub command that taks a cpanel user" => sub {
    share my %ti;

    it "should error out when not given a user" => sub {
        modulino_run_trap( $ti{cmd} );
        is $trap->die, "The user argument is missing.\n";
    };

    it "should error out when given undef user" => sub {
        modulino_run_trap( $ti{cmd}, undef );
        is $trap->die, "The user argument is missing.\n";
    };

    it "should error out when given empty user" => sub {
        modulino_run_trap( $ti{cmd}, "" );
        is $trap->die, "The user argument is missing.\n";
    };

    it "should error out when given non-existant user" => sub {
        modulino_run_trap( $ti{cmd}, "nonuser-$$" );
        is $trap->die, "The given user is not a cPanel user.\n";
    };

    it "should error out when given non-cpanel user" => sub {
        modulino_run_trap( $ti{cmd}, "nobody" );
        is $trap->die, "The given user is not a cPanel user.\n";
    };

    it "should allow cpanel user" => sub {
        modulino_run_trap( $ti{cmd}, "cpuser$$" );
        is $trap->die, undef;
    };
};

describe "en-nginx script" => sub {
    share my %mi;
    around {
        local $ENV{"scripts::ea_nginx::bail_die"} = 1;

        no warnings "redefine", "once";
        use warnings "redefine", "once";

        %mi = %conf;
        Cpanel::Config::LoadUserDomains->expects("loaduserdomains")->returns( { "cpuser$$" => [], "other$$" => [] } )->maybe;
        yield;
    };

    before each => sub { @{$system_calls} = (); @_write_user_conf = (); @_reload = (); };

    it_should_behave_like "all App::CmdDispatch modulino scripts";

    it_should_behave_like "all App::CmdDispatch scripts w/ help";

    describe "sub-command" => sub {
        describe "`config`" => sub {
            around {
                local $mi{cmd} = "config";
                local @glob_res = ();
                no warnings "redefine";
                local *File::Glob::bsd_glob = sub { return @glob_res };    # necessary because https://github.com/CpanelInc/Test-MockFile/issues/40
                yield;
            };
            it_should_behave_like "any sub command that taks a cpanel user";

            it "should create the config for the given user if needed" => sub {
                my $mock = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                modulino_run_trap( config => "cpuser$$" );
                ok -d $mock->filename;
                is_deeply \@_write_user_conf, [ ["cpuser$$"] ];
            };

            it "should create a config for all users given --all" => sub {
                my $mock = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                modulino_run_trap( config => "--all" );
                ok -d $mock->filename;
                is_deeply \@_write_user_conf, [ ["cpuser$$"], ["other$$"] ];
            };

            it "should delete no-longer existing users’ conf given --all" => sub {
                my $mock = Test::MockFile->dir( '/etc/nginx/conf.d/users/', ["iamnomore$$.conf"] );
                my $mockfile = Test::MockFile->file( "/etc/nginx/conf.d/users/iamnomore$$.conf", "i am conf hear me rawr" );
                local @glob_res = ("/etc/nginx/conf.d/users/iamnomore$$.conf");
                modulino_run_trap( config => "--all" );
                ok !-e $mockfile->filename;
            };

            it "should reload nginx (w/ new conf file) if --no-reload is not given (user)" => sub {
                my $mock     = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                my $mockfile = Test::MockFile->dir("/etc/nginx/conf.d/users/cpuser$$.conf");
                modulino_run_trap( config => "cpuser$$" );
                is_deeply \@_reload, [ [ $mockfile->filename ] ];
            };

            it "should not reload nginx if --no-reload is given (user)" => sub {
                my $mock     = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                my $mockfile = Test::MockFile->file("/etc/nginx/conf.d/users/cpuser$$.conf");
                modulino_run_trap( config => "cpuser$$", "--no-reload" );
                is_deeply \@_reload, [];
            };

            it "should reload nginx (w/ no conf file) if --no-reload is not given (--all)" => sub {
                my $mock       = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                my $mockfile_a = Test::MockFile->file("/etc/nginx/conf.d/users/cpuser$$.conf");
                my $mockfile_b = Test::MockFile->file("/etc/nginx/conf.d/users/other$$.conf");
                modulino_run_trap( config => "--all" );
                is_deeply \@_reload, [ [] ];
            };

            it "should not reload nginx if --no-reload is given (--all)" => sub {
                my $mock       = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                my $mockfile_a = Test::MockFile->file("/etc/nginx/conf.d/users/cpuser$$.conf");
                my $mockfile_b = Test::MockFile->file("/etc/nginx/conf.d/users/other$$.conf");
                modulino_run_trap( config => "--all", "--no-reload" );
                is_deeply \@_reload, [];
            };

            it "should have an alias `conf`" => sub {
                my $mock = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                modulino_run_trap( conf => "cpuser$$" );
                ok -d $mock->filename;
                is_deeply \@_write_user_conf, [ ["cpuser$$"] ];
            };
        };

        describe "`remove`" => sub {
            around {
                local $mi{cmd} = "remove";
                yield;
            };
            it_should_behave_like "any sub command that taks a cpanel user";

            it "should remove the file if it exists" => sub {
                my $mock = Test::MockFile->file( "/etc/nginx/conf.d/users/cpuser$$.conf", "# i am a config file" );
                modulino_run_trap( remove => "cpuser$$" );
                ok !-e $mock->filename;
            };

            it "should have a msg if it does not exist" => sub {
                my $mock = Test::MockFile->file("/etc/nginx/conf.d/users/cpuser$$.conf");
                modulino_run_trap( remove => "cpuser$$" );
                like $trap->stdout, qr{/etc/nginx/conf\.d/users/cpuser$$\.conf is already removed or never existed\.\n};
            };

            it "should reload after unlink" => sub {
                my $mock = Test::MockFile->file( "/etc/nginx/conf.d/users/cpuser$$.conf", "# i am a config file" );
                modulino_run_trap( remove => "cpuser$$" );
                is_deeply \@_reload, [ [] ];
            };

            it "should warn if user dir exists" => sub {
                my $mock = Test::MockFile->dir( "/etc/nginx/conf.d/users/cpuser$$/", [] );
                modulino_run_trap( remove => "cpuser$$" );
                like $trap->stderr, qr{Customization path /etc/nginx/conf.d/users/cpuser$$/ exists, you will need to manually move/remove/reconfigure that\.\n};
            };

            it "should msg if user dir does exist" => sub {
                my $mock = Test::MockFile->dir("/etc/nginx/conf.d/users/cpuser$$/");
                modulino_run_trap( remove => "cpuser$$" );
                like $trap->stdout, qr{Customization path /etc/nginx/conf.d/users/cpuser$$/ does not exist\. You are all set!\n};
            };

            it "should reload nginx if --no-reload is not given" => sub {
                my $mock = Test::MockFile->file( "/etc/nginx/conf.d/users/cpuser$$.conf", "# i am a config file" );
                modulino_run_trap( remove => "cpuser$$" );
                is_deeply \@_reload, [ [] ];
            };

            it "should not reload nginx if --no-reload is given" => sub {
                my $mock = Test::MockFile->file( "/etc/nginx/conf.d/users/cpuser$$.conf", "# i am a config file" );
                modulino_run_trap( remove => "cpuser$$", "--no-reload" );
                is_deeply \@_reload, [];
            };
        };

        describe "`reload`" => sub {
            around {
                no warnings "redefine";
                local *scripts::ea_nginx::_reload = $orig__reload;
                yield;
            };

            it "should reload nginx" => sub {
                modulino_run_trap("reload");
                is_deeply $system_calls, [ ['/usr/sbin/nginx -s reload'] ];
            };

            describe "\b, if reload fails, " => sub {
                it "should exit unclean" => sub {
                    local $system_rv = 1;
                    modulino_run_trap("reload");
                    is $trap->exit, 1;
                };

                describe "and internally was given a file" => sub {
                    around {
                        local $system_rv = 1;
                        no warnings "redefine";
                        local *scripts::ea_nginx::_reload = $orig__reload;
                        yield;
                    };

                    it "should try unlinking the given file" => sub {
                        my $mock = Test::MockFile->file( "/etc/nginx/conf.d/users/derp$$.conf", "oh hai" );
                        trap { scripts::ea_nginx::_reload( $mock->filename ) };
                        ok !-e $mock->filename;
                    };

                    it "should warn about unlinking the given file" => sub {
                        my $mock = Test::MockFile->file( "/etc/nginx/conf.d/users/derp$$.conf", "oh hai" );
                        trap { scripts::ea_nginx::_reload( $mock->filename ) };
                        is $trap->stderr, "Could not reload generated nginx config, removing and attempting reload without it: 1\n";
                    };

                    it "should restart again (exit unclean on success)" => sub {
                        my $mock = Test::MockFile->file( "/etc/nginx/conf.d/users/derp$$.conf", "oh hai" );
                        trap { scripts::ea_nginx::_reload( $mock->filename ) };
                        is_deeply $system_calls, [ ['/usr/sbin/nginx -s reload'], ['/usr/sbin/nginx -s reload'] ];
                        is $trap->exit, 1;
                    };

                    it "should restart again (exit clean on success)" => sub {
                        my $rv = 1;
                        local $current_system = sub { push @{$system_calls}, [@_]; $rv-- };
                        my $mock = Test::MockFile->file( "/etc/nginx/conf.d/users/derp$$.conf", "oh hai" );
                        trap { scripts::ea_nginx::_reload( $mock->filename ) };
                        is_deeply $system_calls, [ ['/usr/sbin/nginx -s reload'], ['/usr/sbin/nginx -s reload'] ];
                        is $trap->exit, undef;
                    };
                };
            };
        };
    };
};

runtests unless caller;
