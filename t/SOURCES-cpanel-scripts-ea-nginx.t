#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/SOURCES-cpanel-scripts-ea-nginx.t     Copyright 2020 cPanel, L.L.C.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

## no critic qw(TestingAndDebugging::RequireUseStrict TestingAndDebugging::RequireUseWarnings)
use Test::Spec;    # automatically turns on strict and warnings

use FindBin;
use File::Glob ();

use File::Temp;
use Path::Tiny;

use Cpanel::Config::userdata::Load ();

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
use Test::MockFile   ();

my ( @_write_user_conf, @_reload );
my $orig__write_user_conf        = \&scripts::ea_nginx::_write_user_conf;
my $orig__reload                 = \&scripts::ea_nginx::_reload;
my $orig__do_other_global_config = \&scripts::ea_nginx::_do_other_global_config;

no warnings "redefine";
*scripts::ea_nginx::_write_user_conf        = sub { push @_write_user_conf, [@_] };
*scripts::ea_nginx::_do_other_global_config = sub { };
*scripts::ea_nginx::_reload                 = sub { push @_reload, [@_] };
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
        local $ENV{"scripts::ea_nginx::bail_die"}         = 1;
        local *scripts::ea_nginx::_write_global_logging   = sub { };
        local *scripts::ea_nginx::_write_global_passenger = sub { };
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
                local *File::Glob::bsd_glob                      = sub { return @glob_res };    # necessary because https://github.com/CpanelInc/Test-MockFile/issues/40
                local *scripts::ea_nginx::_write_global_ea_nginx = sub { };
                yield;
            };
            it_should_behave_like "any sub command that takes a cpanel user";

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
                my $mock     = Test::MockFile->dir( '/etc/nginx/conf.d/users/', ["iamnomore$$.conf"] );
                my $mockfile = Test::MockFile->file( "/etc/nginx/conf.d/users/iamnomore$$.conf", "i am conf hear me rawr" );
                local @glob_res = ("/etc/nginx/conf.d/users/iamnomore$$.conf");
                modulino_run_trap( config => "--all" );
                ok !-e $mockfile->filename;
            };

            it "should not do user config given --global" => sub {
                my $mock     = Test::MockFile->dir( '/etc/nginx/conf.d/users/', ["iamnomore$$.conf"] );
                my $mockfile = Test::MockFile->file( "/etc/nginx/conf.d/users/iamnomore$$.conf", "i am conf hear me rawr" );
                modulino_run_trap( config => "--global" );
                ok -e $mockfile->filename;
            };

            it "should do /etc/nginx/ea-nginx/config-scripts/global/ given --global" => sub {
                my $mock     = Test::MockFile->dir( '/etc/nginx/ea-nginx/config-scripts/global/', ["$$.ima.script"] );
                my $mockfile = Test::MockFile->file( "/etc/nginx/ea-nginx/config-scripts/global/$$.ima.script", "i am script hear me rawr", { mode => 0755 } );
                local @glob_res = ("/etc/nginx/ea-nginx/config-scripts/global/$$.ima.script");
                no warnings "redefine";
                local *scripts::ea_nginx::_do_other_global_config = $orig__do_other_global_config;
                modulino_run_trap( config => "--global" );
                like $trap->stdout, qr{Running \(global\) “/etc/nginx/ea-nginx/config-scripts/global/$$\.ima\.script” …};
            };

            it "should do /etc/nginx/ea-nginx/config-scripts/global/ given --all" => sub {
                my $mock     = Test::MockFile->dir( '/etc/nginx/ea-nginx/config-scripts/global/', ["$$.ima.script"] );
                my $mockfile = Test::MockFile->file( "/etc/nginx/ea-nginx/config-scripts/global/$$.ima.script", "i am script hear me rawr", { mode => 0755 } );
                local @glob_res = ("/etc/nginx/ea-nginx/config-scripts/global/$$.ima.script");
                no warnings "redefine";
                local *scripts::ea_nginx::_do_other_global_config = $orig__do_other_global_config;
                modulino_run_trap( config => "--all" );
                like $trap->stdout, qr{Running \(global\) “/etc/nginx/ea-nginx/config-scripts/global/$$\.ima\.script” …};
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

            describe "cPanel Password protected directories" => sub { it "should be tested" };

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
                yield;
            };
            it_should_behave_like "any sub command that takes a cpanel user";

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
                        is_deeply $system_calls, [ ['/usr/local/cpanel/scripts/restartsrv_nginx reload'], ['/usr/local/cpanel/scripts/restartsrv_nginx reload'] ];
                        is $trap->exit, 1;
                    };

                    it "should restart again (exit clean on success)" => sub {
                        my $rv = 1;
                        local $current_system = sub { push @{$system_calls}, [@_]; $rv-- };
                        my $mock = Test::MockFile->file( "/etc/nginx/conf.d/users/derp$$.conf", "oh hai" );
                        trap { scripts::ea_nginx::_reload( $mock->filename ) };
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

        describe "_delete_glob" => sub { it "should be tested" };
    };

    describe "cache_config" => sub {
        share my %ti;

        around {
            local $ti{temp_dir} = File::Temp->newdir();

            local $scripts::ea_nginx::var_cpanel_userdata = $ti{temp_dir} . "/userdata";
            local $scripts::ea_nginx::etc_nginx           = $ti{temp_dir} . "/etc_nginx";

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

            is(
                $trap->stdout, q/{}
/
            );
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
            my $file      = $scripts::ea_nginx::etc_nginx . "/ea-nginx/cache.json";
            my $from_file = eval { Cpanel::JSON::LoadFile($file) } || {};

            my %expected = scripts::ea_nginx::caching_defaults();
            scripts::ea_nginx::_jsonify_caching_booleans( \%expected );

            cmp_deeply( $from_file, \%expected );
        };

        it "should user file should be deleted if user passed on reset" => sub {
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
            my $file = $scripts::ea_nginx::var_cpanel_userdata . "/ipman/nginx-cache.json";
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
            my $file      = $scripts::ea_nginx::etc_nginx . "/ea-nginx/cache.json";
            my $from_file = eval { Cpanel::JSON::LoadFile($file) } || {};

            my %expected = ( enabled => JSON::PP::true() );

            cmp_deeply( $from_file, \%expected );
        };

        it "should just set enabled as false for system" => sub {
            trap {
                scripts::ea_nginx::cache_config( {}, "--system", "--enabled=0" );
            };

            # load the file, it should match the caching_defaults
            my $file      = $scripts::ea_nginx::etc_nginx . "/ea-nginx/cache.json";
            my $from_file = eval { Cpanel::JSON::LoadFile($file) } || {};

            my %expected = ( enabled => JSON::PP::false() );

            cmp_deeply( $from_file, \%expected );
        };

    };
};

runtests unless caller;
