
use strict;
use warnings;

package pm;
# ABSTRACT: Perl module to load files at compile-time, without BEGIN blocks.

=head1 SYNOPSIS

    # Instead of "BEGIN { require '/path/to/file.pm' }"
    # use the more succinct:
    use pm '/path/to/file.pm';

    # Or, if you need to do include a Per module relative to the program:
    use FindBin qw($Bin);
    use pm "$Bin/../lib/Application.pm";

    # Do it at runtime:
    pm->require('/path/to/file.pm');

    # Throw it into a loop:
    say( 'Required: ', $_ ) foreach grep pm->require, @files;

=head1 DESCRIPTION

This is just an alias to the L<filename> module.
See L<filename> for a complete description for how to use this module.

=cut

use parent 'filename';

1;

__END__

