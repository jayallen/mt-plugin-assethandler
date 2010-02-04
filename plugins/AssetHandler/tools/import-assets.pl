#!/usr/bin/perl
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
BEGIN {
    my $mtdir = $ENV{MT_HOME} ? "$ENV{MT_HOME}/" : '';
    unshift @INC, "$mtdir$_" foreach qw(lib extlib );
}
use MT::Bootstrap::CLI App => 'AssetHandler::Tool::Import';

__END__


=head1 AssetHandler::Tool::Import

sample - Using GetOpt::Long and Pod::Usage

=head1 SYNOPSIS

sample [options] [file ...]

 Options:
   -help            brief help message
   -man             full documentation

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut

