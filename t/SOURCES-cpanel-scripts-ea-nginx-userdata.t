#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/SOURCES-cpanel-scripts-ea-nginx-userdata.t
#                                                  Copyright 2019 cPanel, L.L.C.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

## no critic qw(TestingAndDebugging::RequireUseStrict TestingAndDebugging::RequireUseWarnings)
use Test::Spec;    # automatically turns on strict and warnings
no warnings;

use FindBin;
use File::Glob ();
use Path::Tiny ();

my %conf = (
    require => "$FindBin::Bin/../SOURCES/cpanel-scripts-ea-nginx-userdata",
    package => "scripts::ea_nginx_userdata",
);
require $conf{require};

use Test::MockModule;

my ( $var_cpanel_userdata, $vcu_cpuser_dir, $feature_file, $home, $homedir, $homedir_len, %mtimes, @passwds, $version, $loaduserdomains, $cpuser );

no warnings 'redefine';

describe "ea-nginx-userdata script" => sub {

    # NOTE: for change review, I wanted to use the shared examples in the
    # cpanel-scripts-ea-nginx test but the calling architecture is different
    # so I could not use them. Remove after change review.

    describe "as a modulino accepting a user as an argument," => sub {
        around {
            local *scripts::ea_nginx_userdata::_do_feature = sub {
                my (@args) = @_;
                return;
            };

            yield;
        };

        it "should die when not given a user" => sub {
            modulino_run_trap();
            like $trap->die, qr/The user argument is missing/;
        };

        it "should error out when given undef user" => sub {
            modulino_run_trap(undef);
            like $trap->die, qr/The user argument is missing/;
        };

        it "should error out when given empty user" => sub {
            modulino_run_trap("");
            like $trap->die, qr/The user argument is missing/;
        };

        it "should error out when given non-existant user" => sub {
            modulino_run_trap("nonuser-$$");
            like $trap->die, qr/The given user is not a cPanel user/;
        };

        it "should error out when given non-cpanel user" => sub {
            modulino_run_trap("nobody");
            like $trap->die, qr/The given user is not a cPanel user/;
        };

        it "should allow cpanel user" => sub {
            modulino_run_trap("cpuser$$");
            like $trap->stdout, qr/Processing $cpuser/;
        };

        it "should return 0 when passed --help" => sub {
            my $ret = modulino_run_trap('--help');
            is $ret, 0;
        };

        it "should display a help message when passed --help" => sub {
            modulino_run_trap('--help');
            like $trap->{'stdout'}, qr/This script will ensure certain userdata is up to date/;
        };

        it "should return 1 when unknown arguments are passed" => sub {
            my $ret = modulino_run_trap( "cpuser$$", 'gobblyde', 'gook' );
            is $ret, 1;
        };

        it "should display a help message when unknown arguments are passed" => sub {
            modulino_run_trap( "cpuser$$", 'gobblyde', 'gook' );
            like $trap->{'stdout'}, qr/This script will ensure certain userdata is up to date/;
        };

        it "should warn when unknown arguments are passed" => sub {
            modulino_run_trap( "cpuser$$", 'gobblyde', 'gook' );
            like $trap->{'stderr'}, qr/Unknown arguments/;
        };
    };
};

describe "ea-nginx-userdata " => sub {
    around {
        no warnings 'once';
        local $scripts::ea_nginx_userdata::current_cpanel_version = '82';

        yield;
    };

    describe "helper function _do_feature" => sub {
        describe "when not_applicable_as_of_cpanel_version is not set" => sub {
            it "should call the code ref" => sub {
                my $called_me = 0;
                trap {
                    scripts::ea_nginx_userdata::_do_feature( "MyLabelV1.0", sub { $called_me++; return; } );
                };
                is $called_me, 1;
            };

            it "should display the label" => sub {
                my $called_me = 0;
                trap {
                    scripts::ea_nginx_userdata::_do_feature( "MyLabelV1.0", sub { $called_me++; return; } );
                };
                like $trap->{'stdout'}, qr/MyLabelV1\.0/;
            };
        };

        describe "when not_applicable_as_of_cpanel_version is undef" => sub {
            it "should call the code ref" => sub {
                my $called_me = 0;
                trap {
                    scripts::ea_nginx_userdata::_do_feature( "MyLabelV1.0", sub { $called_me++; return; }, 'not_applicable_as_of_cpanel_version' => undef );
                };
                is $called_me, 1;
            };

            it "should display the label" => sub {
                my $called_me = 0;
                trap {
                    scripts::ea_nginx_userdata::_do_feature( "MyLabelV1.0", sub { $called_me++; return; }, 'not_applicable_as_of_cpanel_version' => undef );
                };
                like $trap->{'stdout'}, qr/MyLabelV1\.0/;
            };
        };

        describe "when not_applicable_as_of_cpanel_version is below current version" => sub {
            it "should NOT call the code ref" => sub {
                my $called_me = 0;
                trap {
                    scripts::ea_nginx_userdata::_do_feature( "MyLabelV1.0", sub { $called_me++; return; }, 'not_applicable_as_of_cpanel_version' => '80' );
                };
                is $called_me, 0;
            };

            it "should display the label" => sub {
                my $called_me = 0;
                trap {
                    scripts::ea_nginx_userdata::_do_feature( "MyLabelV1.0", sub { $called_me++; return; }, 'not_applicable_as_of_cpanel_version' => '80' );
                };
                like $trap->{'stdout'}, qr/MyLabelV1\.0/;
            };
        };

        describe "when not_applicable_as_of_cpanel_version is at current version" => sub {
            it "should NOT call the code ref" => sub {
                my $called_me = 0;
                trap {
                    scripts::ea_nginx_userdata::_do_feature( "MyLabelV1.0", sub { $called_me++; return; }, 'not_applicable_as_of_cpanel_version' => '82' );
                };
                is $called_me, 0;
            };

            it "should display the label" => sub {
                my $called_me = 0;
                trap {
                    scripts::ea_nginx_userdata::_do_feature( "MyLabelV1.0", sub { $called_me++; return; }, 'not_applicable_as_of_cpanel_version' => '82' );
                };
                like $trap->{'stdout'}, qr/MyLabelV1\.0/;
            };
        };

        describe "when not_applicable_as_of_cpanel_version is after version" => sub {
            it "should NOT call the code ref" => sub {
                my $called_me = 0;
                trap {
                    scripts::ea_nginx_userdata::_do_feature( "MyLabelV1.0", sub { $called_me++; return; }, 'not_applicable_as_of_cpanel_version' => '84' );
                };
                is $called_me, 1;
            };

            it "should display the label" => sub {
                my $called_me = 0;
                trap {
                    scripts::ea_nginx_userdata::_do_feature( "MyLabelV1.0", sub { $called_me++; return; }, 'not_applicable_as_of_cpanel_version' => '84' );
                };
                like $trap->{'stdout'}, qr/MyLabelV1\.0/;
            };
        };
    };

    describe "helper function _help" => sub {
        it "should return a help message" => sub {
            my $ret;
            trap {
                $ret = scripts::ea_nginx_userdata::_help();
            };

            like $ret, qr/This script will ensure certain userdata/;
        };
    };

    describe "helper function" => sub {
        describe "_get_cur_userdata" => sub {
            around {
                local $scripts::ea_nginx_userdata::var_cpanel_userdata = $var_cpanel_userdata;
                unlink $feature_file if -e $feature_file;
                yield;
            };

            it "should return empty hashref if user feature file does not exist" => sub {
                my $ref;
                trap {
                    $ref = scripts::ea_nginx_userdata::_get_cur_userdata( $cpuser, 'feature' );
                };
                cmp_deeply $ref, {};
            };

            it "should return hashref if user feature file exists" => sub {
                Path::Tiny::path($feature_file)->spew(qq/{ "howdy": 1, "there": 2 }/);

                my $ref;
                trap {
                    $ref = scripts::ea_nginx_userdata::_get_cur_userdata( $cpuser, 'feature' );
                };

                cmp_deeply $ref, { 'howdy' => 1, 'there' => 2 };
            };
        };

        describe "_write_userdata" => sub {
            around {
                local $scripts::ea_nginx_userdata::var_cpanel_userdata = $var_cpanel_userdata;
                unlink $feature_file if -e $feature_file;
                yield;
            };

            it "should return 1 when outputting the data" => sub {
                my $ref = { 'howdy' => 1, 'there' => 2 };
                my $ret;
                trap {
                    $ret = scripts::ea_nginx_userdata::_write_userdata( $cpuser, 'feature', $ref );
                };

                is( $ret, 1 );
            };

            it "should output the data" => sub {
                my $ref = { 'howdy' => 1, 'there' => 2 };
                my $outref;
                my $ret;
                trap {
                    $ret = scripts::ea_nginx_userdata::_write_userdata( $cpuser, 'feature', $ref );
                    $outref = scripts::ea_nginx_userdata::_get_cur_userdata( $cpuser, 'feature' );
                };

                cmp_deeply( $outref, $ref );
            };

            describe " " => sub {
                around {
                    my $file_json = Test::MockModule->new('Cpanel::Transaction::File::JSON');
                    $file_json->redefine(
                        'new',
                        sub {
                            my (@args) = @_;
                            my $self = {};
                            bless $self, 'Cpanel::Transaction::File::JSON';
                            return $self;
                        }
                    );

                    $file_json->redefine(
                        'set_data',
                        sub {
                            my (@args) = @_;
                            die 'hard with a vengence';
                        }
                    );

                    yield;
                };

                it "should return undef when JSON output fails" => sub {
                    my $ref = { 'howdy' => 1, 'there' => 2 };
                    my $ret;
                    trap {
                        $ret = scripts::ea_nginx_userdata::_write_userdata( $cpuser, 'feature', $ref );
                    };

                    is( $ret, undef );
                };

                it "should warn when JSON output fails" => sub {
                    my $ref = { 'howdy' => 1, 'there' => 2 };
                    my $ret;
                    trap {
                        $ret = scripts::ea_nginx_userdata::_write_userdata( $cpuser, 'feature', $ref );
                    };

                    like $trap->{'stderr'}, qr/with a vengence/;
                };
            };
        };
    };
};

describe "ea-nginx-userdata::_do_cpanel_password_protected_directories" => sub {
    share my %mi;

    around {
        local $scripts::ea_nginx_userdata::var_cpanel_userdata = $var_cpanel_userdata;
        unlink $feature_file if -e $feature_file;

        local *scripts::ea_nginx_userdata::_write_userdata = sub {
            my ( $user, $feature, $conf ) = @_;

            $mi{'conf'} = $conf;

            return 1;
        };

        yield;
    };

    it "should generate a clean hashref when no data currently exists" => sub {
        local *scripts::ea_nginx_userdata::_get_cur_userdata = sub {
            my ( $user, $feature ) = @_;

            return {};
        };

        my $ret = scripts::ea_nginx_userdata::_do_cpanel_password_protected_directories( $cpuser, $homedir );

        my $expected_ref = {
            '/subdir2/subdir3/subdir4/subdir5' => {
                'realm_name'      => 'Billy',
                '_htaccess_mtime' => $mtimes{'/subdir2/subdir3/subdir4/subdir5/.htaccess'},
            },
            '/subdir2/subdir3' => {
                '_htaccess_mtime' => $mtimes{'/subdir2/subdir3/.htaccess'},
                'realm_name'      => 'Billy',
            },
            '/subdir1' => {
                'realm_name'      => 'Billy',
                '_htaccess_mtime' => $mtimes{'/subdir1/.htaccess'},
            }
        };

        cmp_deeply( $mi{'conf'}, $expected_ref );
    };

    it "should generate a clean hashref when all the data currently exists" => sub {
        local *scripts::ea_nginx_userdata::_get_cur_userdata = sub {
            my ( $user, $feature ) = @_;

            my $ref = {
                '/subdir2/subdir3/subdir4/subdir5' => {
                    'realm_name'      => 'Billy',
                    '_htaccess_mtime' => $mtimes{'/subdir2/subdir3/subdir4/subdir5/.htaccess'},
                },
                '/subdir2/subdir3' => {
                    '_htaccess_mtime' => $mtimes{'/subdir2/subdir3/.htaccess'},
                    'realm_name'      => 'Billy',
                },
                '/subdir1' => {
                    'realm_name'      => 'Billy',
                    '_htaccess_mtime' => $mtimes{'/subdir1/.htaccess'},
                }
            };

            return $ref;
        };

        my $ret = scripts::ea_nginx_userdata::_do_cpanel_password_protected_directories( $cpuser, $homedir );

        my $expected_ref = {
            '/subdir2/subdir3/subdir4/subdir5' => {
                'realm_name'      => 'Billy',
                '_htaccess_mtime' => $mtimes{'/subdir2/subdir3/subdir4/subdir5/.htaccess'},
            },
            '/subdir2/subdir3' => {
                '_htaccess_mtime' => $mtimes{'/subdir2/subdir3/.htaccess'},
                'realm_name'      => 'Billy',
            },
            '/subdir1' => {
                'realm_name'      => 'Billy',
                '_htaccess_mtime' => $mtimes{'/subdir1/.htaccess'},
            }
        };

        cmp_deeply( $mi{'conf'}, $expected_ref );
    };

    it "should adjust mtimes in hashref when all the data currently exists" => sub {
        local *scripts::ea_nginx_userdata::_get_cur_userdata = sub {
            my ( $user, $feature ) = @_;

            my $ref = {
                '/subdir2/subdir3/subdir4/subdir5' => {
                    'realm_name'      => 'Billy',
                    '_htaccess_mtime' => $mtimes{'/subdir2/subdir3/subdir4/subdir5/.htaccess'} - 10,
                },
                '/subdir2/subdir3' => {
                    '_htaccess_mtime' => $mtimes{'/subdir2/subdir3/.htaccess'} - 10,
                    'realm_name'      => 'Billy',
                },
                '/subdir1' => {
                    'realm_name'      => 'Billy',
                    '_htaccess_mtime' => $mtimes{'/subdir1/.htaccess'} - 10,
                }
            };

            return $ref;
        };

        my $ret = scripts::ea_nginx_userdata::_do_cpanel_password_protected_directories( $cpuser, $homedir );

        my $expected_ref = {
            '/subdir2/subdir3/subdir4/subdir5' => {
                'realm_name'      => 'Billy',
                '_htaccess_mtime' => $mtimes{'/subdir2/subdir3/subdir4/subdir5/.htaccess'},
            },
            '/subdir2/subdir3' => {
                '_htaccess_mtime' => $mtimes{'/subdir2/subdir3/.htaccess'},
                'realm_name'      => 'Billy',
            },
            '/subdir1' => {
                'realm_name'      => 'Billy',
                '_htaccess_mtime' => $mtimes{'/subdir1/.htaccess'},
            }
        };

        cmp_deeply( $mi{'conf'}, $expected_ref );
    };

    it "should properly deal with removed htaccess files" => sub {
        local *scripts::ea_nginx_userdata::_get_cur_userdata = sub {
            my ( $user, $feature ) = @_;

            my $ref = {
                '/subdir2/subdir3/subdir4' => {
                    'realm_name'      => 'Billy',
                    '_htaccess_mtime' => $mtimes{'/subdir2/subdir3/subdir4/subdir5/.htaccess'},
                },
                '/subdir2/subdir3/subdir4/subdir5' => {
                    'realm_name'      => 'Billy',
                    '_htaccess_mtime' => $mtimes{'/subdir2/subdir3/subdir4/subdir5/.htaccess'} - 10,
                },
                '/subdir2/subdir3' => {
                    '_htaccess_mtime' => $mtimes{'/subdir2/subdir3/.htaccess'} - 10,
                    'realm_name'      => 'Billy',
                },
                '/subdir1' => {
                    'realm_name'      => 'Billy',
                    '_htaccess_mtime' => $mtimes{'/subdir1/.htaccess'} - 10,
                }
            };

            return $ref;
        };

        my $ret = scripts::ea_nginx_userdata::_do_cpanel_password_protected_directories( $cpuser, $homedir );

        my $expected_ref = {
            '/subdir2/subdir3/subdir4/subdir5' => {
                'realm_name'      => 'Billy',
                '_htaccess_mtime' => $mtimes{'/subdir2/subdir3/subdir4/subdir5/.htaccess'},
            },
            '/subdir2/subdir3' => {
                '_htaccess_mtime' => $mtimes{'/subdir2/subdir3/.htaccess'},
                'realm_name'      => 'Billy',
            },
            '/subdir1' => {
                'realm_name'      => 'Billy',
                '_htaccess_mtime' => $mtimes{'/subdir1/.htaccess'},
            }
        };

        cmp_deeply( $mi{'conf'}, $expected_ref );
    };
};

######################################################################
# BEGIN TEST SETUP
######################################################################

$version = Test::MockModule->new('Cpanel::Version');
$version->redefine(
    'get_short_release_number',
    sub {
        my (@args) = @_;
        return '82';
    }
);

$cpuser = "cpuser$$";

$loaduserdomains = Test::MockModule->new('Cpanel::Config::LoadUserDomains');
$loaduserdomains->redefine(
    'loaduserdomains',
    sub {
        my (@args) = @_;
        return { "$cpuser" => 1 };
    }
);

$var_cpanel_userdata = File::Temp->newdir();
$vcu_cpuser_dir      = $var_cpanel_userdata . "/$cpuser";
$feature_file        = $vcu_cpuser_dir . '/feature.json';

Path::Tiny::path($vcu_cpuser_dir)->mkpath;

# /home/cpuser .htpasswd stuff

$home    = File::Temp->newdir();
$homedir = $home . '/' . $cpuser;

Path::Tiny::path($homedir)->mkpath;

# put the .htpasswd stuff in place

@passwds = qw(
  passwd
  subdir1/passwd
  subdir2/subdir3/passwd
  subdir2/subdir3/subdir4/subdir5/passwd
);

$homedir_len = length($homedir);

foreach my $passwd (@passwds) {
    my $passwd_file = $homedir . '/.htpasswds/' . $passwd;
    my $dir         = Path::Tiny::path($passwd_file)->parent();
    Path::Tiny::path($dir)->mkpath;
    Path::Tiny::path($passwd_file)->spew('howdy mom');

    if ( $passwd ne 'passwd' ) {
        my $imaginary_file = $homedir . '/' . $passwd;
        my $dir_to_create  = Path::Tiny::path($imaginary_file)->parent();
        my $htaccess       = $dir_to_create . "/.htaccess";
        Path::Tiny::path($dir_to_create)->mkpath;
        Path::Tiny::path($htaccess)->spew(qq{AuthType Basic\nAuthName "Billy"\n});

        my $mtime = ( stat($htaccess) )[9];
        $mtimes{ substr( $htaccess, $homedir_len ) } = $mtime;
    }
}

sub modulino_run_trap {
    my @run_args = @_;

    my $ret = -1;

    trap {
        $ret = scripts::ea_nginx_userdata::run(@run_args);
    };

    return $ret;
}

######################################################################
# END TEST SETUP
######################################################################

runtests unless caller;
