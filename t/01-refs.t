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
    my $return = require;
    %{ $incs{'require'} } = %INC;
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

# Negative tests
foreach my $inc (
    # CODE
    # CODE: Emtpy return
    'inc_func_0',

    # CODE: Single value return
    'inc_func_scalar',

    # Object
    bless \do{"Testing::WithoutINC"}, 'Testing::WithoutINC',
) {
    note "\@INC now includes ", ref($inc) || $inc;
    local @INC = ( ref($inc) ? $inc : ( __PACKAGE__->can($inc) || $inc ) );
    #push @INC, \&looking_for;

    foreach my $pm (qw( good symlink )) {
        my $module = sprintf( 'Testing-%s', $pm );
        $_ = my $filename = sprintf( '%s.pm', $module );

        is( dies {&$file}, dies {&$core},
            "Cannot filename->require $filename" );
        is( \%file, \%core, '%INC is the same for file and CORE' );

        my $expected_error
            = Scalar::Util::blessed($inc)
            ? sprintf(
                  qq!Can't locate object method "INC" via package "%s"!
                . qq! at %s line %d.\n!,
                ${$inc}, __FILE__, __LINE__ + 9
            )
            : sprintf(
                  "Can't locate %s in \@INC "
                . "(you may need to install the %s module) "
                . "(\@INC contains: %s)"
                . " at %s line %d.\n",
                $filename, $module, "@INC", __FILE__, __LINE__ + 2
            );
        eval { CORE::require($filename) };
        is( $@, $expected_error, "Failed to require $filename" );
        local %inc = %INC;
        is( dies {&$file}, dies {&$core},
            "Trying to re-filename->require $filename" );
        is( \%file, \%core, '%INC is the same for file and CORE' );
    }
}

# Positive tests
foreach my $inc (

    # CODE

    # CODE: Single value return
    'inc_func_scalarref',
    'inc_func_fh',
    'inc_func_coderef',

    # CODE: Two value return
    'inc_func_scalarref_fh',
    'inc_func_scalarref_coderef',
    'inc_func_fh_coderef',
    'inc_func_coderef_state',

    # CODE: Three value return
    'inc_func_scalarref_fh_coderef',
    'inc_func_scalarref_coderef_state',

    # CODE : Four value return
    'inc_func_scalarref_fh_coderef_state',

    # ARRAY
    [ \&inc_func_coderef, "Testing", 123 ],

    # Object
    bless \do{"Testing::INC"}, 'Testing::INC',

) {
    note "\@INC now includes ", ref($inc) || $inc;
    local @INC = ( ref($inc) ? $inc : ( __PACKAGE__->can($inc) || $inc ) );

    # Tests with good files
    foreach my $pm (qw( good symlink )) {
        $_ = my $filename = sprintf( 'Testing-%s.pm', $pm );

        is( &$file, &$core, "Can filename->require $filename" );
        is( \%file, \%core, '%INC is the same for filename and CORE' );
    }

    # Tests with bad files
    # failure has a difference in the error message (line 2 vs line 3),
    # so skip testing that one:
    #
    # syntax error at /loader/0xXXX/Testing-failuer.pm line 2, at EOF
    # Compilation failed in require at (eval 162) line 1.
    #
    # vs
    #
    # syntax error at /loader/0xXXX/Testing-failure.pm line 3, at EOF
    # Compilation failed in require at (eval 162) line 1.
    #
    foreach my $pm (qw(
        empty
        empty-string
        errno
        eval_error
        false
        undef
    )) {
        $_ = my $filename = sprintf( 'Testing-%s.pm', $pm );

        my ( $fdie, $cdie ) = ( dies {&$file}, dies {&$core} );
        s!/loader/0x[[:xdigit:]]+/!/loader/0xXXX/! for ( $fdie, $cdie );
        is( $fdie, $cdie,
            "Cannot filename->require $filename" );
        is( \%file, \%core, '%INC is the same for file and CORE' );
        eval { filename->require($filename) };
        local %inc = %INC;
        is( dies {&$file}, dies {&$core},
            "Trying to re-filename->require $filename" );
        is( \%file, \%core, '%INC is the same for file and CORE' );
    }
}

done_testing();


# Four value return
sub inc_func_scalarref_fh_coderef_state {
    my ( $sub, $filename ) = @_;
    my $precode = sprintf( "#line 0 %s/%s\n", __FILE__ , $filename );
    return \$precode, inc_func_fh( \&inc_func_fh, $filename ),
        inc_func_coderef( \&inc_func_coderef, $filename ), {};
}

# Three value return
sub inc_func_scalarref_fh_coderef {
    my ( $sub, $filename ) = @_;
    my $precode = sprintf( "#line 0 %s/%s\n", __FILE__ , $filename );
    return \$precode, inc_func_fh( \&inc_func_fh, $filename ),
        inc_func_coderef( \&inc_func_coderef, $filename );
}
sub inc_func_scalarref_coderef_state {
    my ( $sub, $filename ) = @_;
    my $precode = sprintf( "#line 0 %s/%s\n", __FILE__ , $filename );
    return \$precode, inc_func_coderef( \&inc_func_coderef, $filename ), {};
}

# Two value return
sub inc_func_scalarref_fh {
    my ( $sub, $filename ) = @_;
    my $precode = sprintf( "#line 0 %s/%s\n", __FILE__ , $filename );
    return \$precode, inc_func_fh( \&inc_func_fh, $filename );
}
sub inc_func_scalarref_coderef {
    my ( $sub, $filename ) = @_;
    my $precode = sprintf( "#line 0 %s/%s\n", __FILE__ , $filename );
    return \$precode, inc_func_coderef( \&inc_func_coderef, $filename );
}
sub inc_func_fh_coderef {
    my ( $sub, $filename ) = @_;
    return inc_func_fh( \&inc_func_fh, $filename ),
        inc_func_coderef( \&inc_func_coderef, $filename );
}
sub inc_func_coderef_state {
    my ( $sub, $filename ) = @_;
    return inc_func_coderef( \&inc_func_coderef, $filename ), {};
}

# Single value return
sub inc_func_scalar {
    my ( $sub, $filename ) = @_;
    my $fullpath = "$FindBin::Bin/$filename";
    return -r -f $fullpath ? $fullpath : ();
}
sub inc_func_scalarref {
    my ( $sub, $filename ) = @_;
    return \do {
        local $/;
        my $fh = inc_func_fh( \&inc_func_fh, $filename ) or die $!;
        <$fh>;
    };
}
sub inc_func_fh {
    my ( $sub, $filename ) = @_;
    my $fh;
    return open( $fh, '<', "$FindBin::Bin/$filename" ) ? $fh : ();
}
sub inc_func_coderef {
    my ( $sub, $filename ) = @_;
    my $fh = inc_func_fh( \&inc_func_fh, $filename );
    return $fh ? sub { $_ = <$fh>; return 0+ !!length() } : ();
}

# Empty return
sub inc_func_0 {
    my ( $sub, $filename ) = @_;
    ( $sub, my @params ) = ref($sub) eq 'ARRAY' ? @$sub : ( undef, $sub );
    return;
}

package Testing::INC;

BEGIN { *Testing::INC::INC = \&::inc_func_scalarref; }

package Testing::WithoutINC;

