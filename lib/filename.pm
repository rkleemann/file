
use strict;
use warnings;

package filename;
# ABSTRACT: Perl module to load files at compile-time, without BEGIN blocks.

=head1 SYNOPSIS

    # Instead of "BEGIN { require '/path/to/file.pm' }"
    # use the more succinct:
    use filename '/path/to/file.pm';

    # Or, if you need to do include a file relative to the program:
    use FindBin qw($Bin);
    use filename "$Bin/../lib/Application.pm";

    # Do it at runtime:
    filename->require('/path/to/file.pm');

    # Throw it into a loop:
    say( 'Required: ', $_ ) foreach grep filename->require, @files;

=head1 DESCRIPTION

This module came about because there was a need to include some standard
boilerplate that included some configuration and application specific paths
to all modules for an application, and to do it at compile time.
Rather than repeating C<BEGIN { require ... }> in every single entry point
for the application, this module was created to simplify the experience.

The intention is to have this module be equivalent to L<perlfunc/require>,
except that it's run at compile time (via L<perlfunc/use>),
rather than at runtime.

=cut

use Carp 1.50 ();

=method C<require( $filename = $_ )>

Does the equivalent of L<perlfunc/require> on the supplied C<$filename>,
or C<$_> if no argument is provided.

Must be called as a class method: C<< filename->require( $filename ) >>

=cut

my $error = sub { };    # Private sub

# Modified version of the code as specified in `perldoc -f require`
*import = \&require;
sub require {
    eval { $_[0]->isa(__PACKAGE__) } && shift
        || Carp::croak( $_[0], " is not a ", __PACKAGE__ );
    my $filename = @_ ? shift : $_;
    Carp::croak("Null filename used") unless length($filename);

    return $INC{$filename} if ( exists $INC{$filename} );

    if ( $filename =~ m!\A/! ) {
        goto NOT_INC if $^V < v5.17.0 && !-r $filename;
        return do($filename) || $error->($filename);
    }
    foreach my $prefix (@INC) {
        next unless -f ( my $fullpath = "$prefix/$filename" );
        next if $^V < v5.17.0 && !-r _;
        my $result = do $fullpath;
        $INC{$filename} = delete $INC{$fullpath};
        return $result || $error->( $filename => $fullpath );
    }
    NOT_INC:
        Carp::croak("Can't locate $filename in \@INC (\@INC contains: @INC)");
}

# Private sub
$error = sub {
    my $filename = @_ ? shift : $_;
    my $fullpath = @_ ? shift : $filename;

    $INC{$filename} = undef;

    $@ && Carp::croak( $@, "Compilation failed in require" );

    $! && Carp::croak(
        "Can't locate $filename:   ",
        $^V >= v5.21.0 ? "$fullpath: " : (),
        "$!"
    );

    delete $INC{$filename};
    Carp::croak( $filename, " did not return a true value" );
};

1;

__END__

