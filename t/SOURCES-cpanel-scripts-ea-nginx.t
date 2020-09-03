#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/SOURCES-cpanel-scripts-ea-nginx.t     Copyright 2020 cPanel, L.L.C.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

## no critic qw(TestingAndDebugging::RequireUseStrict TestingAndDebugging::RequireUseWarnings)
use Test::Spec;    # automatically turns on strict and warnings

use FindBin;
use File::Glob ();

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
                local *File::Glob::bsd_glob = sub { return @glob_res };    # necessary because https://github.com/CpanelInc/Test-MockFile/issues/40
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
};

runtests unless caller;
