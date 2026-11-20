#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/SOURCES-cpanel-ea-nginx-config-scripts-global-webapp-includes.t
#                                                           All rights Reserved.
# This code is subject to the cPanel license. Unauthorized copying is prohibited

## no critic qw(TestingAndDebugging::RequireUseStrict TestingAndDebugging::RequireUseWarnings)
use Test::Spec;    # automatically turns on strict and warnings

use FindBin;
use File::Path ();
use File::Temp ();

require "$FindBin::Bin/../SOURCES/cpanel/ea-nginx/config-scripts/global/config-scripts-global-webapp-includes";

my $managed = "# Managed by the cPanel webapp plugin for example.com. Do not edit.\nlocation ~ ^/ { proxy_pass http://127.0.0.1:10000; }\n";

sub _write {
    my ( $path, $content ) = @_;
    ( my $dir = $path ) =~ s{/[^/]+$}{};
    File::Path::make_path($dir);
    open my $fh, '>', $path or die "$path: $!";
    print {$fh} $content;
    close $fh;
}

describe "config-scripts-global-webapp-includes" => sub {
    my ( $root, $inc );

    before each => sub {
        $root = File::Temp->newdir();
        $inc  = "$root/etc/nginx/conf.d/users/bob/example.com/webapp.conf";
    };

    describe "in reverse-proxy mode" => sub {
        it "removes a managed include and prunes its empty domain directory" => sub {
            _write( $inc, $managed );
            scripts::ea_nginx_webapp_includes::run("$root");
            ok( !-e $inc,                                               "include removed" );
            ok( !-d "$root/etc/nginx/conf.d/users/bob/example.com", "empty domain dir pruned" );
            ok( -d "$root/etc/nginx/conf.d/users/bob",              "user dir kept" );
        };

        it "leaves an include it did not write alone" => sub {
            _write( $inc, "# my own proxy\nlocation /x { }\n" );
            scripts::ea_nginx_webapp_includes::run("$root");
            ok( -e $inc, "unmanaged include kept" );
        };

        it "keeps the domain directory when it still holds other files" => sub {
            _write( $inc, $managed );
            _write( "$root/etc/nginx/conf.d/users/bob/example.com/other.conf", "# x\n" );
            scripts::ea_nginx_webapp_includes::run("$root");
            ok( !-e $inc, "include removed" );
            ok( -e "$root/etc/nginx/conf.d/users/bob/example.com/other.conf", "other file kept" );
        };
    };

    describe "in standalone mode" => sub {
        it "does not remove managed includes" => sub {
            _write( "$root/etc/nginx/ea-nginx/enable.standalone", "" );
            _write( $inc, $managed );
            scripts::ea_nginx_webapp_includes::run("$root");
            ok( -e $inc, "include kept" );
        };
    };
};

runtests unless caller;
