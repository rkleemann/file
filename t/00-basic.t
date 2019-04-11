#! /usr/bin/env perl

use FindBin ();

use Test2::V0;

ok( require file, 'Can require file module' );
ok( require pm,   'Can require pm module' );

@INC = ( $FindBin::Bin, @INC );

our %inc = %INC;
my ( %incs, %file, %core );
$incs{'file->require'} = \%file;
$incs{'CORE::require'} = \%core;

# This hack is because I need them to report the same error message,
# including filename and line number.
my ( $file, $core ) = do {
    my $test = <<'END';
sub {
    local %INC = %inc;
    my $return = require;
    %{ $incs{'require'} } = %INC;
    return $return;
}
END
    eval( join(
        ',',
        map { $test =~ s/require/$_/gr =~ s/\s+//gr } qw(
            file->require
            CORE::require
        )
    ) );
};

{
    $_ = my $filename = "Testing.pm";

    is( &$file, &$core, "Can file->require $filename" );
    is( \%file, \%core, '%INC is the same for file and CORE' );
}

{
    $_ = my $filename = "$FindBin::Bin/Testing.pm";

    my $mode = ( stat $filename )[2] & 07777 || die "Cannot stat $filename";
    chmod( 00000, $filename ) or die "Could not chmod $filename: $!";
    is( dies {&$file}, dies {&$core},
        "Cannot file->require unreadable $filename" );
    is( \%file, \%core, '%INC is the same for file and CORE' );
    eval { file->require($filename) };
    local %inc = %INC;
    is( dies {&$file}, dies {&$core},
        "Trying to re-file->require an unreadable file fails" );
    is( \%file, \%core, '%INC is the same for file and CORE' );
    chmod( $mode, $filename ) or die "Could not chmod $filename: $!";
}

{
    $_ = my $filename = "Testing-empty.pm";

    is( dies {&$file}, dies {&$core},
        "Cannot file->require empty file $filename" );
    is( \%file, \%core, '%INC is the same for file and CORE' );
    eval { file->require($filename) };
    local %inc = %INC;
    is( dies {&$file}, dies {&$core},
        "Trying to re-file->require an empty file fails" );
    is( \%file, \%core, '%INC is the same for file and CORE' );
}

{
    $_ = my $filename = "Testing-failure.pm";

    is( dies {&$file}, dies {&$core},
        "Cannot file->require failing file $filename" );
    is( \%file, \%core, '%INC is the same for file and CORE' );
    eval { file->require($filename) };
    local %inc = %INC;
    is( dies {&$file}, dies {&$core},
        "Trying to re-file->require a failing file fails" );
    is( \%file, \%core, '%INC is the same for file and CORE' );
}

done_testing();
