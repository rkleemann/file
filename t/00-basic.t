#! /usr/bin/env perl

use Array::RefElem ();    #qw( hv_store );
use File::Spec     ();
use FindBin        ();    #qw( $Bin );


use Test2::V0;

ok( require filename, "Can require filename module" );
ok( require pm,       "Can require pm module" );

my %core = %INC;
my %file = %INC;
my %inc  = %INC;
my %incs = (
    "CORE::require"     => \%core,
    "filename->require" => \%file,
    "inc"               => \%inc,
);

# This hack is because I need them to report the same error message,
# including filename and line number.
my ( $core, $file ) = do {
    ( my $test = <<'END' ) =~ s/\s+//g;
sub {
    local $_ = shift() if @_;
    _restore_INC('require');
    my $return = eval { require };
    _save_INC('require');
    die $@ if $@;
    return $return;
}
END
    eval( join(
        ",",
        map { ( my $sub = $test ) =~ s/require/$_/g; $sub } qw(
            CORE::require
            filename->require
        )
    ) );
};

sub _save_INC {
    @_ = ("inc") unless @_;
    local $_;
    %{ $incs{$_} } = %INC foreach @_;
}
sub _restore_INC {
    %INC = %{ $incs{ shift() // "inc" } };
    local $_;
    Array::RefElem::hv_store( %INC, $_, undef )
        foreach grep { not defined $INC{$_} } keys %INC;
    return %INC;
}

foreach my $inc ( $FindBin::Bin ) {
    note "\@INC now includes ", $inc;
    local @INC = ( $inc );

    foreach my $prefix ( "", $FindBin::Bin ) {

        # Tests with good files
        foreach my $pm (qw( good symlink )) {
            my $filename = sprintf( "Testing-%s.pm", $pm );
            my $fullpath = File::Spec->catfile(
                $prefix ? $prefix : $FindBin::Bin,
                $filename
            );
            local $_ = $prefix ? $fullpath : $filename;

            {
                _save_INC(qw( CORE::require filename->require ));

                is( &$file, &$core, "Can require $_" );
                is( \%file, \%core,
                    "%INC is the same for filename and CORE" );
                is( &$file, &$core, "Can re-require $_" );
                is( \%file, \%core,
                    "%INC is still the same for filename and CORE" );

                _restore_INC();
            }

            my $mode = ( stat $fullpath )[2] & 07777
                || die "Cannot stat $fullpath";
            chmod( 00000, $fullpath ) or die "Could not chmod $fullpath: $!";
            SKIP: {
                skip(
                    sprintf(
                        "Cannot change %s permission to non-readable (%05o)",
                        $fullpath,
                        $mode
                    ),
                    7
                ) if ( $mode == ( ( stat $fullpath )[2] & 07777 ) );
                # The mode did not change,
                # and we cannot test on this filesystem

                _save_INC(qw( CORE::require filename->require ));

                my ( $fdie, $cdie ) = ( dies {&$file}, dies {&$core} );
                ok( length($fdie), "file died with message" )
                    || diag(
                        "file died with ",
                        defined($fdie) ? $fdie : "undefined"
                    );
                ok( length($cdie), "core died with message" )
                    || diag(
                        "core died with ",
                        defined($cdie) ? $cdie : "undefined"
                    );
                is( $fdie, $cdie,
                    "Cannot require unreadable $_" );
                is( \%file, \%core,
                    "%INC is the same for filename and CORE" );

                is( exists $INC{$_}, "",
                    "%INC has not been updated for $_" )
                    || diag(
                        "\$INC{$_} is ",
                        defined( $INC{$_} )
                            ? $INC{$_}
                            : "undefined"
                    );
                %file = %core = %INC;

                is( dies {&$file}, dies {&$core},
                    "Trying to re-require an unreadable file fails" );
                is( \%file, \%core,
                    "%INC is the same for filename and CORE" );

                _restore_INC();
            }
            chmod( $mode, $fullpath ) or die "Could not chmod $fullpath: $!";
        }

        # Tests with files that return false
        foreach my $pm (qw(
            empty
            empty-string
            errno
            eval_error
            false
            undef
        )) {
            my $filename = sprintf( "Testing-%s.pm", $pm );
            my $fullpath = File::Spec->catfile(
                $prefix ? $prefix : $FindBin::Bin,
                $filename
            );
            local $_ = $prefix ? $fullpath : $filename;

            {
                _save_INC(qw( CORE::require filename->require ));

                is( dies {&$file}, dies {&$core},
                    "Cannot require $_" );
                is( \%file, \%core,
                    "%INC is the same for filename and CORE" );

                _restore_INC();
            }

            {
                _save_INC(qw( CORE::require filename->require ));

                ok( length( dies { CORE::require } ),
                    "Failed to require $_" );
                is( exists $INC{$_}, "",
                    "%INC has not been updated for $_" )
                    || diag(
                        "\$INC{$_} is ",
                        defined( $INC{$_} )
                            ? $INC{$_}
                            : "undefined"
                    );

                is( dies {&$file}, dies {&$core},
                    "Trying to re-require $_" );
                is( \%file, \%core,
                    "%INC is the same for filename and CORE" );

                _restore_INC();
            }
        }

        # Tests with bad files
        foreach my $pm (qw(
            failure
        )) {
            my $filename = sprintf( "Testing-%s.pm", $pm );
            my $fullpath = File::Spec->catfile(
                $prefix ? $prefix : $FindBin::Bin,
                $filename
            );
            local $_ = $prefix ? $fullpath : $filename;

            {
                _save_INC(qw( CORE::require filename->require ));

                is( dies {&$file}, dies {&$core},
                    "Cannot require $_" );
                is( \%file, \%core,
                    "%INC is the same for filename and CORE" );

                _restore_INC();
            }

            {
                _save_INC(qw( CORE::require filename->require ));

                is( { map { $_ => $INC{$_} } grep /Testing/, keys %INC }, {},
                    "%INC has no Testing" );

                my @expected_errors = (
                    sprintf(
                          "syntax error at %s line 2, at EOF\n"
                        . "Compilation failed in require at %s line %d.\n",
                        $fullpath, __FILE__, __LINE__ + 9
                    ),
                    sprintf(
                          "Attempt to reload %s aborted.\n"
                        . "Compilation failed in require at %s line %d.\n",
                        $_, __FILE__, __LINE__ + 4
                    ),
                );
                for my $expected_error (@expected_errors) {
                    is( dies { CORE::require }, $expected_error,
                        "Failed to require $_" );
                    is( exists $INC{$_}, 1,
                        "%INC has been updated for $_" );
                    is( $INC{$_}, undef,
                        "\$INC{$_} is undef" );
                }
                _save_INC(qw( CORE::require filename->require ));

                is( dies {&$file}, dies {&$core},
                    "Trying to re-require $_" );
                is( \%file, \%core,
                    "%INC is the same for filename and CORE" );

                _restore_INC();
            }
        }
    }
}

done_testing();

