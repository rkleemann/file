#! /usr/bin/env perl

use FindBin ();

use Test2::V0;

ok( require filename, 'Can require filename module' );
ok( require pm,       'Can require pm module' );

our %inc = %INC;
my %file = %inc;
my %core = %inc;
my %incs = (
    'filename->require' => \%file,
    'CORE::require'     => \%core,
);

# This hack is because I need them to report the same error message,
# including filename and line number.
my ( $file, $core ) = do {
    ( my $test = <<'END' ) =~ s/\s+//g;
sub {
    local %INC = %inc;
    my $return = eval { require };
    %{ $incs{'require'} } = %INC;
    die $@ if $@;
    return $return;
}
END
    eval( join(
        ',',
        map { ( my $sub = $test ) =~ s/require/$_/g; $sub } qw(
            filename->require
            CORE::require
        )
    ) );
};

foreach my $inc ( $FindBin::Bin ) {
    note "\@INC now includes ", $inc;
    local @INC = ( $inc );

    foreach my $prefix ( "", "$FindBin::Bin/" ) {

        # Tests with good files
        foreach my $pm (qw( good symlink )) {
            $_ = my $filename = sprintf( '%sTesting-%s.pm', $prefix, $pm );

            {
                local %INC = %INC;

                is( &$file, &$core, "Can filename->require $filename" );
                is( \%file, \%core,
                    '%INC is the same for filename and CORE' );
            }

            my $statname = ( $prefix ? "" : "$FindBin::Bin/" ) . $filename;
            my $mode = ( stat $statname )[2] & 07777
                || die "Cannot stat $statname";
            chmod( 00000, $statname ) or die "Could not chmod $statname: $!";
            {
                local %INC = %INC;

                is( dies {&$file}, dies {&$core},
                    "Cannot filename->require unreadable $filename" );
                is( \%file, \%core,
                    '%INC is the same for filename and CORE' );
            }

            {
                local %INC = %INC;

                my $expected_error = sprintf(
                    "Can't locate %s:   Permission denied at %s line %d.\n",
                    $filename, __FILE__, __LINE__ + 2
                );
                is( dies { CORE::require($filename) }, $expected_error,
                    "Failed to require $filename" );
                is( exists $INC{$filename}, "",
                    "%INC has not been updated for $filename" )
                    || diag(
                        "\$INC{$filename} is ",
                        defined( $INC{$filename} )
                            ? $INC{$filename}
                            : "undefined"
                    );

                local %inc = %INC;
                is( dies {&$file}, dies {&$core},
                    "Trying to re-filename->require an unreadable file fails"
                );
                is( \%file, \%core,
                    '%INC is the same for filename and CORE' );
            }
            chmod( $mode, $statname ) or die "Could not chmod $statname: $!";
        }

        # Tests with bad files
        foreach my $pm (qw(
            empty
            empty-string
            errno
            eval_error
            failure
            false
            undef
        )) {
            $_ = my $filename = sprintf( '%sTesting-%s.pm', $prefix, $pm );
            my $fullpath = $prefix ? $filename : "$FindBin::Bin/$filename";

            {
                local %INC = %INC;

                is( dies {&$file}, dies {&$core},
                    "Cannot filename->require $filename" );
                is( \%file, \%core,
                    '%INC is the same for filename and CORE' );
            }

            {
                local %INC = %INC;

                my $expected_error
                    = $pm eq "failure"
                    ? sprintf(
                          "syntax error at %s line %d, at EOF\n"
                        . "Compilation failed in require at %s line %d.\n",
                        $fullpath, 2, __FILE__, __LINE__ + 6
                    )
                    : sprintf(
                        "%s did not return a true value at %s line %d.\n",
                        $filename, __FILE__, __LINE__ + 2
                    );
                is( dies { CORE::require($filename) }, $expected_error,
                    "Failed to require $filename" );
                if ( $pm eq "failure" ) {
                    is( exists $INC{$filename}, 1,
                        "%INC has been updated for $filename" );
                    is( $INC{$filename}, undef,
                        "\$INC{$filename} is undef" );
                } else {
                    is( exists $INC{$filename}, "",
                        "%INC has not been updated for $filename" )
                        || diag(
                            "\$INC{$filename} is ",
                            defined( $INC{$filename} )
                                ? $INC{$filename}
                                : "undefined"
                        );
                }

                local %inc = %INC;
                is( dies {&$file}, dies {&$core},
                    "Trying to re-filename->require $filename" );
                is( \%file, \%core,
                    '%INC is the same for filename and CORE' );
            }
        }
    }
}

done_testing();

