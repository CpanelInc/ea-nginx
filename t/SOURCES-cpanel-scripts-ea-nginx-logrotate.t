#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/SOURCES-cpanel-scripts-ea-nginx-logrotate.t
#                                                  Copyright 2020 cPanel, L.L.C.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

## no critic qw(TestingAndDebugging::RequireUseStrict TestingAndDebugging::RequireUseWarnings)
use Test::Spec;    # automatically turns on strict and warnings

use FindBin;

use Path::Tiny ();

require "$FindBin::Bin/../SOURCES/cpanel-scripts-ea-nginx-logrotate";
scripts::ea_nginx::logrotate::_load_logrotate_class();    # will go away once we do split this out per the TODO comment (ZC-6949) in the function

our @std_process_stats_log;
our @std_process_bytes_log;
describe "ea-nginx-logrotate script" => sub {
    around {
        no warnings "redefine", "once";

        # will go away once we do split this out per the TODO comment (ZC-6949) in the funtion
        local *scripts::ea_nginx::logrotate::_load_logrotate_class = sub { 1 };
        local *Cpanel::Logrotate::File::std_process_stats_log      = sub { push @std_process_stats_log, shift->path };
        local *Cpanel::Logrotate::File::std_process_bytes_log      = sub { push @std_process_bytes_log, shift->path };
        yield;
    };

    describe "given a bytes file" => sub {
        around {
            local @std_process_bytes_log = ();
            local @std_process_stats_log = ();
            yield;
        };

        it "should do standard bytes processing" => sub {
            scripts::ea_nginx::logrotate::run("/$$/example.tld-bytes_log.1");
            is_deeply \@std_process_bytes_log, ["/$$/example.tld-bytes_log.1"];
        };
    };

    describe "under piped logging" => sub {
        around {
            local @std_process_bytes_log = ();
            local @std_process_stats_log = ();
            no warnings "redefine";
            local *Cpanel::Logrotate::File::piped_logging_enabled = sub { 1 };
            yield;
        };

        it "should do standard processing w/ non-SSL file" => sub {
            scripts::ea_nginx::logrotate::run("/$$/example.tld.1");
            is_deeply \@std_process_stats_log, ["/$$/example.tld.1"];
        };

        it "should do standard processing w/ SSL file" => sub {
            scripts::ea_nginx::logrotate::run("/$$/example.tld-ssl_log.1");
            is_deeply \@std_process_stats_log, ["/$$/example.tld-ssl_log.1"];
        };
    };

    describe "under normal logging" => sub {
        around {
            local @std_process_bytes_log = ();
            local @std_process_stats_log = ();
            no warnings "redefine";
            local *Cpanel::Logrotate::File::piped_logging_enabled = sub { 0 };
            yield;
        };

        describe "w/ non-SSL file" => sub {
            it "should do standard processing on SSL and non-SSL" => sub {
                my $dir = Path::Tiny::tempdir();
                Path::Tiny::path("$dir/example.tld.1")->spew("");
                scripts::ea_nginx::logrotate::run("$dir/example.tld.1");
                is_deeply \@std_process_stats_log, [ "$dir/example.tld-ssl_log.1", "$dir/example.tld.1" ];
            };

            it "should create an SSL log using the :443 column w/out the :443 column" => sub {
                my $dir = Path::Tiny::tempdir();
                Path::Tiny::path("$dir/example.tld.1")->spew("example.tld:80 80 1\nexample.tld:443 443 1\nexample.tld:80 80 2\nexample.tld:443 443 2\n");
                scripts::ea_nginx::logrotate::run("$dir/example.tld.1");
                is Path::Tiny::path("$dir/example.tld-ssl_log.1")->slurp, "443 1\n443 2\n";
            };

            it "should remove the SSL entries and :80 column" => sub {
                my $dir = Path::Tiny::tempdir();
                Path::Tiny::path("$dir/example.tld.1")->spew("example.tld:80 80 1\nexample.tld:443 443 1\nexample.tld:80 80 2\nexample.tld:443 443 2\n");
                scripts::ea_nginx::logrotate::run("$dir/example.tld.1");
                is Path::Tiny::path("$dir/example.tld.1")->slurp, "80 1\n80 2\n";
            };
        };

        it "should do standard processing w/ SSL file" => sub {
            scripts::ea_nginx::logrotate::run("/$$/example.tld-ssl_log.1");
            is_deeply \@std_process_stats_log, ["/$$/example.tld-ssl_log.1"];
        };
    };
};

runtests unless caller;
