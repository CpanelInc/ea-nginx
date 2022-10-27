#!/usr/local/cpanel/3rdparty/bin/perl
# cpanel - t/SOURCES-cpanel-scripts-ea-nginx.t     Copyright 2022 cPanel, L.L.C.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

## no critic qw(TestingAndDebugging::RequireUseStrict TestingAndDebugging::RequireUseWarnings)
use Test::Spec;    # automatically turns on strict and warnings
use Test::FailWarnings;

use FindBin;
use File::Glob ();

use File::Temp;
use Path::Tiny;

use Cpanel::Config::userdata::Load         ();
use Cpanel::ConfigFiles::Apache::Config    ();
use Cpanel::Config::LoadUserDomains::Count ();

our $system_calls   = [];
our $system_rv      = 0;
our $current_system = sub {
    push @{$system_calls}, [@_];
    $? = $system_rv;
    return $system_rv;
};
use Test::Mock::Cmd 'system' => sub { $current_system->(@_) };

our @glob_res;
our $userdata;
our $cpanel_redirects;
our @redirect_results;

my %conf = (
    require => "$FindBin::Bin/../SOURCES/cpanel-scripts-ea-nginx",
    package => "scripts::ea_nginx",
);
require $conf{require};

spec_helper "/usr/local/cpanel/t/small/.spec_helpers/App-CmdDispatch_based_modulinos.pl";

use App::CmdDispatch ();
use Test::MockModule ();

use Test::MockFile qw< nostrict >;

use Test::Fatal qw( dies_ok lives_ok );

my ( @_write_user_conf, @_reload, @clear_cache );
my $orig__write_user_conf           = \&scripts::ea_nginx::_write_user_conf;
my $orig__reload                    = \&scripts::ea_nginx::_reload;
my $orig_clear_cache                = \&scripts::ea_nginx::clear_cache;
my $orig__do_other_global_config    = \&scripts::ea_nginx::_do_other_global_config;
my $orig__update_for_custom_configs = \&scripts::ea_nginx::_update_for_custom_configs;
my $orig__write_global_logging      = \&scripts::ea_nginx::_write_global_logging;
my $orig__write_global_passenger    = \&scripts::ea_nginx::_write_global_passenger;
my $orig__get_global_config_data    = \&scripts::ea_nginx::_get_global_config_data;

no warnings "redefine";
*scripts::ea_nginx::_write_user_conf           = sub { push @_write_user_conf, [ $_[0] ] };
*scripts::ea_nginx::_do_other_global_config    = sub { };
*scripts::ea_nginx::_reload                    = sub { push @_reload,     [@_] };
*scripts::ea_nginx::clear_cache                = sub { push @clear_cache, [@_] };
*scripts::ea_nginx::_update_for_custom_configs = sub { };
*scripts::ea_nginx::_write_global_logging      = sub { };
*scripts::ea_nginx::_write_global_passenger    = sub { };
*scripts::ea_nginx::_get_global_config_data    = sub { return {}; };
use warnings "redefine";

our $cpanel_json_loadfiles_string = "";

shared_examples_for "any circular redirect" => sub {
    share my %ti;

    it "should skip with no trailing slash" => sub {
        local $cpanel_redirects->[0]{targeturl} = "$ti{protocol}dan.test";
        my $res = trap { scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects ) };
        is_deeply $res, [];
    };

    it "should skip with no trailing slash and anchor" => sub {
        local $cpanel_redirects->[0]{targeturl} = "$ti{protocol}dan.test#foo";
        my $res = trap { scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects ) };
        is_deeply $res, [];
    };

    it "should skip with no trailing slash and query string" => sub {
        local $cpanel_redirects->[0]{targeturl} = "$ti{protocol}dan.test?foo=bar";
        my $res = trap { scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects ) };
        is_deeply $res, [];
    };

    it "should skip with trailing slash" => sub {
        local $cpanel_redirects->[0]{targeturl} = "$ti{protocol}dan.test/";
        my $res = trap { scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects ) };
        is_deeply $res, [];
    };

    it "should skip with trailing slash and anchor" => sub {
        local $cpanel_redirects->[0]{targeturl} = "$ti{protocol}dan.test/#foo";
        my $res = trap { scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects ) };
        is_deeply $res, [];
    };

    it "should skip with trailing slash and query string" => sub {
        local $cpanel_redirects->[0]{targeturl} = "$ti{protocol}dan.test/?foo=bar";
        my $res = trap { scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects ) };
        is_deeply $res, [];
    };

    it "should skip with trailing slash and URI" => sub {
        local $cpanel_redirects->[0]{targeturl} = "$ti{protocol}dan.test/foo";
        my $res = trap { scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects ) };
        is_deeply $res, [];
    };
};

shared_examples_for "any sub command that takes a cpanel user" => sub {
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

describe "ea-nginx script" => sub {
    share my %mi;
    around {
        no warnings "redefine", "once";
        local $ENV{"scripts::ea_nginx::bail_die"} = 1;
        use warnings "redefine", "once";

        %mi = %conf;
        Cpanel::Config::LoadUserDomains->expects("loaduserdomains")->returns( { "cpuser$$" => [], "other$$" => [] } )->maybe;
        yield;
    };

    before each => sub { @{$system_calls} = (); @_write_user_conf = (); @_reload = (); @clear_cache = (); };

    it_should_behave_like "all App::CmdDispatch modulino scripts";

    it_should_behave_like "all App::CmdDispatch scripts w/ help";

    describe "sub-command" => sub {
        describe "`config`" => sub {
            my $called_cpanel_fileguard      = 0;
            my $called_global_config_data    = 0;
            my $called_write_global_ea_nginx = 0;

            around {
                local $mi{cmd} = "config";
                local @glob_res = ();

                my $mock_lock_dir = Test::MockFile->dir('/var/cpanel/locks');

                no warnings "redefine";
                local *File::Glob::bsd_glob = sub { return @glob_res };    # necessary because https://github.com/CpanelInc/Test-MockFile/issues/40

                my $mock_cpanel_fileguard = Test::MockModule->new('Cpanel::FileGuard');
                $mock_cpanel_fileguard->redefine( new => sub { $called_cpanel_fileguard++; }, );

                local *scripts::ea_nginx::_write_global_cpanel_localhost     = sub { };
                local *scripts::ea_nginx::_write_global_nginx_conf           = sub { };
                local *scripts::ea_nginx::_write_global_default              = sub { };
                local *scripts::ea_nginx::_write_global_cpanel_proxy_non_ssl = sub { };
                local *scripts::ea_nginx::ensure_valid_nginx_config          = sub { };

                local *scripts::ea_nginx::_write_global_ea_nginx  = sub { $called_write_global_ea_nginx++ };
                local *scripts::ea_nginx::_get_global_config_data = sub { $called_global_config_data++; };

                yield;
            };

            before each => sub { $called_cpanel_fileguard = 0; $called_global_config_data = 0; $called_write_global_ea_nginx = 0; };

            it_should_behave_like "any sub command that takes a cpanel user";

            it 'should create aquire a lock via Cpanel::FileGuard before continuing' => sub {
                modulino_run_trap( config => "--all", "--serial" );
                is( $called_cpanel_fileguard, 1 );
            };

            it 'should call _update_user_configs_in_serial_mode() when give the --all and --serial flags' => sub {
                no warnings 'redefine';
                my $called_serial = 0;
                local *scripts::ea_nginx::_update_user_configs_in_serial_mode = sub { $called_serial++; };
                use warnings 'redefine';

                modulino_run_trap( config => "--all", "--serial" );
                is( $called_serial, 1 );
            };

            it 'should call _update_user_configs_in_parallel_mode() when given the --all flag (default)' => sub {
                no warnings 'redefine';
                my $called_parallel = 0;
                local *scripts::ea_nginx::_update_user_configs_in_parallel_mode = sub { $called_parallel++; };
                use warnings 'redefine';

                modulino_run_trap( config => "--all" );
                is( $called_parallel, 1 );
            };

            it 'should update ea-nginx.conf if called for a single user' => sub {
                my $mock = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                modulino_run_trap( config => "cpuser$$", "--serial" );
                is( $called_write_global_ea_nginx, 1 );
            };

            it "should create the config for the given user if needed" => sub {
                my $mock = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                modulino_run_trap( config => "cpuser$$", "--serial" );
                ok -d $mock->path;
                is_deeply \@_write_user_conf, [ ["cpuser$$"] ] or diag explain \@_write_user_conf;
            };

            it "should create a config for all users given --all" => sub {
                my $mock = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                modulino_run_trap( config => "--all", "--serial" );
                ok -d $mock->path;
                is_deeply \@_write_user_conf, [ ["cpuser$$"], ["other$$"] ];
            };

            it "should delete no-longer existing users’ conf given --all" => sub {
                my $mock     = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                my $mockfile = Test::MockFile->file( "/etc/nginx/conf.d/users/iamnomore$$.conf", "i am conf hear me rawr" );
                local @glob_res = ("/etc/nginx/conf.d/users/iamnomore$$.conf");
                modulino_run_trap( config => "--all", "--serial" );
                ok !-e $mockfile->path();
            };

            it "should not do user config given --global" => sub {
                my $mock     = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                my $mockfile = Test::MockFile->file( "/etc/nginx/conf.d/users/iamnomore$$.conf", "i am conf hear me rawr" );
                modulino_run_trap( config => "--global", "--serial" );
                ok -e $mockfile->path();
            };

            it "should do /etc/nginx/ea-nginx/config-scripts/global/ given --global" => sub {
                my $mock     = Test::MockFile->dir('/etc/nginx/ea-nginx/config-scripts/global/');
                my $mockfile = Test::MockFile->file( "/etc/nginx/ea-nginx/config-scripts/global/$$.ima.script", "i am script hear me rawr", { mode => 0755 } );
                local @glob_res = ("/etc/nginx/ea-nginx/config-scripts/global/$$.ima.script");
                no warnings "redefine";
                local *scripts::ea_nginx::_do_other_global_config = $orig__do_other_global_config;
                modulino_run_trap( config => "--global", "--serial" );
                like $trap->stdout, qr{Running \(global\) “/etc/nginx/ea-nginx/config-scripts/global/$$\.ima\.script” …};
            };

            it "should do /etc/nginx/ea-nginx/config-scripts/global/ given --all" => sub {
                my $mock     = Test::MockFile->dir('/etc/nginx/ea-nginx/config-scripts/global/');
                my $mockfile = Test::MockFile->file( "/etc/nginx/ea-nginx/config-scripts/global/$$.ima.script", "i am script hear me rawr", { mode => 0755 } );
                local @glob_res = ("/etc/nginx/ea-nginx/config-scripts/global/$$.ima.script");
                no warnings "redefine";
                local *scripts::ea_nginx::_do_other_global_config = $orig__do_other_global_config;
                modulino_run_trap( config => "--all", "--serial" );
                like $trap->stdout, qr{Running \(global\) “/etc/nginx/ea-nginx/config-scripts/global/$$\.ima\.script” …};
            };

            it "should reload nginx (w/ new conf file) if --no-reload is not given (user)" => sub {
                my $mock     = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                my $mockfile = Test::MockFile->dir("/etc/nginx/conf.d/users/cpuser$$.conf");
                modulino_run_trap( config => "cpuser$$", "--serial" );
                is_deeply \@_reload, [ [ $mockfile->path() ] ];
            };

            it "should not reload nginx if --no-reload is given (user)" => sub {
                my $mock     = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                my $mockfile = Test::MockFile->file("/etc/nginx/conf.d/users/cpuser$$.conf");
                modulino_run_trap( config => "cpuser$$", "--no-reload", "--serial" );
                is_deeply \@_reload, [];
            };

            it "should reload nginx (w/ no conf file) if --no-reload is not given (--all)" => sub {
                my $mock       = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                my $mockfile_a = Test::MockFile->file("/etc/nginx/conf.d/users/cpuser$$.conf");
                my $mockfile_b = Test::MockFile->file("/etc/nginx/conf.d/users/other$$.conf");
                modulino_run_trap( config => "--all", "--serial" );
                is_deeply \@_reload, [ [] ];
            };

            it "should not reload nginx if --no-reload is given (--all)" => sub {
                my $mock       = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                my $mockfile_a = Test::MockFile->file("/etc/nginx/conf.d/users/cpuser$$.conf");
                my $mockfile_b = Test::MockFile->file("/etc/nginx/conf.d/users/other$$.conf");
                modulino_run_trap( config => "--all", "--no-reload", "--serial" );
                is_deeply \@_reload, [];
            };

            it "should clear_cache if --no-reload is not given (user)" => sub {
                my $mock     = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                my $mockfile = Test::MockFile->dir("/etc/nginx/conf.d/users/cpuser$$.conf");
                modulino_run_trap( config => "cpuser$$", "--serial" );
                is_deeply \@clear_cache, [ ["cpuser$$"] ];
            };

            it "should not clear_cache if --no-reload is given (user)" => sub {
                my $mock     = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                my $mockfile = Test::MockFile->file("/etc/nginx/conf.d/users/cpuser$$.conf");
                modulino_run_trap( config => "cpuser$$", "--no-reload", "--serial" );
                is_deeply \@clear_cache, [];
            };

            it "should clear_cache if --no-reload is not given (--all)" => sub {
                my $mock       = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                my $mockfile_a = Test::MockFile->file("/etc/nginx/conf.d/users/cpuser$$.conf");
                my $mockfile_b = Test::MockFile->file("/etc/nginx/conf.d/users/other$$.conf");
                modulino_run_trap( config => "--all", "--serial" );
                is_deeply \@clear_cache, [ [] ];
            };

            it "should not clear_cache if --no-reload is given (--all)" => sub {
                my $mock       = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                my $mockfile_a = Test::MockFile->file("/etc/nginx/conf.d/users/cpuser$$.conf");
                my $mockfile_b = Test::MockFile->file("/etc/nginx/conf.d/users/other$$.conf");
                modulino_run_trap( config => "--all", "--no-reload", "--serial" );
                is_deeply \@clear_cache, [];
            };

            it "should die if errors are found while updating user configs (--all)" => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_update_user_configs_in_parallel_mode = sub {
                    return { "cpuser$$" => "bad things happened" };
                };
                use warnings 'redefine';

                modulino_run_trap( config => "--all" );
                $trap->did_die();
            };

            it "should have an alias `conf`" => sub {
                my $mock = Test::MockFile->dir('/etc/nginx/conf.d/users/');
                modulino_run_trap( conf => "cpuser$$", "--serial" );
                ok -d $mock->path();
                is_deeply \@_write_user_conf, [ ["cpuser$$"] ];
            };

            it 'should call _get_global_config_data() when given the --all option' => sub {
                modulino_run_trap( config => "--all" );
                is( $called_global_config_data, 1 );
            };

            it 'should call _get_global_config_data() when given the a single user to process' => sub {
                modulino_run_trap( conf => "cpuser$$", "--serial" );
                is( $called_global_config_data, 1 );
            };

            describe "cPanel Password protected directories" => sub { it "is tested by smold4r -- nginx-standalone.t and nginx-reverse_proxy.t" };

            describe "cPanel Domains -" => sub {
                around {
                    no warnings "redefine";
                    local *Cpanel::Config::userdata::Load::load_userdata = sub { $userdata };
                    yield;
                };

                describe "Force HTTPS redirects" => sub {
                    it "should set `ssl_redirect` to true when enabled in userdata" => sub {
                        local $userdata                               = { ssl_redirect => 1 };
                        local %scripts::ea_nginx::load_userdata_cache = ();
                        ok scripts::ea_nginx::_get_ssl_redirect( "user$$" => ["foo$$.lol"] );
                    };

                    it "should set `ssl_redirect` to false when disabled in userdata" => sub {
                        local $userdata                               = { ssl_redirect => 0 };
                        local %scripts::ea_nginx::load_userdata_cache = ();
                        ok !scripts::ea_nginx::_get_ssl_redirect( "user$$" => ["foo$$.lol"] );
                    };

                    it "should set `ssl_redirect` to false when does not exist in userdata" => sub {
                        local $userdata                               = undef;
                        local %scripts::ea_nginx::load_userdata_cache = ();
                        ok !scripts::ea_nginx::_get_ssl_redirect( "user$$" => ["foo$$.lol"] );
                    };
                };

                describe "Disable Mod Security" => sub {
                    it "should set `secruleengineoff` to true when enabled in userdata" => sub {
                        local $userdata                               = { secruleengineoff => 1 };
                        local %scripts::ea_nginx::load_userdata_cache = ();
                        ok scripts::ea_nginx::_get_secruleengineoff( "user$$" => ["foo$$.lol"] );
                    };

                    it "should set `secruleengineoff` to false when disabled in userdata" => sub {
                        local $userdata                               = { secruleengineoff => 0 };
                        local %scripts::ea_nginx::load_userdata_cache = ();
                        ok !scripts::ea_nginx::_get_secruleengineoff( "user$$" => ["foo$$.lol"] );
                    };

                    it "should set `secruleengineoff` to false when does not exist in userdata" => sub {
                        local $userdata                               = undef;
                        local %scripts::ea_nginx::load_userdata_cache = ();
                        ok !scripts::ea_nginx::_get_secruleengineoff( "user$$" => ["foo$$.lol"] );
                    };
                };
            };

            describe "cPanel Redirects" => sub {
                around {
                    local $cpanel_redirects = [
                        {
                            docroot    => '/home/dantest/public_html',
                            domain     => '.*',
                            kind       => 'rewrite',
                            matchwww   => 1,
                            opts       => 'L',
                            sourceurl  => 'glob',
                            statuscode => '301',
                            targeturl  => 'https://cpanel.net/alldomains',
                            type       => 'permanent',
                            wildcard   => 0
                        },
                        {
                            docroot    => '/home/dantest/public_html',
                            domain     => 'dan.test',
                            kind       => 'rewrite',
                            matchwww   => 1,
                            opts       => 'L',
                            sourceurl  => '/index.html',
                            statuscode => '301',
                            targeturl  => 'https://cpanel.net/index',
                            type       => 'permanent',
                            wildcard   => 0
                        },
                        {
                            docroot    => '/home/dantest/public_html',
                            domain     => 'dan.test',
                            kind       => 'rewrite',
                            matchwww   => 1,
                            opts       => 'L',
                            sourceurl  => '/derp',
                            statuscode => '301',
                            targeturl  => 'http://this is not a good/url yo',
                            type       => 'permanent',
                            wildcard   => 0
                        },
                        {
                            docroot    => '/home/dantest/public_html',
                            domain     => 'dan.test',
                            kind       => 'rewrite',
                            matchwww   => 1,
                            opts       => 'L',
                            sourceurl  => '/foo',
                            statuscode => '302',
                            targeturl  => 'https://cpanel.net/302/Y',
                            type       => 'temporary',
                            wildcard   => 1
                        },
                        {
                            docroot    => '/home/dantest/public_html',
                            domain     => "$$.test",
                            kind       => 'rewrite',
                            matchwww   => 1,
                            opts       => 'L',
                            sourceurl  => '/foo',
                            statuscode => '302',
                            targeturl  => 'https://cpanel.net/302/X',
                            type       => 'temporary',
                            wildcard   => 1
                        },
                    ];
                    local @redirect_results = (
                        {
                            flag        => 'permanent',
                            regex       => '^glob$',
                            replacement => 'https://cpanel.net/alldomains'
                        },
                        {
                            'flag'        => 'permanent',
                            'regex'       => '^\\/index\\.html$',
                            'replacement' => 'https://www.youtube.com/watch?v=kr_CFydcBZc'
                        },
                        {
                            'flag'        => 'redirect',
                            'regex'       => '^\\/foo\\/?(.*)$',
                            'replacement' => 'https://cpanel.net/302/Y$1'
                        },
                        {
                            'flag'        => 'redirect',
                            'regex'       => '^\\/foo\\/?(.*)$',
                            'replacement' => 'https://cpanel.net/302/X$1'
                        },
                    );
                    yield;
                };

                it "should warn about invalid `targeturl`s" => sub {
                    my $res = trap { scripts::ea_nginx::_get_redirects( [ "dan.test", "$$.test" ], $cpanel_redirects ) };
                    is $trap->warn->[0], "Skipping invalid targeturl “http://this is not a good/url yo”\n";
                };

                it "should not include invalid `targeturl`s" => sub {
                    my $res = trap { scripts::ea_nginx::_get_redirects( [ "dan.test", "$$.test" ], $cpanel_redirects ) };
                    is_deeply [ grep /this is not a good/, map { $_->{replacement} } @{$res} ], [];
                };

                it "should always include '.*' redirects" => sub {
                    my $res = trap { scripts::ea_nginx::_get_redirects( ["$$.test"], $cpanel_redirects ) };
                    is $res->[0]{regex}, '^glob$';
                };

                it "should include, in addition to '.*', only the given domains’ redirects" => sub {
                    my $res = trap { scripts::ea_nginx::_get_redirects( ["$$.test"], $cpanel_redirects ) };
                    is_deeply $res, [ $redirect_results[0], $redirect_results[3] ];
                };

                it "should warn about `statuscode` that is not 301 or 302" => sub {
                    local $cpanel_redirects = [ { domain => "dan.test", statuscode => 418, targeturl => "teapot.test" } ];
                    my $res = trap { scripts::ea_nginx::_get_redirects( [ "dan.test", "$$.test" ], $cpanel_redirects ) };
                    is $trap->warn->[0], "Skipping non 301/302 redirect\n";
                };

                it "should not include `statuscode` that is not 301 or 302" => sub {
                    local $cpanel_redirects = [ { domain => "dan.test", statuscode => 418, targeturl => "teapot.test" } ];
                    my $res = trap { scripts::ea_nginx::_get_redirects( [ "dan.test", "$$.test" ], $cpanel_redirects ) };
                    is_deeply $res, [];
                };

                it "should have a `flag` of `permanent` for 301 `statuscode`" => sub {
                    local $cpanel_redirects = [ { domain => "dan.test", statuscode => 301, targeturl => "301.yo" } ];
                    my $res = trap { scripts::ea_nginx::_get_redirects( [ "dan.test", "$$.test" ], $cpanel_redirects ) };
                    is $res->[0]{flag}, "permanent";
                };

                it "should have a `flag` of `redirect` for 302 `statuscode`" => sub {
                    local $cpanel_redirects = [ { domain => "dan.test", statuscode => 302,, targeturl => "302.yo" } ];
                    my $res = trap { scripts::ea_nginx::_get_redirects( [ "dan.test", "$$.test" ], $cpanel_redirects ) };
                    is $res->[0]{flag}, "redirect";
                };

                describe "non-wildcard" => sub {
                    it "should escape `sourceurl` in `regex`" => sub {
                        my $res = trap { scripts::ea_nginx::_get_redirects( [ "dan.test", "$$.test" ], $cpanel_redirects ) };
                        is $res->[1]{regex}, $redirect_results[1]{regex};
                    };

                    it "should pass through `targeturl` to `replacement`" => sub {
                        my $res = trap { scripts::ea_nginx::_get_redirects( [ "dan.test", "$$.test" ], $cpanel_redirects ) };
                        is $res->[1]{replacement}, $cpanel_redirects->[1]{targeturl};
                    };
                };

                describe "wildcard" => sub {

                    # these should all be $redirect_results[2] but an is() test is not as specific
                    it "should escape `sourceurl` in `regex`" => sub {
                        my $res = trap { scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects ) };
                        like $res->[2]{regex}, qr{\\/foo};
                    };

                    it "should append URI capture to `sourceurl` in `regex` (trailing /)" => sub {
                        local $cpanel_redirects->[3]{sourceurl} = "$cpanel_redirects->[3]{sourceurl}/";
                        my $res = trap { scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects ) };
                        like $res->[2]{regex}, qr{foo\\/\?\(\.\*\)\$};
                    };

                    it "should append URI capture to `sourceurl` in `regex` (w/out trailing /)" => sub {
                        my $res = trap { scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects ) };
                        like $res->[2]{regex}, qr{foo\\/\?\(\.\*\)\$};
                    };

                    it "should append capture variable to `replacement`" => sub {
                        my $res = trap { scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects ) };
                        like $res->[2]{replacement}, qr/\$1$/;
                    };
                };

                describe "potential domain-is-target infinite loops" => sub {
                    around {
                        local $cpanel_redirects = [
                            {
                                domain     => "dan.test",
                                sourceurl  => "/",
                                targeturl  => "https://dan.test/",
                                statuscode => 301,
                            }
                        ];

                        yield;
                    };

                    it "should warn when skipping" => sub {
                        my $res = trap { scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects ) };
                        is $trap->warn->[0], "Skipping circular redirect for “dan.test” to “https://dan.test/”\n";
                    };

                    it "should not include the redirect when skipping" => sub {
                        my $res = trap { scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects ) };
                        is_deeply $res, [];
                    };

                    it "should skip non-www. version" => sub {
                        my $res = trap { scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects ) };
                        is_deeply $res, [];
                    };

                    it "should skip www. version" => sub {
                        local $cpanel_redirects->[0]{targeturl} = "https://www.dan.test/";
                        my $res = trap { scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects ) };
                        is_deeply $res, [];
                    };

                    it "should not skip if the domain matches another domain (before)" => sub {
                        local $cpanel_redirects->[0]{targeturl} = "https://dan.testermax/";
                        my $res = scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects );
                        is scalar( @{$res} ), 1;
                    };

                    it "should not skip if the domain matches another domain (middle)" => sub {
                        local $cpanel_redirects->[0]{targeturl} = "https://mynameisdan.testermax/";
                        my $res = scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects );
                        is scalar( @{$res} ), 1;
                    };

                    it "should not skip if the domain matches another domain (after)" => sub {
                        local $cpanel_redirects->[0]{targeturl} = "https://mynameisdan.test/";
                        my $res = scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects );
                        is scalar( @{$res} ), 1;
                    };

                    it "should not skip if the domain is part of another domain (before)" => sub {
                        local $cpanel_redirects->[0]{targeturl} = "https://dan.test.com/";
                        my $res = scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects );
                        is scalar( @{$res} ), 1;
                    };

                    it "should not skip if the domain is part of another domain (middle)" => sub {
                        local $cpanel_redirects->[0]{targeturl} = "https://yo.dan.test.com/";
                        my $res = scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects );
                        is scalar( @{$res} ), 1;
                    };

                    it "should not skip if the domain is part of another domain (after)" => sub {
                        local $cpanel_redirects->[0]{targeturl} = "https://yo.dan.test/";
                        my $res = scripts::ea_nginx::_get_redirects( ["dan.test"], $cpanel_redirects );
                        is scalar( @{$res} ), 1;
                    };

                    describe "- https" => sub {
                        around {
                            local $mi{protocol} = "https://";
                            yield;
                        };
                        it_should_behave_like "any circular redirect";
                    };

                    describe "- http" => sub {
                        around {
                            local $mi{protocol} = "http://";
                            yield;
                        };
                        it_should_behave_like "any circular redirect";
                    };

                    describe "- protocol relative" => sub {
                        around {
                            local $mi{protocol} = "//";
                            yield;
                        };
                        it_should_behave_like "any circular redirect";
                    };

                    describe "- arbitrary word-like protocol" => sub {
                        around {
                            local $mi{protocol} = "Alph4.Num3riC+plus_undy.dot-dash:colon//";
                            yield;
                        };
                        it_should_behave_like "any circular redirect";
                    };
                };
            };
        };

        describe "`remove`" => sub {
            around {
                local $mi{cmd} = "remove";

                no warnings 'redefine';
                local *scripts::ea_nginx::ensure_valid_nginx_config = sub { };
                yield;
            };

            before each => sub { @clear_cache = (); };

            it_should_behave_like "any sub command that takes a cpanel user";

            it "should remove the file if it exists" => sub {
                my $mock = Test::MockFile->file( "/etc/nginx/conf.d/users/cpuser$$.conf", "# i am a config file" );
                modulino_run_trap( remove => "cpuser$$" );
                ok !-e $mock->path();
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
                my $mock      = Test::MockFile->dir("/etc/nginx/conf.d/users/cpuser$$/");
                my $mock_file = Test::MockFile->file( "/etc/nginx/conf.d/users/cpuser$$/stuff.conf", "config stuff 42" );
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

            it "should clear_cache if --no-reload is not given" => sub {
                my $mock = Test::MockFile->file( "/etc/nginx/conf.d/users/cpuser$$.conf", "# i am a config file" );
                modulino_run_trap( remove => "cpuser$$" );
                is_deeply \@clear_cache, [ ["cpuser$$"] ];
            };

            it "should not reload nginx if --no-reload is given" => sub {
                my $mock = Test::MockFile->file( "/etc/nginx/conf.d/users/cpuser$$.conf", "# i am a config file" );
                modulino_run_trap( remove => "cpuser$$", "--no-reload" );
                is_deeply \@_reload, [];
            };

            it "should not clear_cache if --no-reload is given" => sub {
                my $mock = Test::MockFile->file( "/etc/nginx/conf.d/users/cpuser$$.conf", "# i am a config file" );
                modulino_run_trap( remove => "cpuser$$", "--no-reload" );
                is_deeply \@clear_cache, [];
            };
        };

        describe "`reload`" => sub {
            around {
                no warnings "redefine";
                local *scripts::ea_nginx::_reload                   = $orig__reload;
                local *scripts::ea_nginx::ensure_valid_nginx_config = sub { };
                yield;
            };

            it "should reload nginx" => sub {
                modulino_run_trap("reload");
                is_deeply $system_calls, [ ['/usr/local/cpanel/scripts/restartsrv_nginx reload'] ];
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
                        trap { scripts::ea_nginx::_reload( $mock->path ) };
                        ok !-e $mock->path();
                    };

                    it "should warn about unlinking the given file" => sub {
                        my $mock = Test::MockFile->file( "/etc/nginx/conf.d/users/derp$$.conf", "oh hai" );
                        trap { scripts::ea_nginx::_reload( $mock->path() ) };
                        is $trap->stderr, "Could not reload generated nginx config, removing and attempting reload without it: 1\n";
                    };

                    it "should restart again (exit unclean on success)" => sub {
                        my $mock = Test::MockFile->file( "/etc/nginx/conf.d/users/derp$$.conf", "oh hai" );
                        trap { scripts::ea_nginx::_reload( $mock->path ) };
                        is_deeply $system_calls, [ ['/usr/local/cpanel/scripts/restartsrv_nginx reload'], ['/usr/local/cpanel/scripts/restartsrv_nginx reload'] ];
                        is $trap->exit, 1;
                    };

                    it "should restart again (exit clean on success)" => sub {
                        my $rv = 1;
                        local $current_system = sub { push @{$system_calls}, [@_]; $rv-- };
                        my $mock = Test::MockFile->file( "/etc/nginx/conf.d/users/derp$$.conf", "oh hai" );
                        trap { scripts::ea_nginx::_reload( $mock->path ) };
                        is_deeply $system_calls, [ ['/usr/local/cpanel/scripts/restartsrv_nginx reload'], ['/usr/local/cpanel/scripts/restartsrv_nginx reload'] ];
                        is $trap->exit, undef;
                    };
                };
            };
        };
    };

    describe "caching_defaults()" => sub {
        it "should have hard coded defaults" => sub {
            my %conf = scripts::ea_nginx::caching_defaults();
            is_deeply \%conf, {
                enabled           => 1,
                logging           => 0,
                x_cache_header    => 0,
                zone_size         => "10m",
                inactive_time     => "60m",
                levels            => "1:2",
                proxy_cache_valid => {
                    "200 301 302" => "60m",
                    "404"         => "1m",
                },
                proxy_cache_use_stale         => "error timeout http_429 http_500 http_502 http_503 http_504",
                proxy_cache_background_update => "on",
                proxy_cache_revalidate        => "on",
                proxy_cache_min_uses          => 1,
                proxy_cache_lock              => "on",
            };
        };

        it "should matching data in global conf file" => sub {
            my %conf = scripts::ea_nginx::caching_defaults();
            my $file = Cpanel::JSON::LoadFile("$FindBin::Bin/../SOURCES/cpanel/ea-nginx/cache.json");

            for my $bool (qw(enabled logging x_cache_header proxy_cache_min_uses)) {
                $conf{$bool} = $conf{$bool} ? Cpanel::JSON::true : Cpanel::JSON::false;
                $file->{$bool} = $file->{$bool} ? Cpanel::JSON::true : Cpanel::JSON::false;
            }

            is_deeply \%conf, $file;
        };
    };

    describe "clear_cache_cmd" => sub {
        share my %ti;

        around {
            local $ti{users}              = ();
            local $ti{clear_cache_called} = 0;

            no warnings "redefine";
            local *scripts::ea_nginx::_validate_user_arg = sub { 1 };
            local *scripts::ea_nginx::clear_cache        = sub {
                my (@users) = @_;

                push( @{ $ti{users} }, @users );
                $ti{clear_cache_called}++;

                return;
            };

            yield;
        };

        it "should call clear_cache if no user passed" => sub {
            scripts::ea_nginx::clear_cache_cmd( {}, () );
            is( $ti{clear_cache_called}, 1 );
        };

        it "should call clear_cache with no users if no user passed" => sub {
            scripts::ea_nginx::clear_cache_cmd( {}, () );
            is( @{ $ti{users} }, 0 );
        };

        it "should call clear_cache with no users if --all passed" => sub {
            scripts::ea_nginx::clear_cache_cmd( {}, '--all' );
            is( @{ $ti{users} }, 0 );
        };

        it "should call clear_cache if --all passed" => sub {
            scripts::ea_nginx::clear_cache_cmd( {}, '--all' );
            is( $ti{clear_cache_called}, 1 );
        };

        it "should call clear_cache with 2 users if 2 users are passed" => sub {
            scripts::ea_nginx::clear_cache_cmd( {}, 'chucknorris', 'brucelee' );
            is( @{ $ti{users} }, 2 );
        };
    };

    describe "clear_cache" => sub {
        share my %ti;

        around {
            local $ti{globs}              = ();
            local $ti{delete_glob_called} = 0;

            no warnings "redefine";
            local *scripts::ea_nginx::clear_cache        = $orig_clear_cache;
            local *scripts::ea_nginx::_validate_user_arg = sub { 1 };
            local *scripts::ea_nginx::_delete_glob       = sub {
                my ($glob) = @_;

                push( @{ $ti{globs} }, $glob );
                $ti{delete_glob_called}++;

                return;
            };

            yield;
        };

        it "should call _delete_glob once if no user passed" => sub {
            scripts::ea_nginx::clear_cache();

            is( $ti{delete_glob_called}, 1 );
        };

        it "should call _delete_glob with correct glob when no user passed" => sub {
            scripts::ea_nginx::clear_cache();

            is( $ti{globs}->[0], '/var/cache/ea-nginx/*/*/*' );
        };

        it "should call _delete_glob twice when 2 users passed" => sub {
            scripts::ea_nginx::clear_cache( 'chucknorris', 'brucelee' );

            is( $ti{delete_glob_called}, 2 );
        };

        it "should call _delete_glob with correct globs when 2 users are passed" => sub {
            scripts::ea_nginx::clear_cache( 'chucknorris', 'brucelee' );

            cmp_deeply(
                $ti{globs},
                [
                    '/var/cache/ea-nginx/*/chucknorris/*',
                    '/var/cache/ea-nginx/*/brucelee/*',
                ]
            );
        };
    };

    describe "private routines" => sub {
        describe "_get_domains_with_ssls" => sub {
            around {
                no warnings "redefine";
                local *Cpanel::ConfigFiles::Apache::Config::get_httpd_vhosts_hash = sub {
                    return {
                        'domain.tld'     => {},
                        'domain.tld_SSL' => {},
                        'nossl.tld'      => {},
                        'ssl.tld_SSL'    => {},
                    };
                };

                yield;
            };

            it "should return a href" => sub {
                my $href = scripts::ea_nginx::_get_domains_with_ssls();
                ok( ref($href) eq 'HASH' );
            };

            it "should return domain.tld as a key based on the mocking" => sub {
                my $href = scripts::ea_nginx::_get_domains_with_ssls();
                is( $href->{'domain.tld'}, 1 );
            };

            it "should NOT return nossl.tld as a key based on the mocking" => sub {
                my $href = scripts::ea_nginx::_get_domains_with_ssls();
                isnt( $href->{'nossl.tld'}, 1 );
            };

            it "should return ssl.tld as a key based on the mocking" => sub {
                my $href = scripts::ea_nginx::_get_domains_with_ssls();
                is( $href->{'ssl.tld'}, 1 );
            };
        };

        describe "_get_caching_hr" => sub {
            around {
                local $cpanel_json_loadfiles_string = "";

                local $scripts::ea_nginx::caching_cache  = undef;
                local $scripts::ea_nginx::global_caching = undef;

                no warnings "redefine";
                local *Cpanel::JSON::LoadFile = sub {
                    my ($file) = @_;
                    $cpanel_json_loadfiles_string .= "$file,";
                    return {
                        file => $file,
                    };
                };

                yield;
            };

            it "should get the data from the caching files" => sub {
                trap {
                    scripts::ea_nginx::_get_caching_hr("thebilldozer");
                };

                my $expected_str = "/etc/nginx/ea-nginx/cache.json,/var/cpanel/userdata/thebilldozer/nginx-cache.json,";
                is( $cpanel_json_loadfiles_string, $expected_str );
            };

            it "should get the data from the caching_cache, and not load from files" => sub {
                local $scripts::ea_nginx::caching_cache = { thebilldozer => 1 };

                trap {
                    scripts::ea_nginx::_get_caching_hr("thebilldozer");
                };

                my $expected_str = "";
                is( $cpanel_json_loadfiles_string, $expected_str );
            };

            it "should not load from cache.json , when caching is present" => sub {
                local $scripts::ea_nginx::global_caching = { global_caching => 1 };

                trap {
                    scripts::ea_nginx::_get_caching_hr("thebilldozer");
                };

                my $expected_str = "/var/cpanel/userdata/thebilldozer/nginx-cache.json,";
                is( $cpanel_json_loadfiles_string, $expected_str );
            };
        };

        describe "_get_nginx_bin" => sub {
            it "should die if the nginx binary is not executable" => sub {
                my $mock = Test::MockFile->file( '/usr/sbin/nginx', 'nginx executable' );
                dies_ok { scripts::ea_nginx::_get_nginx_bin() };
            };

            it "should return the path to the nginx binary if it is executable" => sub {
                my $mock = Test::MockFile->file( '/usr/sbin/nginx', 'nginx executable', { mode => 0755 } );
                is( scripts::ea_nginx::_get_nginx_bin(), '/usr/sbin/nginx' );
            };
        };

        describe "_get_num_total_domains" => sub {
            it "should return a scalar value if it loads ‘Cpanel::Config::LoadUserDomains::Count’" => sub {
                no warnings 'redefine';
                local *Cpanel::Config::LoadUserDomains::Count::countuserdomains = sub { return 42; };

                is( scripts::ea_nginx::_get_num_total_domains(), 42 );
            };
        };

        describe "_attempt_to_fix_syntax_errors" => sub {
            around {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_num_total_domains = sub { return 42; };
                local *scripts::ea_nginx::_write_global_ea_nginx = sub { return; };

                yield;
            };

            it "should die if no arguments are passed" => sub {
                dies_ok { scripts::ea_nginx::_attempt_to_fix_syntax_errors() };
            };

            it "should return 0 if it does not resolve any syntax errors" => sub {
                is( scripts::ea_nginx::_attempt_to_fix_syntax_errors('foo'), 0 );
            };

            it "should return 0 if the line with an error does match any known patterns" => sub {
                my $mockdir  = Test::MockFile->dir('/etc/nginx/conf.d/');
                my $mockfile = Test::MockFile->file( '/etc/nginx/conf.d/duplicate.conf', 'doit' );
                my $mock     = Test::MockModule->new('Path::Tiny');
                $mock->redefine(
                    path  => sub { return bless {}, 'Path::Tiny'; },
                    lines => sub { return ( 'bad_key', '42', ';' ); },
                    spew  => sub { return; },
                );

                my $line = q[nginx: [emerg] "bad_key" directive is duplicate in /etc/nginx/conf.d/duplicate.conf:3];
                is( scripts::ea_nginx::_attempt_to_fix_syntax_errors($line), 0 );
            };

            it "should return 1 if it comments out a duplicate key" => sub {
                my $mockdir  = Test::MockFile->dir('/etc/nginx/conf.d/');
                my $mockfile = Test::MockFile->file( '/etc/nginx/conf.d/duplicate.conf', 'doit' );
                my $mock     = Test::MockModule->new('Path::Tiny');
                $mock->redefine(
                    path  => sub { return bless {}, 'Path::Tiny'; },
                    lines => sub { return ('bad_key 42;'); },
                    spew  => sub { return; },
                );

                my $line = q[nginx: [emerg] "bad_key" directive is duplicate in /etc/nginx/conf.d/duplicate.conf:1];
                is( scripts::ea_nginx::_attempt_to_fix_syntax_errors($line), 1 );
            };
        };

        describe "_write_global_cpanel_localhost" => sub {
            my $wrote_new_header = 0;
            my ( $contents, $perms );
            around {
                no warnings 'redefine';
                local *scripts::ea_nginx::_write_cpanel_localhost_header = sub { $wrote_new_header++; };

                local *Cpanel::JSON::LoadFile = sub { return { 'cPanel-localhost' => 'bigbrotheriswatchingyou' }; };

                my $mock_path_tiny = Test::MockModule->new('Path::Tiny');
                $mock_path_tiny->redefine(
                    path  => sub { return bless {}, 'Path::Tiny' },
                    spew  => sub { $contents = $_[1]; },
                    chmod => sub { $perms    = $_[1]; },
                );
                yield;
            };

            before each => sub { $wrote_new_header = 0; };

            it "should write ‘cpanel-proxy-xt.conf’ with the expected cPanel-localhost header" => sub {
                scripts::ea_nginx::_write_global_cpanel_localhost();
                like( $contents, qr/cPanel-localhost\sbigbrotheriswatchingyou/ );
                like( $contents, qr/X-Forwarded-For-bigbrotheriswatchingyou/ );
            };

            it "should write ‘cpanel-proxy-xt.conf’ with the expected permissions" => sub {
                scripts::ea_nginx::_write_global_cpanel_localhost();
                is( $perms, 0600 );
            };

            describe 'caching behavior' => sub {
                around {
                    my $mock_path_tiny = Test::MockModule->new('Path::Tiny');
                    $mock_path_tiny->redefine(
                        path  => sub { return bless {}, 'Path::Tiny' },
                        spew  => sub { },
                        chmod => sub { },
                    );
                    yield;
                };

                it "should write the cpanel localhost header file if it does not exist" => sub {
                    scripts::ea_nginx::_write_global_cpanel_localhost();
                    is( $wrote_new_header, 1 );
                };

                it "should NOT write the cpanel localhost header file if it exists and was created in the last 30 minutes" => sub {
                    my $mock_dir = File::Temp->newdir();
                    local $scripts::ea_nginx::proxy_header_file = $mock_dir . '/cpanel_localhost_header.json';

                    open( my $fh, '>', $scripts::ea_nginx::proxy_header_file );
                    print $fh q[{"cPanel-localhost":"bigbrotheriswatchingyou"}];
                    close $fh;

                    scripts::ea_nginx::_write_global_cpanel_localhost();
                    is( $wrote_new_header, 0 );
                };

                it "should write the cpanel localhost header file if it does not contain the ‘cPanel-localhost’ key" => sub {
                    no warnings 'redefine';
                    local *Cpanel::JSON::LoadFile = sub { };
                    use warnings 'redefine';

                    my $mock_dir = File::Temp->newdir();
                    local $scripts::ea_nginx::proxy_header_file = $mock_dir . '/cpanel_localhost_header.json';

                    open( my $fh, '>', $scripts::ea_nginx::proxy_header_file );
                    print $fh "corrupted";
                    close $fh;

                    scripts::ea_nginx::_write_global_cpanel_localhost();
                    is( $wrote_new_header, 1 );
                };
            };
        };

        describe "_write_cpanel_localhost_header" => sub {
            my $called_rebuild_and_restart_apache = 0;
            around {
                no warnings 'redefine';
                my $mock_cpanel_rand_get = Test::MockModule->new('Cpanel::Rand::Get');
                $mock_cpanel_rand_get->redefine(
                    getranddata => sub { return 'foo_42'; },
                );

                local *scripts::ea_nginx::_rebuild_and_restart_apache = sub { $called_rebuild_and_restart_apache++; };

                my $mock_dir = File::Temp->newdir();
                local $scripts::ea_nginx::proxy_header_file = $mock_dir . '/cpanel_localhost_header.json';
                yield;
            };

            before each => sub { $called_rebuild_and_restart_apache = 0; };

            it 'should write ‘/etc/nginx/ea-nginx/cpanel_localhost_header.json’' => sub {
                scripts::ea_nginx::_write_cpanel_localhost_header();
                my $contents = Cpanel::JSON::LoadFile($scripts::ea_nginx::proxy_header_file);
                is( $contents->{'cPanel-localhost'}, 'foo-42' );
            };

            it 'should set ‘/etc/nginx/ea-nginx/cpanel_localhost_header.json’ to 0600 perms' => sub {
                scripts::ea_nginx::_write_cpanel_localhost_header();
                my $mode = ( stat $scripts::ea_nginx::proxy_header_file )[2];
                is( $mode & 0777, 0600 );
            };

            it 'should rebuild and restart apache' => sub {
                scripts::ea_nginx::_write_cpanel_localhost_header();
                is( $called_rebuild_and_restart_apache, 1 );
            };

            it 'should return the new random cPanel localhost headrer value' => sub {
                my $val = scripts::ea_nginx::_write_cpanel_localhost_header();
                is( $val, 'foo-42' );
            };
        };

        describe "_write_json" => sub {
            my $transaction_args = {};
            my $data             = {};
            my $called_save      = 0;
            my $called_close     = 0;
            around {
                my $mock_cpanel_transaction_file_json = Test::MockModule->new('Cpanel::Transaction::File::JSON');
                $mock_cpanel_transaction_file_json->redefine(
                    new => sub {
                        shift;
                        %$transaction_args = @_;
                        return bless {}, 'Cpanel::Transaction::File::JSON';
                    },
                    set_data                     => sub { shift; $data = shift; },
                    save_pretty_canonical_or_die => sub { $called_save++; },
                    close_or_die                 => sub { $called_close++; },
                );

                yield;
            };

            before each => sub { $transaction_args = {}; $data = {}; $called_save = 0; $called_close = 0; };

            it 'should create Cpanel::Transaction::File::JSON object using the given file and with 0644 perms' => sub {
                scripts::ea_nginx::_write_json( '/foo/bar.json', { foo => 'bar' } );
                is_deeply(
                    $transaction_args,
                    {
                        path        => '/foo/bar.json',
                        permissions => 0644,
                    },
                ) or diag explain $transaction_args;
            };

            it 'should set the data to match the given ref' => sub {
                scripts::ea_nginx::_write_json( '/foo/bar.json', { foo => 'bar' } );
                is_deeply(
                    $data,
                    {
                        foo => 'bar',
                    },
                ) or diag explain $data;
            };

            it 'should save the file' => sub {
                scripts::ea_nginx::_write_json( '/foo/bar.json', { foo => 'bar' } );
                is( $called_save, 1 );
            };

            it 'should close the transaction' => sub {
                scripts::ea_nginx::_write_json( '/foo/bar.json', { foo => 'bar' } );
                is( $called_close, 1 );
            };
        };

        describe "_rebuild_and_restart_apache" => sub {
            my $mock_cso;
            my $program;
            my $called_restart = 0;
            around {
                $mock_cso = Test::MockModule->new('Cpanel::SafeRun::Object');
                $mock_cso->redefine(
                    new => sub {
                        shift;
                        my %args = @_;
                        $program = $args{program};
                        return bless {}, 'Cpanel::SafeRun::Object';
                    },
                    CHILD_ERROR => sub { return 0; },
                );

                no warnings 'redefine', 'once';
                local *Cpanel::HttpUtils::ApRestart::BgSafe::restart = sub { $called_restart++; };
                yield;
            };

            before each => sub { $called_restart = 0; };

            it 'should call the script to rebuild httpd.conf' => sub {
                scripts::ea_nginx::_rebuild_and_restart_apache();
                is( $program, '/usr/local/cpanel/scripts/rebuildhttpdconf' );
            };

            it 'should warn if it fails to properly rebuild httpd.conf' => sub {
                $mock_cso->redefine(
                    CHILD_ERROR => sub { return 1; },
                    stdout      => sub { return 'httpd.conf is foobared'; },
                    stderr      => sub { return ''; },
                );

                trap { scripts::ea_nginx::_rebuild_and_restart_apache(); };
                is( $trap->stderr(), "Failed to rebuild apache configuration:  httpd.conf is foobared\n" );
            };

            it 'should call the module to restart apache' => sub {
                scripts::ea_nginx::_rebuild_and_restart_apache();
                is( $called_restart, 1 );
            };
        };

        describe "_write_global_logging" => sub {
            my ( $tt_file, $output_file, $data_hr );
            around {
                my $mock_dir = File::Temp->newdir();

                no warnings 'redefine', 'once';
                local $scripts::ea_nginx::piped_module_conf = $mock_dir . '/ngx_http_pipelog_module.conf';

                local *Cpanel::Hostname::gethostname = sub { };

                local *scripts::ea_nginx::_write_global_logging = $orig__write_global_logging;
                local *scripts::ea_nginx::_get_logging_hr       = sub { return { piped_logs => 1 }; };
                local *scripts::ea_nginx::_render_tt_to_file    = sub {
                    $tt_file     = shift;
                    $output_file = shift;
                    $data_hr     = shift;
                    return;
                };
                yield;
            };

            it 'should process global-logging.tt and write it to global-logging.conf' => sub {
                scripts::ea_nginx::_write_global_logging();
                is( $tt_file,     'global-logging.tt' );
                is( $output_file, 'global-logging.conf' );
            };

            it 'should spew logging information to ‘ngx_http_pipelog_module.conf’ if piped logging is enabled' => sub {
                scripts::ea_nginx::_write_global_logging();
                my $contents = Cpanel::LoadFile::load_if_exists($scripts::ea_nginx::piped_module_conf);
                is( $contents, 'load_module modules/ngx_http_pipelog_module.so;' );
            };

            it 'should ensure ‘ngx_http_pipelog_module.conf’ is removed if piped logging is disabled' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_logging_hr = sub { return { piped_logs => 0 }; };
                use warnings 'redefine';

                scripts::ea_nginx::_write_global_logging();
                ok !-e $scripts::ea_nginx::piped_module_conf;
            };
        };

        describe "_get_logging_hr" => sub {
            around {
                no warnings 'redefine', 'once';
                local *Whostmgr::TweakSettings::get_value               = sub { return 1; };
                local *Cpanel::Config::LoadWwwAcctConf::loadwwwacctconf = sub { return { LOGSTYLE => 'common' }; };
                local *scripts::ea_nginx::caching_global                = sub { return { logging  => 0 }; };
                local *Cpanel::EA4::Conf::Tiny::get_ea4_conf_hr         = sub { return { loglevel => 'info' }; };
                yield;
            };

            before each => sub { no warnings 'once'; $scripts::ea_nginx::logging_hr = undef; };

            it 'should set the logstyle to combined if an invalid logstyle is used' => sub {
                no warnings 'redefine';
                local *Cpanel::Config::LoadWwwAcctConf::loadwwwacctconf = sub { return {}; };
                use warnings 'redefine';

                my $hr;
                trap { $hr = scripts::ea_nginx::_get_logging_hr(); };
                is( $hr->{default_format_name}, 'combined' );
            };

            it 'should return a hashref with the users desired logging information in it' => sub {
                my $hr;
                trap { $hr = scripts::ea_nginx::_get_logging_hr(); };
                is_deeply(
                    $hr,
                    {
                        piped_logs          => 1,
                        default_format_name => 'common',
                        loglevel            => 'info',
                        enable_cache_log    => 0,
                    },
                ) or diag explain $hr;
            };
        };

        describe "caching_global" => sub {
            around {
                my $mock_dir = File::Temp->newdir();
                no warnings 'redefine';
                $scripts::ea_nginx::cache_file = $mock_dir . '/cache.json';
                yield;
            };

            before each => sub { no warnings 'once'; $scripts::ea_nginx::global_caching = undef; };

            it 'should return the contents of ‘cache.json’' => sub {
                open( my $fh, '>', $scripts::ea_nginx::cache_file );
                print $fh <<'EOF';
{
    "enabled" : 1,
    "proxy_cache_valid" : {}
}
EOF
                close $fh;

                my $hr = scripts::ea_nginx::caching_global();
                is_deeply(
                    $hr,
                    {
                        enabled           => 1,
                        proxy_cache_valid => {},
                    }
                ) or diag explain $hr;
            };

            it 'should update the contents of ‘cache.json’ to the micro-cache-defaults if the touch file is present and the normal cache defaults are present' => sub {
                my $mockfile = Test::MockFile->file( '/etc/nginx/ea-nginx/enable.micro-cache-defaults', '' );

                open( my $fh, '>', $scripts::ea_nginx::cache_file );
                print $fh <<'EOF';
{
    "enabled" : 1,
    "proxy_cache_valid" : {
        "200 301 302" : "60m",
        "404" : "1m"
    }
}
EOF
                close $fh;

                my $hr;
                trap { $hr = scripts::ea_nginx::caching_global(); };
                is_deeply(
                    $hr,
                    {
                        enabled           => 1,
                        proxy_cache_valid => {
                            "301 302" => "5m",
                            "404"     => "1m",
                        },
                    },
                ) or diag explain $hr;
            };

            it 'should update the contents of ‘cache.json’ to the normal defaults if the touch file is missing and the micro-cache-defaults are present' => sub {
                open( my $fh, '>', $scripts::ea_nginx::cache_file );
                print $fh <<'EOF';
{
    "enabled" : 1,
    "proxy_cache_valid" : {
        "301 302" : "5m",
        "404" : "1m"
    }
}
EOF
                close $fh;

                my $hr;
                trap { $hr = scripts::ea_nginx::caching_global(); };
                is_deeply(
                    $hr,
                    {
                        enabled           => 1,
                        proxy_cache_valid => {
                            "200 301 302" => "60m",
                            "404"         => "1m",
                        },
                    },
                ) or diag explain $hr;
            };
        };

        describe "_render_tt_to_file" => sub {
            my $spew;
            around {
                my $mock_path_tiny = Test::MockModule->new('Path::Tiny');
                $mock_path_tiny->redefine(
                    path      => sub { return bless {}, 'Path::Tiny'; },
                    touchpath => sub { },
                    slurp     => sub { return 'I am a tt file, hear me rawr'; },
                    spew      => sub { $spew = pop @_; return; },
                );

                yield;
            };

            before each => sub { $spew = undef; };

            it 'should process the given tt file and render it to the given output file using the given data' => sub {
                scripts::ea_nginx::_render_tt_to_file( 'tt_file', 'output_file' );
                is( $spew, 'I am a tt file, hear me rawr' );
            };

            it 'should die if it encounters any errors processing the tt' => sub {
                my $mock_template = Test::MockModule->new('Template')->redefine( error => sub { return 'oops, bad template'; } );

                trap { scripts::ea_nginx::_render_tt_to_file( 'tt_file', 'output_file' ); };
                like( $trap->die(), qr/oops, bad template/ );
            };
        };

        describe "_write_global_passenger" => sub {
            my $data;
            around {
                no warnings 'redefine', 'once';
                local *scripts::ea_nginx::_write_global_passenger = $orig__write_global_passenger;

                local *scripts::ea_nginx::_get_application_paths = sub {
                    my ($hr) = @_;
                    $hr->{ruby} = '/opt/cpanel/ea-ruby24/root/usr/libexec/passenger-ruby24';
                    return;
                };

                local *scripts::ea_nginx::_render_tt_to_file = sub { $data = pop @_; };
                yield;
            };

            it 'should render ‘ngx_http_passenger_module.conf.tt’ to ‘passenger.conf’ with the expected data' => sub {
                scripts::ea_nginx::_write_global_passenger();
                is_deeply(
                    $data,
                    {
                        passenger => {
                            global => {
                                passenger_root                  => '/opt/cpanel/ea-ruby24/root/usr/libexec/../share/passenger/phusion_passenger/locations.ini',
                                passenger_instance_registry_dir => '/opt/cpanel/ea-ruby24/root/usr/libexec/../../var/run/passenger-instreg',
                                default                         => {
                                    name => 'global passenger defaults',
                                    ruby => '/opt/cpanel/ea-ruby24/root/usr/libexec/passenger-ruby24',
                                },
                            },
                        },
                    },
                ) or diag explain $data;
            };
        };

        describe "_get_application_paths" => sub {
            it 'should populate the given hashref with the paths to the ruby, python, and nodejs binaries if they exist' => sub {
                my $hr = {};

                no warnings 'redefine';
                my $mock = Test::MockModule->new('Cpanel::Config::userdata::PassengerApps')->redefine(
                    ensure_paths => sub {
                        $hr->{ruby} = '/path/to/ruby',
                          $hr->{python} = '/path/to/python',
                          $hr->{nodejs} = '/path/to/nodejs',
                          return;
                    },
                );
                use warnings 'redefine';

                scripts::ea_nginx::_get_application_paths($hr);
                is_deeply(
                    $hr,
                    {
                        ruby   => '/path/to/ruby',
                        python => '/path/to/python',
                        nodejs => '/path/to/nodejs',
                    },
                );
            };
        };

        describe "_write_global_ea_nginx" => sub {
            it 'should render ‘ea-nginx.conf.tt’ to ‘ea-nginx.conf’ with the expected data' => sub {
                no warnings 'redefine';
                my $mock_cpanel_ea4_conf = Test::MockModule->new('Cpanel::EA4::Conf')->redefine(
                    instance => sub { return bless {}, 'Cpanel::EA4::Conf'; },
                    as_hr    => sub {
                        return {
                            sslprotocol_list_str => 'TLSv1.2 TLSv1.3',
                            sslciphersuite       => 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256',
                            keepalive            => 'Off',
                            keepalivetimeout     => 5,
                            maxkeepaliverequests => 100,
                        };
                    },
                );

                local *scripts::ea_nginx::_get_settings_hr = sub {
                    return {
                        apache_port_ip                => '127.0.0.1',
                        apache_port                   => 81,
                        apache_ssl_port               => 444,
                        server_names_hash_max_size    => 1024,
                        server_names_hash_bucket_size => 128,
                        client_max_body_size          => '128m',
                    };
                };

                local *scripts::ea_nginx::_get_httpd_vhosts_hash = sub {
                    return {
                        'foo.tld' => {
                            ip => '1.2.3.4',
                        },
                        'bar.tld' => {
                            ip => '5.6.7.8',
                        },
                        'baz.tld' => {
                            ip => '1.2.3.4',
                        },
                    };
                };

                my $data = {};
                local *scripts::ea_nginx::_render_tt_to_file = sub { $data = pop @_; };
                use warnings 'redefine';

                scripts::ea_nginx::_write_global_ea_nginx();
                is_deeply(
                    $data,
                    {
                        ea4conf => {
                            sslprotocol_list_str => 'TLSv1.2 TLSv1.3',
                            sslciphersuite       => 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256',
                            keepalive            => 'Off',
                            keepalivetimeout     => 5,
                            maxkeepaliverequests => 100,
                        },
                        settings => {
                            apache_port_ip                => '127.0.0.1',
                            apache_port                   => 81,
                            apache_ssl_port               => 444,
                            server_names_hash_max_size    => 1024,
                            server_names_hash_bucket_size => 128,
                            client_max_body_size          => '128m',
                        },
                        ips => [
                            '1.2.3.4',
                            '5.6.7.8',
                        ],
                    },
                );
            };
        };

        describe "_get_settings_hr" => sub {
            my $hr;
            around {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_cpconf_hr = sub {
                    return {
                        apache_port     => '0.0.0.0:81',
                        apache_ssl_port => '0.0.0.0:444',
                    };
                };

                local *scripts::ea_nginx::_get_server_names_hash_bucket_size = sub { return 42; };
                local *scripts::ea_nginx::_get_server_names_hash_max_size    = sub { return 21; };
                yield;
            };

            before each => sub { no warnings 'once'; $scripts::ea_nginx::settings_hr = undef; };

            it 'should return a hashref containing the default settings if ‘settings.json’ does not define anything' => sub {
                my $mock = Test::MockModule->new('Cpanel::JSON')->redefine(
                    LoadFile => sub { return {}; },
                );

                $hr = scripts::ea_nginx::_get_settings_hr();
                is_deeply(
                    $hr,
                    {
                        apache_port_ip                => '127.0.0.1',
                        server_names_hash_bucket_size => 42,
                        server_names_hash_max_size    => 21,
                        apache_ssl_port_ip            => '127.0.0.1',
                        client_max_body_size          => '128m',
                        apache_port                   => 81,
                        apache_ssl_port               => 444,
                    },
                ) or diag explain $hr;
            };

            it 'should return a hashref containing the contents of ‘settings.json’ along with any default settings that it does not define' => sub {
                my $mock = Test::MockModule->new('Cpanel::JSON')->redefine(
                    LoadFile => sub { return { foo => 'bar' }; },
                );

                $hr = scripts::ea_nginx::_get_settings_hr();
                is_deeply(
                    $hr,
                    {
                        foo                           => 'bar',
                        apache_port_ip                => '127.0.0.1',
                        server_names_hash_bucket_size => 42,
                        server_names_hash_max_size    => 21,
                        apache_ssl_port_ip            => '127.0.0.1',
                        client_max_body_size          => '128m',
                        apache_port                   => 81,
                        apache_ssl_port               => 444,
                    },
                ) or diag explain $hr;
            };

            it 'should return a hashref where the contents of ‘settings.json’ take precendence over the default settings' => sub {
                my $mock = Test::MockModule->new('Cpanel::JSON')->redefine(
                    LoadFile => sub {
                        return {
                            bar             => 'foo',
                            apache_port     => 86,
                            apache_ssl_port => 468,
                        };
                    },
                );

                $hr = scripts::ea_nginx::_get_settings_hr();
                is_deeply(
                    $hr,
                    {
                        bar                           => 'foo',
                        apache_port_ip                => '127.0.0.1',
                        server_names_hash_bucket_size => 42,
                        server_names_hash_max_size    => 21,
                        apache_ssl_port_ip            => '127.0.0.1',
                        client_max_body_size          => '128m',
                        apache_port                   => 86,
                        apache_ssl_port               => 468,
                    },
                ) or diag explain $hr;
            };
        };

        describe '_get_server_names_hash_bucket_size' => sub {
            it 'should return minimum allowed value if there are no long domains hosted on the server' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_domain_length_info = sub {
                    return {
                        longest      => 12,
                        total_length => 42,
                    };
                };
                use warnings 'redefine';

                my $value = scripts::ea_nginx::_get_server_names_hash_bucket_size(1024);
                is( $value, 128 );
            };

            it 'should return a larger value if there is a longer domain hosted on the server' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_domain_length_info = sub {
                    return {
                        longest      => 200,
                        total_length => 4242,
                    };
                };
                use warnings 'redefine';

                my $value = scripts::ea_nginx::_get_server_names_hash_bucket_size(1024);
                is( $value, 256 );
            };
        };

        describe '_get_server_names_hash_max_size' => sub {
            it 'should return the minimum max size if the number of domains hosted is less than said size' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_num_total_domains = sub { return 1; };
                use warnings 'redefine';

                my $value = scripts::ea_nginx::_get_server_names_hash_max_size();
                is( $value, 1024 );
            };

            it 'should return a larger value if there are a significant number of domains hosted on the server' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_num_total_domains = sub { return 1500; };
                use warnings 'redefine';

                my $value = scripts::ea_nginx::_get_server_names_hash_max_size();
                is( $value, 12000 );
            };
        };

        describe "_write_global_nginx_conf" => sub {
            my $content;
            around {
                my $mock_path_tiny = Test::MockModule->new('Path::Tiny')->redefine(
                    path  => sub { return bless {}, 'Path::Tiny'; },
                    slurp => sub { return "user  nginx;\nworker_processes  1;\nworker_shutdown_timeout 10s;\nworker_rlimit_nofile 16384;\n"; },
                    spew  => sub { $content = pop @_; },
                );
                yield;
            };

            before each => sub { $content = undef; };

            it 'should default the value of worker_processes to 1 if it is not defined in settings.json' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_settings_hr = sub { };
                use warnings 'redefine';

                scripts::ea_nginx::_write_global_nginx_conf();
                like( $content, qr/worker_processes\s+1;/ );
            };

            it 'should update the value of worker_processes to match what is in settings.json if it is valid (integer)' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_settings_hr = sub { return { worker_processes => 42 }; };
                use warnings 'redefine';

                scripts::ea_nginx::_write_global_nginx_conf();
                like( $content, qr/worker_processes\s+42;/ );
            };

            it 'should update the value of worker_processes to match what is in settings.json if it is valid (auto)' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_settings_hr = sub { return { worker_processes => 'auto' }; };
                use warnings 'redefine';

                scripts::ea_nginx::_write_global_nginx_conf();
                like( $content, qr/worker_processes\s+auto;/ );
            };

            it 'should warn and use the default value of worker_processes if the value set in settings.json is invalid' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_settings_hr = sub { return { worker_processes => 'foo' }; };
                use warnings 'redefine';

                trap { scripts::ea_nginx::_write_global_nginx_conf(); };
                like( $trap->stderr(), qr/Custom `worker_processes`.*is not a number/ );
            };

            it 'should default the value of worker_shutdown_timeout to 10s if it is not defined in settings.json' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_settings_hr = sub { };
                use warnings 'redefine';

                scripts::ea_nginx::_write_global_nginx_conf();
                like( $content, qr/worker_shutdown_timeout\s+10s;/ );
            };

            it 'should update the value of worker_shutdown_timeout to match what is in settings.json if it is valid' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_settings_hr = sub { return { worker_shutdown_timeout => '42ms' }; };
                use warnings 'redefine';

                scripts::ea_nginx::_write_global_nginx_conf();
                like( $content, qr/worker_shutdown_timeout\s+42ms;/ );
            };

            it 'should warn and use the default value of worker_shutdown_timeout if the value set in settings.json is invalid' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_settings_hr = sub { return { worker_shutdown_timeout => 'foo' }; };
                use warnings 'redefine';

                trap { scripts::ea_nginx::_write_global_nginx_conf(); };
                like( $trap->stderr(), qr/Custom `worker_shutdown_timeout`.*is not an NGINX time value/ );
            };
        };

        describe "_write_global_default" => sub {
            my $content;
            around {
                my $mockfile = Test::MockFile->file( "/var/cpanel/ssl/cpanel/mycpanel.pem", "this is an ssl for real though" );

                no warnings 'redefine';
                local *scripts::ea_nginx::_has_ipv6    = sub { return 1; };
                local *scripts::ea_nginx::_wants_http2 = sub { return 0; };

                my $mock_path_tiny = Test::MockModule->new('Path::Tiny')->redefine(
                    path  => sub { return bless {}, 'Path::Tiny'; },
                    slurp => sub { return "    listen 80;\n    listen [::]:80;\n    listen 443 ssl;\n    listen [::]:443 ssl;\n    ssl_certificate /var/cpanel/ssl/cpanel/cpanel.pem;\n    ssl_certificate_key /var/cpanel/ssl/cpanel/cpanel.pem;\n"; },
                    spew  => sub { $content = pop @_; },
                );
                yield;
            };

            before each => sub { $content = undef; };

            it 'should add a configuration for IPv6 if it is enabled' => sub {
                scripts::ea_nginx::_write_global_default();
                like( $content, qr/listen \[::\]:80;/ );
            };

            it 'should add a comment stating that IPv6 is not enabled if it is disabled' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_has_ipv6 = sub { return 0; };
                use warnings 'redefine';

                scripts::ea_nginx::_write_global_default();
                like( $content, qr/# server does not have IPv6 enabled:/ );
            };

            it 'should set default.conf to use mycpanel.pem for its ssl certificate if it exists' => sub {
                scripts::ea_nginx::_write_global_default();
                like( $content, qr{ssl_certificate_key\s+/var/cpanel/ssl/cpanel/mycpanel\.pem} );
            };

            it 'should set default.conf to use cpanel.pem for its ssl certificate if mycpanel.pem is missing' => sub {
                unlink '/var/cpanel/ssl/cpanel/mycpanel.pem';

                scripts::ea_nginx::_write_global_default();
                like( $content, qr{ssl_certificate_key\s+/var/cpanel/ssl/cpanel/cpanel\.pem} );
            };

            it 'should configure port 443 to use http2 if it is enabled' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_wants_http2 = sub { return 1; };
                use warnings 'redefine';

                scripts::ea_nginx::_write_global_default();
                like( $content, qr/listen 443 ssl http2;/ );
            };

            it 'should not configure port 443 to use http2 if it is not enabled' => sub {
                scripts::ea_nginx::_write_global_default();
                like( $content, qr/listen 443 ssl;/ );
            };
        };

        describe "_has_ipv6" => sub {
            around {
                my $mockfile = Test::MockFile->file( '/proc/net/if_inet6', '' );
                yield;
            };

            before each => sub { no warnings 'once'; $scripts::ea_nginx::has_ipv6 = undef; };

            it 'should return 1 when IPv6 is enabled on the server' => sub {
                is( scripts::ea_nginx::_has_ipv6(), 1 );
            };

            it 'should return 0 when IPv6 is disabled on the server' => sub {
                unlink '/proc/net/if_inet6';
                is( scripts::ea_nginx::_has_ipv6(), 0 );
            };
        };

        describe "_wants_http2" => sub {
            around {
                my $mockfile = Test::MockFile->file( '/etc/nginx/conf.d/http2.conf', '' );
                yield;
            };

            before each => sub { no warnings 'once'; $scripts::ea_nginx::wants_http2 = undef; };

            it 'should return 1 when http2 is configured for nginx' => sub {
                is( scripts::ea_nginx::_wants_http2(), 1 );
            };

            it 'should return 0 when http2 is NOT configured for nginx' => sub {
                unlink '/etc/nginx/conf.d/http2.conf';
                is( scripts::ea_nginx::_wants_http2(), 0 );
            };
        };

        describe "_write_global_cpanel_proxy_non_ssl" => sub {
            my $content;
            around {
                my $slurp = <<'EOF';
server {
    server_name cpanel.*;
    listen 80;
    listen [::]:80;
    return 301 https://$host$request_uri;
}
EOF

                my $mock_path_tiny = Test::MockModule->new('Path::Tiny')->redefine(
                    path  => sub { return bless {}, 'Path::Tiny'; },
                    slurp => sub { return $slurp; },
                    spew  => sub { $content = pop @_; },
                );
                yield;
            };

            before each => sub { $content = undef; };

            it 'should add a configuration for IPv6 if it is enabled' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_has_ipv6 = sub { return 1; };
                use warnings 'redefine';

                scripts::ea_nginx::_write_global_cpanel_proxy_non_ssl();
                like( $content, qr/listen \[::\]:80;/ );
            };

            it 'should add a comment stating that IPv6 is not enabled if it is disabled' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_has_ipv6 = sub { return 0; };
                use warnings 'redefine';

                scripts::ea_nginx::_write_global_cpanel_proxy_non_ssl();
                like( $content, qr/# server does not have IPv6 enabled:/ );
            };
        };

        describe "_update_user_configs_in_serial_mode" => sub {
            around {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_user_domains = sub {
                    return {
                        foo => 1,
                        bar => 1,
                        baz => 1,
                    };
                };
                local *scripts::ea_nginx::_process_users = sub { };
                yield;
            };

            it 'should print a message saying that the config subcommand is running in serial mode' => sub {
                my $errors;
                trap { $errors = scripts::ea_nginx::_update_user_configs_in_serial_mode(); };
                like( $trap->stdout(), qr/Serial mode detected\.  User configuration will take longer/ );
                is( $errors, undef );
            };

            it 'should return a hashref of users that had errors' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_process_users = sub {
                    return {
                        foo => 'failed',
                        bar => 'is bad',
                    };
                };

                my $errors;
                trap { $errors = scripts::ea_nginx::_update_user_configs_in_serial_mode(); };
                is_deeply(
                    $errors,
                    {
                        foo => 'failed',
                        bar => 'is bad',
                    },
                ) or diag explain $errors;
            };
        };

        describe "_process_users" => sub {
            my @users_called;
            around {
                no warnings 'redefine', 'once';
                local *scripts::ea_nginx::_write_user_conf = sub {
                    push @users_called, $_[0];
                    die "whoops\n" if $_[0] eq 'foo';
                };
                yield;
            };

            it 'should accept an array ref of users to process and call _write_user_conf() for each user' => sub {
                my $errors = scripts::ea_nginx::_process_users( [ 'foo', 'bar', 'baz' ] );
                is_deeply(
                    \@users_called,
                    [
                        'foo',
                        'bar',
                        'baz',
                    ],
                ) or diag explain \@users_called;
            };

            it 'should return a hashref of users that had errors' => sub {
                my $errors = scripts::ea_nginx::_process_users( [ 'foo', 'bar', 'baz' ] );
                is_deeply(
                    $errors,
                    {
                        'foo' => "whoops\n",
                    },
                );
            };
        };

        describe "_write_user_conf" => sub {
            my $spewed;
            my $render_domains = [];
            around {
                no warnings 'redefine', 'once';
                local *scripts::ea_nginx::_write_user_conf = $orig__write_user_conf;

                my $mock_cpanel_config_userdata_load = Test::MockModule->new('Cpanel::Config::userdata::Load')->redefine(
                    load_userdata_main => sub {
                        return {
                            main_domain   => 'foo.tld',
                            addon_domains => {
                                'addon1.tld' => 'sub.addon1.tld',
                                'addon2.tld' => 'sub.addon2.tld',
                            },
                            sub_domains => [
                                'sub.addon1.tld',
                                'sub.addon2.tld',
                                'sub1.foo.tld',
                                'sub2.foo.tld',
                            ],
                            parked_domains => [
                                'parked1.tld',
                                'parked2.tld',
                            ],
                        };
                    },
                );

                local *scripts::ea_nginx_userdata::run    = sub { };
                local *scripts::ea_nginx::_get_caching_hr = sub {
                    return {
                        enabled       => 1,
                        inactive_time => '42m',
                        zone_size     => '24m',
                        levels        => '1:2',
                    };
                };

                my $mock_path_tiny = Test::MockModule->new('Path::Tiny')->redefine(
                    path   => sub { return bless {}, 'Path::Tiny'; },
                    spew   => sub { $spewed = pop @_; },
                    append => sub { },
                );

                local *scripts::ea_nginx::_render_and_append = sub { my ($args) = @_; push @$render_domains, $args->{domains}; };
                yield;
            };

            before each => sub { $spewed = undef; };

            it 'should write the cache configuration for the user at the top of its configuration file' => sub {
                scripts::ea_nginx::_write_user_conf('foo');
                like( $spewed, qr{^proxy_cache_path /var/cache/ea-nginx/proxy/foo levels=1:2 keys_zone=foo:24m inactive=42m;} );
            };

            it 'should call _render_and_append() to write the server block for the primary domain for the user' => sub {
                scripts::ea_nginx::_write_user_conf('foo');
                is( $render_domains->[0][0], 'foo.tld' );
            };

            it 'should include the parked domains for the account when calling _render_and_append() for the primary domain for the user' => sub {
                scripts::ea_nginx::_write_user_conf('foo');
                is_deeply(
                    $render_domains->[0],
                    [ 'foo.tld', 'parked1.tld', 'parked2.tld' ],
                );
            };

            it 'should call _render_and_append() for each subdomain for the account' => sub {
                scripts::ea_nginx::_write_user_conf('foo');
                is_deeply(
                    $render_domains->[1],
                    ['sub1.foo.tld'],
                );
                is_deeply(
                    $render_domains->[2],
                    ['sub2.foo.tld'],
                );
            };

            it 'should call _render_and_append() for each addon domain for the account' => sub {
                scripts::ea_nginx::_write_user_conf('foo');
                is_deeply(
                    $render_domains->[3],
                    [ 'sub.addon1.tld', 'addon1.tld' ],
                );
                is_deeply(
                    $render_domains->[4],
                    [ 'sub.addon2.tld', 'addon2.tld' ],
                );
            };

            it 'should pass global_config_data into _render_and_append()' => sub {
                no warnings 'redefine';
                my $data = [];
                local *scripts::ea_nginx::_render_and_append = sub {
                    my ($args) = @_;
                    my $config_data = $args->{global_config_data};
                    push @$data, $config_data;
                };
                use warnings 'redefine';

                scripts::ea_nginx::_write_user_conf( 'foo', { foo => 'bar', } );
                cmp_deeply(
                    $data,
                    [
                        { foo => 'bar' },
                        { foo => 'bar' },
                        { foo => 'bar' },
                        { foo => 'bar' },
                        { foo => 'bar' },
                    ],
                ) or diag explain $data;
            };
        };

        describe "_render_and_append" => sub {
            my $mock_template;
            around {
                my $mock_modsecurity_module = Test::MockFile->file('/etc/nginx/conf.d/modules/ngx_http_modsecurity_module.conf');
                my $mock_log_file           = Test::MockFile->file('/var/log/nginx/domains/foo.tld');
                my $mock_bytes_log_file     = Test::MockFile->file('/var/log/nginx/domains/foo.tld-bytes_log');
                my $mock_ssl_log_file       = Test::MockFile->file('/var/log/nginx/domains/foo.tld-ssl_log');
                my $mock_set_user_id        = Test::MockFile->file('/etc/cpanel/ea4/option-flags/set-USER_ID');
                my $mock_user_conf          = Test::MockFile->file('/etc/nginx/conf.d/users/foo.conf');

                unlink '/etc/nginx/conf.d/modules/ngx_http_modsecurity_module.conf';
                unlink '/etc/cpanel/ea4/option-flags/set-USER_ID';

                no warnings 'redefine';
                local *scripts::ea_nginx::_get_group_for         = sub { };
                local *scripts::ea_nginx::_is_standalone         = sub { return 1; };
                local *scripts::ea_nginx::_get_basic_auth        = sub { };
                local *scripts::ea_nginx::_get_redirects         = sub { };
                local *scripts::ea_nginx::_get_logging_hr        = sub { };
                local *scripts::ea_nginx::_get_ssl_redirect      = sub { };
                local *scripts::ea_nginx::_get_passenger_apps    = sub { };
                local *scripts::ea_nginx::_get_caching_hr        = sub { };
                local *scripts::ea_nginx::_has_ipv6              = sub { };
                local *scripts::ea_nginx::_wants_http2           = sub { };
                local *scripts::ea_nginx::_get_domains_with_ssls = sub { };
                local *scripts::ea_nginx::_get_httpd_vhosts_hash = sub { };
                local *scripts::ea_nginx::_get_cpconf_hr         = sub { };
                local *scripts::ea_nginx::_get_settings_hr       = sub { };
                local *scripts::ea_nginx::_get_wordpress_info    = sub {
                    return {
                        docroot_install  => undef,
                        non_docroot_uris => [],
                    };
                };

                my $mock_cpanel_json = Test::MockModule->new('Cpanel::JSON')->redefine(
                    LoadFile => sub { },
                );

                $mock_template = Test::MockModule->new('Template');
                $mock_template->redefine(
                    new     => sub { return bless {}, 'Template'; },
                    process => sub { },
                    error   => sub { return 0; },
                );

                my $mock_path_tiny = Test::MockModule->new('Path::Tiny')->redefine(
                    path  => sub { return bless {}, 'Path::Tiny'; },
                    slurp => sub { },
                );

                my $mock_cpanel_domainlookup_docroot = Test::MockModule->new('Cpanel::DomainLookup::DocRoot')->redefine(
                    getdocroots => sub { return 'foo.tld' => '/home/foo/public_html'; },
                );

                my $mock_cpanel_pwcache = Test::MockModule->new('Cpanel::PwCache')->redefine(
                    getpwnam => sub { return ( undef, undef, undef, undef ); },
                );

                my $mock_cpanel_fileutils_touchfile = Test::MockModule->new('Cpanel::FileUtils::TouchFile')->redefine(
                    touchfile => sub { },
                );

                my $mock_cpanel_phpfpm_get = Test::MockModule->new('Cpanel::PHPFPM::Get')->redefine(
                    get_php_fpm => sub { return 0; },
                );

                my $mock_cpanel_apache_tls = Test::MockModule->new('Cpanel::Apache::TLS')->redefine(
                    get_tls_path => sub { },
                );

                my $mock_cpanel_domainip = Test::MockModule->new('Cpanel::DomainIp')->redefine(
                    getdomainip => sub { },
                );

                my $mock_cpanel_nat = Test::MockModule->new('Cpanel::NAT')->redefine(
                    get_public_ip => sub { return ''; },
                );

                my $mock_cpanel_ea4_conf = Test::MockModule->new('Cpanel::EA4::Conf')->redefine(
                    instance => sub { return bless {}, 'Cpanel::EA4::Conf'; },
                    as_hr    => sub { },
                );

                yield;
            };

            it 'should warn if it is in standalone mode, the domain has php fpm enabled, and it is unable to gather the php config settings for the domain' => sub {
                my $mock_cpanel_phpfpm_get = Test::MockModule->new('Cpanel::PHPFPM::Get')->redefine(
                    get_php_fpm => sub { return 1; },
                );

                my $mock_cpanel_php_config = Test::MockModule->new('Cpanel::PHP::Config')->redefine(
                    get_php_config_for_domains => sub { return {}; },
                );

                trap {
                    scripts::ea_nginx::_render_and_append(
                        {
                            user                  => 'foo',
                            domains               => ['foo.tld'],
                            global_config_data    => {},
                            mail_subdomain_exists => 0,
                        }
                    );
                };
                like( $trap->stderr(), qr/Could not find PHP configuration for.*it will not be configured to use PHP-FPM/ );
            };

            it 'should die if it fails to process the template toolkit file' => sub {
                $mock_template->redefine(
                    error => sub { return 'no process tt for you'; },
                );

                trap {
                    scripts::ea_nginx::_render_and_append(
                        {
                            user                  => 'foo',
                            domains               => ['foo.tld'],
                            global_config_data    => {},
                            mail_subdomain_exists => 0,
                        }
                    );
                };
                like( $trap->die(), qr/no process tt for you/ );
            };
        };

        describe "_is_standalone" => sub {
            around {
                my $mockfile = Test::MockFile->file( '/etc/nginx/ea-nginx/enable.standalone', '' );
                yield;
            };

            before each => sub { no warnings 'once'; $scripts::ea_nginx::standalone = undef; };

            it 'should return 1 if nginx is in standalone mode' => sub {
                is( scripts::ea_nginx::_is_standalone(), 1 );
            };

            it 'should return 0 if nginx is NOT in standalone mode' => sub {
                unlink '/etc/nginx/ea-nginx/enable.standalone';
                is( scripts::ea_nginx::_is_standalone(), 0 );
            };
        };

        describe "_get_basic_auth" => sub {
            around {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_homedir = sub { return '/home/foo'; };
                yield;
            };

            it 'should return a hashref containing the auth_file for the docroot if the docroot is the only password protected directory' => sub {
                my $res = scripts::ea_nginx::_get_basic_auth(
                    'foo',
                    '/home/foo/public_html',
                    {
                        '/public_html' => {
                            '_htaccess_mtime' => 1234,
                            'realm_name'      => 'docroot',
                        },
                    },
                );

                is_deeply(
                    $res,
                    {
                        realm_name      => 'docroot',
                        auth_file       => '/home/foo/.htpasswds/public_html/passwd',
                        _htaccess_mtime => 1234,
                        locations       => {},
                    },
                ) or diag explain $res;
            };

            it 'should return a hashref containing the auth_file for a directory beneath the docroot if it exists' => sub {
                my $res = scripts::ea_nginx::_get_basic_auth(
                    'foo',
                    '/home/foo/public_html/subdomain',
                    {
                        '/public_html' => {
                            '_htaccess_mtime' => 1234,
                            'realm_name'      => 'docroot',
                        },
                        '/public_html/nope' => {
                            '_htaccess_mtime' => 5678,
                            'realm_name'      => 'nope',
                        },
                    },
                );

                is_deeply(
                    $res,
                    {
                        realm_name      => 'docroot',
                        auth_file       => '/home/foo/.htpasswds/public_html/passwd',
                        _htaccess_mtime => 1234,
                        locations       => {},
                    },
                ) or diag explain $res;
            };

            it 'should return a hashref containing the auth_file for the home directory if only the homedir is protected' => sub {
                my $res = scripts::ea_nginx::_get_basic_auth(
                    'foo',
                    '/home/foo/public_html',
                    {
                        '' => {
                            '_htaccess_mtime' => 1234,
                            'realm_name'      => 'home',
                        },
                    },
                );

                is_deeply(
                    $res,
                    {
                        realm_name      => 'home',
                        auth_file       => '/home/foo/.htpasswds/passwd',
                        _htaccess_mtime => 1234,
                        locations       => {},
                    },
                ) or diag explain $res;
            };

            it 'should populate the locations key for any directories above the protected directory' => sub {
                my $res = scripts::ea_nginx::_get_basic_auth(
                    'foo',
                    '/home/foo/public_html',
                    {
                        '' => {
                            '_htaccess_mtime' => 1234,
                            'realm_name'      => 'home',
                        },
                        '/public_html' => {
                            '_htaccess_mtime' => 1234,
                            'realm_name'      => 'docroot',
                        },
                        '/public_html/sub' => {
                            '_htaccess_mtime' => 1234,
                            'realm_name'      => 'sub',
                        },
                        '/public_html/sub/finn/quinn' => {
                            '_htaccess_mtime' => 1234,
                            'realm_name'      => 'glee',
                        },
                    },
                );

                is_deeply(
                    $res,
                    {
                        realm_name      => 'docroot',
                        auth_file       => '/home/foo/.htpasswds/public_html/passwd',
                        _htaccess_mtime => 1234,
                        locations       => {
                            '/sub' => {
                                'auth_file'  => '/home/foo/.htpasswds/public_html/sub/passwd',
                                'realm_name' => 'sub',
                            },
                            '/sub/finn/quinn' => {
                                'auth_file'  => '/home/foo/.htpasswds/public_html/sub/finn/quinn/passwd',
                                'realm_name' => 'glee',
                            },
                        },
                    },
                ) or diag explain $res;
            };
        };

        describe "_get_userdata_for" => sub {
            around {
                my $mock_cpanel_config_userdata_load = Test::MockModule->new('Cpanel::Config::userdata::Load')->redefine(
                    load_userdata => sub { return { a => 1, b => 2, c => 3, }; },
                );
                yield;
            };

            it 'should return a hashref of userdata for the given domain' => sub {
                my $res = scripts::ea_nginx::_get_userdata_for( 'foo', 'bar.tld' );
                is_deeply(
                    $res,
                    {
                        a => 1,
                        b => 2,
                        c => 3,
                    },
                );
            };

            it 'should cache the result for subsequent calls' => sub {
                my $mock_cpanel_config_userdata_load = Test::MockModule->new('Cpanel::Config::userdata::Load')->redefine(
                    load_userdata => sub { return { a => 9, b => 42, c => 0, }; },
                );

                my $res = scripts::ea_nginx::_get_userdata_for( 'foo', 'bar.tld' );
                is_deeply(
                    $res,
                    {
                        a => 1,
                        b => 2,
                        c => 3,
                    },
                );

                $res = scripts::ea_nginx::_get_userdata_for( 'foo', 'foo.tld' );
                is_deeply(
                    $res,
                    {
                        a => 9,
                        b => 42,
                        c => 0,
                    },
                );
            };
        };

        describe "_get_passenger_apps" => sub {
            around {
                no warnings 'redefine', 'once';
                local *scripts::ea_nginx::_get_application_paths = sub { };
                yield;
            };

            it 'should return an empty array reference if the user does not have an applications.json file' => sub {
                my $mock_cpanel_json = Test::MockModule->new('Cpanel::JSON')->redefine( LoadFile => sub { die; }, );

                my $res = scripts::ea_nginx::_get_passenger_apps( 'foo', ['foo.tld'] );
                is_deeply( $res, [] );
            };

            it 'should return an empty array reference if none of the apps listed in applications.json are enabled' => sub {
                my $mock_cpanel_json = Test::MockModule->new('Cpanel::JSON')->redefine(
                    LoadFile => sub {
                        return {
                            yo => {
                                enabled => 0,
                            },
                        };
                    },
                );

                my $res = scripts::ea_nginx::_get_passenger_apps( 'foo', ['foo.tld'] );
                is_deeply( $res, [] );
            };

            it 'should return an empty array reference if none of the apps listed in applications.json are for one of the domains passed in' => sub {
                my $mock_cpanel_json = Test::MockModule->new('Cpanel::JSON')->redefine(
                    LoadFile => sub {
                        return {
                            yo => {
                                enabled => 1,
                                domain  => 'bar.tld',
                            },
                        };
                    },
                );

                my $res = scripts::ea_nginx::_get_passenger_apps( 'foo', ['foo.tld'] );
                is_deeply( $res, [] );
            };

            it 'should return array reference of hashes for any apps that are enabled and belong to one of the domains passed in' => sub {
                my $mock_cpanel_json = Test::MockModule->new('Cpanel::JSON')->redefine(
                    LoadFile => sub {
                        return {
                            yo => {
                                base_uri        => '/bar',
                                deployment_mode => 'development',
                                domain          => 'bar.tld',
                                enabled         => 1,
                                envvars         => {},
                                name            => 'yo',
                                path            => '/home/foo/bar',
                                python          => '/usr/bin/python',
                                ruby            => '/opt/cpanel/ea-ruby27/root/usr/libexec/passenger-ruby27',
                            },
                        };
                    },
                );

                my $res = scripts::ea_nginx::_get_passenger_apps( 'foo', [ 'foo.tld', 'bar.tld' ] );
                is_deeply(
                    $res,
                    [
                        {
                            envvars         => {},
                            base_uri        => '/bar',
                            deployment_mode => 'development',
                            name            => 'yo',
                            path            => '/home/foo/bar',
                            enabled         => 1,
                            python          => '/usr/bin/python',
                            domain          => 'bar.tld',
                            ruby            => '/opt/cpanel/ea-ruby27/root/usr/libexec/passenger-ruby27',
                        },
                    ],
                ) or diag explain $res;
            };
        };

        describe "_get_wordpress_info" => sub {
            around {
                my $mock_cache_file          = Test::MockFile->file( '/etc/nginx/wordpress_info_cache/foo__home_foo_public_html_wordpress_info.json', '{}' );
                my $mock_wp_toolkit_bin      = Test::MockFile->file( '/usr/local/bin/wp-toolkit',                                '', { mode => 0700, } );
                my $mock_wp_instance_manager = Test::MockFile->file( '/usr/local/cpanel/Cpanel/API/WordPressInstanceManager.pm', '', { mode => 0644 } );

                no warnings 'redefine';
                local *scripts::ea_nginx::_is_wordpress_info_cache_valid         = sub { return 0; };
                local *scripts::ea_nginx::_ensure_wordpress_info_cache_directory = sub { };
                local *scripts::ea_nginx::_write_json                            = sub { };
                local *scripts::ea_nginx::_get_wp_uapi                           = sub { };
                yield;
            };

            it 'should return the wp info from the cache file if it is valid' => sub {
                my $called = 0;

                no warnings 'redefine';
                local *scripts::ea_nginx::_is_wordpress_info_cache_valid = sub { return 1; };
                local *scripts::ea_nginx::_get_wordpress_info_from_cache = sub { $called++; };
                local *scripts::ea_nginx::_write_json                    = sub { die; };
                use warnings 'redefine';

                scripts::ea_nginx::_get_wordpress_info( 'foo', '/home/foo/public_html' );
                is( $called, 1 );
            };

            it 'should get the wp info from wp-toolkit if the wp-toolkit binary exists' => sub {
                my $called = 0;
                unlink '/etc/nginx/wordpress_info_cache/foo__home_foo_public_html_wordpress_info.json';

                no warnings 'redefine';
                local *scripts::ea_nginx::_get_wp_toolkit_list_for_user = sub { $called++; };
                use warnings 'redefine';

                scripts::ea_nginx::_get_wordpress_info( 'foo', '/home/foo/public_html' );
                is( $called, 1 );
            };

            it 'should get the wp info from wordpress instance manager if it is installed and the wp-toolkit binary does not exist' => sub {
                my $called = 0;
                unlink '/etc/nginx/wordpress_info_cache/foo__home_foo_public_html_wordpress_info.json';
                unlink '/usr/local/bin/wp-toolkit';

                no warnings 'redefine';
                local *scripts::ea_nginx::_get_wordpress_info_from_wpmanager = sub { $called++; };
                use warnings 'redefine';

                scripts::ea_nginx::_get_wordpress_info( 'foo', '/home/foo/public_html' );
                is( $called, 1 );
            };

            it 'should ensure the cache directory exists' => sub {
                my $called = 0;
                unlink '/etc/nginx/wordpress_info_cache/foo__home_foo_public_html_wordpress_info.json';
                unlink '/usr/local/bin/wp-toolkit';
                unlink '/usr/local/cpanel/Cpanel/API/WordPressInstanceManager.pm';

                no warnings 'redefine';
                local *scripts::ea_nginx::_ensure_wordpress_info_cache_directory = sub { $called++; };
                use warnings 'redefine';

                scripts::ea_nginx::_get_wordpress_info( 'foo', '/home/foo/public_html' );
                is( $called, 1 );
            };

            it 'should write the cache file if it was not valid' => sub {
                my $cache_file;
                unlink '/etc/nginx/wordpress_info_cache/foo__home_foo_public_html_wordpress_info.json';
                unlink '/usr/local/bin/wp-toolkit';
                unlink '/usr/local/cpanel/Cpanel/API/WordPressInstanceManager.pm';

                no warnings 'redefine';
                local *scripts::ea_nginx::_write_json = sub { $cache_file = shift; };
                use warnings 'redefine';

                scripts::ea_nginx::_get_wordpress_info( 'foo', '/home/foo/public_html' );
                is( $cache_file, '/etc/nginx/wordpress_info_cache/foo__home_foo_public_html_wordpress_info.json' );
            };

            it 'should return the wp info for the user' => sub {
                unlink '/etc/nginx/wordpress_info_cache/foo__home_foo_public_html_wordpress_info.json';
                unlink '/usr/local/bin/wp-toolkit';
                unlink '/usr/local/cpanel/Cpanel/API/WordPressInstanceManager.pm';

                my $res = scripts::ea_nginx::_get_wordpress_info( 'foo', '/home/foo/public_html' );
                is_deeply(
                    $res,
                    {
                        docroot_install  => 0,
                        non_docroot_uris => [],
                    },
                );
            };
        };

        describe "_get_wordpress_info_from_cache" => sub {
            it 'should warn if the cache file fails to load' => sub {
                my $mock_cpanel_json = Test::MockModule->new('Cpanel::JSON')->redefine(
                    LoadFile => sub { die; },
                );

                my $res;
                trap { $res = scripts::ea_nginx::_get_wordpress_info_from_cache(''); };
                like( $trap->stderr(), qr/Failed to load cache file/ );
                is( $res, undef );
            };

            it 'should warn if the cache file is missing either of the required keys' => sub {
                my $mock_cpanel_json = Test::MockModule->new('Cpanel::JSON')->redefine(
                    LoadFile => sub { return {}; },
                );

                my $res;
                trap { $res = scripts::ea_nginx::_get_wordpress_info_from_cache(''); };
                like( $trap->stderr(), qr/The cache file.*has missing data/ );
                is( $res, undef );
            };

            it 'should return a hashref if it loads the cache file successfully' => sub {
                my $mock_cpanel_json = Test::MockModule->new('Cpanel::JSON')->redefine(
                    LoadFile => sub { return { docroot_install => 1, non_docroot_uris => [], }; },
                );

                my $res;
                trap { $res = scripts::ea_nginx::_get_wordpress_info_from_cache(''); };
                is( $trap->stderr(), '' );
                is_deeply(
                    $res,
                    {
                        docroot_install  => 1,
                        non_docroot_uris => [],
                    },
                );
            };
        };

        describe "_get_wp_toolkit_list_for_user" => sub {
            it 'should return the wp info for the given user and docroot if there is any' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_wp_toolkit_list = sub {
                    return [
                        {
                            fullPath => '/home/foo/public_html',
                            siteUrl  => 'https://foo.tld/',
                        },
                        {
                            fullPath => '/home/foo/public_html/finn',
                            siteUrl  => 'https://foo.tld/finn',
                        },
                        {
                            fullPath => '/home/foo/public_html/rock/roll',
                            siteUrl  => 'https://foo.tld/rock/roll',
                        },
                    ];
                };
                use warnings 'redefine';

                my $res = scripts::ea_nginx::_get_wp_toolkit_list_for_user(
                    'foo',
                    '/home/foo/public_html',
                    {
                        docroot_install  => 0,
                        non_docroot_uris => [],
                    },
                );

                is( $res->{docroot_install}, 1 );
                cmp_bag(
                    $res->{non_docroot_uris},
                    [
                        'finn',
                        'rock/roll',
                    ],
                );
            };
        };

        describe "_update_user_configs_in_parallel_mode" => sub {
            it 'should return a hashref of users that had errors' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_user_domains = sub {
                    return {
                        foo => 1,
                        bar => 1,
                        baz => 1,
                    };
                };
                local *scripts::ea_nginx::_process_users = sub {
                    return {
                        foo => 'failed',
                        bar => 'is bad',
                    };
                };

                my $errors;
                trap { $errors = scripts::ea_nginx::_update_user_configs_in_parallel_mode(); };
                is_deeply(
                    $errors,
                    {
                        foo => 'failed',
                        bar => 'is bad',
                    },
                ) or diag explain $errors;
            };
        };

        describe "_get_global_config_data" => sub {
            around {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_global_config_data = $orig__get_global_config_data;

                local *scripts::ea_nginx::_get_domain_ips = sub { return { '1.2.3.4' => 'foo.tld' }; };
                yield;
            };

            it 'should return a hashref containing data that all users will need when being configured' => sub {
                my $data = scripts::ea_nginx::_get_global_config_data();
                is_deeply(
                    $data,
                    {
                        domain_ips => {
                            '1.2.3.4' => 'foo.tld',
                        },
                    },
                ) or diag explain $data;
            };
        };

        describe "_get_domain_ips" => sub {
            around {
                my $mock_cpanel_httputils_vhosts_primaryreader = Test::MockModule->new('Cpanel::HttpUtils::Vhosts::PrimaryReader')->redefine(
                    new                            => sub { return bless {}, 'Cpanel::HttpUtils::Vhosts::PrimaryReader'; },
                    get_primary_non_ssl_servername => sub { return 'baz.tld', },
                );

                my $mock_cpanel_config_userdata_load = Test::MockModule->new('Cpanel::Config::userdata::Load')->redefine(
                    load_userdata_main => sub {
                        my ($user) = @_;
                        my $domain = $user . '.tld';
                        return {
                            main_domain => $domain,
                        };
                    },
                );

                my $mock_cpanel_domainip = Test::MockModule->new('Cpanel::DomainIp')->redefine(
                    getdomainip => sub {
                        my ($domain) = @_;
                        return '5.6.7.8' if $domain eq 'bar.tld';
                        return '1.2.3.4';
                    },
                );

                my $mock_cpanel_dip_isdedicated = Test::MockModule->new('Cpanel::DIp::IsDedicated')->redefine(
                    isdedicatedip => sub { return $_[0] eq '5.6.7.8' ? 1 : 0; },
                );

                no warnings 'redefine';
                local *scripts::ea_nginx::_get_user_domains = sub {
                    return {
                        foo => 1,
                        bar => 1,
                        baz => 1,
                    };
                };
                yield;
            };

            it 'should return a hashref mapping IPs to domains that they will be assigned to' => sub {
                my $data = scripts::ea_nginx::_get_domain_ips();
                is_deeply(
                    $data,
                    {
                        '1.2.3.4' => 'baz.tld',
                        '5.6.7.8' => 'bar.tld',
                    },
                ) or diag explain $data;
            };
        };

        describe "_get_aligned_domain_length" => sub {
            it 'should return the smallest integer that is divisible by 8 and greater than or equal to the given integer' => sub {
                is( scripts::ea_nginx::_get_aligned_domain_length(16), 16 );
                is( scripts::ea_nginx::_get_aligned_domain_length(42), 48 );
            };
        };

        describe "_get_domain_length_info" => sub {
            it 'should return the length of the longest domain and the total length of all domains hosted on the system' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_get_user_domains = sub {
                    return {
                        foo => [
                            'foo.tld',
                            'new.foo.tld',
                        ],
                        bar    => ['bar.tld'],
                        whodat => ['this.is.a.really.long.domain.name.it.goes.on.and.on.till.the.end.of.the.song.and.it.is.still.not.as.long.as.it.needs.to.be.so.my.will.go.on.even.though.it.is.annoyed'],
                    };
                };
                use warnings 'redefine';

                is_deeply(
                    scripts::ea_nginx::_get_domain_length_info(),
                    {
                        longest      => 200,
                        total_length => 3280,
                    },
                );
            };
        };
    };

    describe "cache_config" => sub {
        share my %ti;

        around {
            local $ti{temp_dir} = File::Temp->newdir();

            local $scripts::ea_nginx::var_cpanel_userdata = $ti{temp_dir} . "/userdata";
            local $scripts::ea_nginx::etc_nginx           = $ti{temp_dir} . "/etc_nginx";
            local $scripts::ea_nginx::cache_file          = $scripts::ea_nginx::etc_nginx . "/ea-nginx/cache.json";

            mkdir $scripts::ea_nginx::var_cpanel_userdata;
            mkdir $scripts::ea_nginx::var_cpanel_userdata . "/ipman";
            mkdir $scripts::ea_nginx::etc_nginx;
            mkdir $scripts::ea_nginx::etc_nginx . "/ea-nginx";

            local $ti{validate_user_called} = 0;
            local $ti{config_called}        = 0;

            no warnings qw(redefine once);
            local *scripts::ea_nginx::_validate_user_arg = sub {
                $ti{validate_user_called}++;
                return 1;
            };
            local *scripts::ea_nginx::config = sub {
                $ti{config_called}++;
                return 1;
            };

            yield;
        };

        it "should die if no user or system passed" => sub {
            trap {
                scripts::ea_nginx::cache_config( {} );
            };

            like( $trap->die, qr/^First argument/ );
        };

        it "should die if user is empty" => sub {
            trap {
                scripts::ea_nginx::cache_config( {}, "" );
            };

            like( $trap->die, qr/^First argument/ );
        };

        it "should show users config file (empty json if it does not exist) if no flags passed after user" => sub {
            trap {
                scripts::ea_nginx::cache_config( {}, "ipman" );
            };

            is( $trap->stdout, "{}\n" );
        };

        it "should show users config file if no flags passed after user" => sub {
            trap {
                scripts::ea_nginx::cache_config( {}, "ipman", "--enabled=1" );
                scripts::ea_nginx::cache_config( {}, "ipman" );
            };

            my $expected = q/{
   "enabled" : true
}
/;

            is( $trap->stdout, $expected );
        };

        it "should show system config file if no flags passed after --system" => sub {
            trap {
                scripts::ea_nginx::cache_config( {}, "--system", "--enabled=1" );
                scripts::ea_nginx::cache_config( {}, "--system" );
            };

            my $expected = q/{
   "enabled" : true
}
/;

            is( $trap->stdout, $expected );
        };

        it "should die if --reset is mixed with other configuration flags" => sub {
            trap {
                scripts::ea_nginx::cache_config( {}, "ipman", "--reset", "--no-rebuild", "--enabled=0" );
            };

            like( $trap->die, qr/--reset does not make sense/ );
        };

        it "should go back to defaults if reset is called on system" => sub {
            trap {
                scripts::ea_nginx::cache_config( {}, "--system", "--reset", "--no-rebuild" );
            };

            # load the file, it should match the caching_defaults
            my $file      = $scripts::ea_nginx::cache_file;
            my $from_file = eval { Cpanel::JSON::LoadFile($file) } || {};

            my %expected = scripts::ea_nginx::caching_defaults();
            scripts::ea_nginx::_jsonify_caching_booleans( \%expected );

            cmp_deeply( $from_file, \%expected );
        };

        it "should delete user file if user arg also has --reset" => sub {
            my $file = $scripts::ea_nginx::var_cpanel_userdata . "/ipman/nginx-cache.json";
            Path::Tiny::path($file)->spew('{ enabled: true }');

            trap {
                scripts::ea_nginx::cache_config( {}, "ipman", "--reset", "--no-rebuild" );
            };

            ok( !-e $file );
        };

        it "config should not be called if resetting system with no rebuild" => sub {
            trap {
                scripts::ea_nginx::cache_config( {}, "--system", "--reset", "--no-rebuild" );
            };

            is( $ti{config_called}, 0 );
        };

        it "config should not be called if resetting a user with no rebuild" => sub {
            my $file = $scripts::ea_nginx::cache_file;
            Path::Tiny::path($file)->spew('{ enabled: true }');

            trap {
                scripts::ea_nginx::cache_config( {}, "ipman", "--reset", "--no-rebuild" );
            };

            is( $ti{config_called}, 0 );
        };

        it "config should be called if resetting system" => sub {
            trap {
                scripts::ea_nginx::cache_config( {}, "--system", "--reset" );
            };

            is( $ti{config_called}, 1 );
        };

        it "config should be called if resetting a user" => sub {
            my $file = $scripts::ea_nginx::var_cpanel_userdata . "/ipman/nginx-cache.json";
            Path::Tiny::path($file)->spew('{ enabled: true }');

            trap {
                scripts::ea_nginx::cache_config( {}, "ipman", "--reset" );
            };

            is( $ti{config_called}, 1 );
        };

        it "should just set enabled as true for system" => sub {
            trap {
                scripts::ea_nginx::cache_config( {}, "--system", "--enabled=1" );
            };

            # load the file, it should match the caching_defaults
            my $file      = $scripts::ea_nginx::cache_file;
            my $from_file = eval { Cpanel::JSON::LoadFile($file) } || {};

            my %expected = ( enabled => JSON::PP::true() );

            cmp_deeply( $from_file, \%expected );
        };

        it "should just set enabled as false for system" => sub {
            trap {
                scripts::ea_nginx::cache_config( {}, "--system", "--enabled=0" );
            };

            # load the file, it should match the caching_defaults
            my $file      = $scripts::ea_nginx::cache_file;
            my $from_file = eval { Cpanel::JSON::LoadFile($file) } || {};

            my %expected = ( enabled => JSON::PP::false() );
            cmp_deeply( $from_file, \%expected );
        };

    };

    describe "ensure_valid_nginx_config" => sub {
        around {
            no warnings 'redefine';
            local *scripts::ea_nginx::_get_nginx_bin = sub { return '/usr/sbin/nginx' };

            my $mock_io_callback = Test::MockModule->new('IO::Callback');
            $mock_io_callback->redefine( new => sub { } );

            yield;
        };

        it "should return if it does not discover any syntax errors in the nginx config" => sub {
            my $mock_cpanel_saferun_object = Test::MockModule->new('Cpanel::SafeRun::Object');
            $mock_cpanel_saferun_object->redefine(
                new         => sub { return bless {}, shift; },
                CHILD_ERROR => sub { },
            );

            lives_ok { scripts::ea_nginx::ensure_valid_nginx_config() };
        };

        it "should die if the nginx configuration has a syntax error that it can not resolve" => sub {
            my $mock_cpanel_saferun_object = Test::MockModule->new('Cpanel::SafeRun::Object');
            $mock_cpanel_saferun_object->redefine(
                new         => sub { return bless {}, shift; },
                CHILD_ERROR => sub { return 1; }
            );

            no warnings 'redefine';
            local *scripts::ea_nginx::_attempt_to_fix_syntax_errors = sub { return 0; };
            use warnings;

            dies_ok { scripts::ea_nginx::ensure_valid_nginx_config() };
        };
    };

    describe "_update_for_custom_configs" => sub {
        my $mock_dir;

        around {
            $mock_dir = File::Temp->newdir();

            no warnings 'redefine';
            local *scripts::ea_nginx::_update_for_custom_configs = $orig__update_for_custom_configs;

            local $scripts::ea_nginx::custom_settings_dir = $mock_dir . '/var';
            local $scripts::ea_nginx::etc_ea_nginx        = $mock_dir . '/etc';
            local $scripts::ea_nginx::settings_file       = $scripts::ea_nginx::etc_ea_nginx . '/settings.json';
            local $scripts::ea_nginx::cache_file          = $scripts::ea_nginx::etc_ea_nginx . '/cache.json';

            mkdir $scripts::ea_nginx::custom_settings_dir;
            mkdir $scripts::ea_nginx::etc_ea_nginx;

            yield;
        };

        my $called;
        before each => sub { $called = 0; };

        it 'should call _update_nginx_settings_config_file()' => sub {
            no warnings 'redefine';
            local *scripts::ea_nginx::_update_nginx_settings_config_file = sub { $called++; };
            local *scripts::ea_nginx::_update_nginx_cache_config_file    = sub { };
            use warnings 'redefine';

            scripts::ea_nginx::_update_for_custom_configs();
            is( $called, 1 );
        };

        it 'should call _update_nginx_cache_config_file()' => sub {
            no warnings 'redefine';
            local *scripts::ea_nginx::_update_nginx_settings_config_file = sub { };
            local *scripts::ea_nginx::_update_nginx_cache_config_file    = sub { $called++; };
            use warnings 'redefine';

            scripts::ea_nginx::_update_for_custom_configs();
            is( $called, 1 );
        };

        describe '_update_nginx_settings_config_file' => sub {
            around {
                no warnings 'once';
                open( my $fh, '>', $scripts::ea_nginx::settings_file );
                print $fh q[{"foo":"bar","apache_port":81,"apache_ssl_port":444,"apache_port_ip":1234,"apache_ssl_port_ip":4321}];
                close $fh;
                yield;
            };

            before each => sub { no warnings 'once'; $scripts::ea_nginx::settings_hr = undef; };

            it 'should not call _write_json if ‘/var/nginx/ea-nginx/settings.json’ does not exist' => sub {
                no warnings 'redefine';
                local *scripts::ea_nginx::_write_json = sub { $called++; };
                use warnings 'redefine';

                scripts::ea_nginx::_update_nginx_settings_config_file();
                is( $called, 0 );
            };

            it 'should should merge the contents of ‘/var/nginx/ea-nginx/settings.json’ into ‘/etc/nginx/ea-nginx/settings.json’ if it exists' => sub {
                open( my $fh, '>', $scripts::ea_nginx::custom_settings_dir . '/settings.json' );
                print $fh q[{"finn":"quinn"}];
                close $fh;

                scripts::ea_nginx::_update_nginx_settings_config_file();
                my $after = Cpanel::JSON::LoadFile("$scripts::ea_nginx::etc_ea_nginx/settings.json");
                cmp_deeply(
                    $after,
                    {
                        apache_port        => 81,
                        apache_port_ip     => 1234,
                        apache_ssl_port    => 444,
                        apache_ssl_port_ip => 4321,
                        finn               => 'quinn',
                    },
                ) or diag explain $after;
            };

            it 'should NOT allow apache_port or apache_ssl_port to be overwritten' => sub {
                open( my $fh, '>', $scripts::ea_nginx::custom_settings_dir . '/settings.json' );
                print $fh q[{"finn":"quinn","apache_port":3306,"apache_ssl_port":22}];
                close $fh;

                scripts::ea_nginx::_update_nginx_settings_config_file();
                my $after = Cpanel::JSON::LoadFile("$scripts::ea_nginx::etc_ea_nginx/settings.json");
                cmp_deeply(
                    $after,
                    {
                        apache_port        => 81,
                        apache_port_ip     => 1234,
                        apache_ssl_port    => 444,
                        apache_ssl_port_ip => 4321,
                        finn               => 'quinn',
                    },
                ) or diag explain $after;
            };
        };

        describe '_update_nginx_cache_config_file' => sub {
            around {
                no warnings 'once';
                open( my $fh, '>', $scripts::ea_nginx::cache_file );
                print $fh "foo bar";
                close $fh;
                yield;
            };

            it 'should NOT overwrite ‘/etc/nginx/ea-nginx/cache.json’ if ‘/var/nginx/ea-nginx/cache.json’ does NOT exist' => sub {
                scripts::ea_nginx::_update_nginx_cache_config_file();
                my $contents = Cpanel::LoadFile::load_if_exists($scripts::ea_nginx::cache_file);
                is( $contents, "foo bar" );
            };

            it 'should overwrite ‘/etc/nginx/ea-nginx/cache.json’ if ‘/var/nginx/ea-nginx/cache.json’ does exists' => sub {
                open( my $fh, '>', $scripts::ea_nginx::custom_settings_dir . '/cache.json' );
                print $fh "customized stuff";
                close $fh;

                scripts::ea_nginx::_update_nginx_cache_config_file();
                my $contents = Cpanel::LoadFile::load_if_exists($scripts::ea_nginx::cache_file);
                is( $contents, "customized stuff" );
            };
        };
    };
};

runtests unless caller;
