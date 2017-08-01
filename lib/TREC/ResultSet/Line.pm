##
#
# TREC::ResultSet::Line
#
# A class that represents a single line of a
#  TREC result set
#
# It is stored as an arrayref in which the elements are
#  in the same order as in the input file (i.e. as outlined
#  by trec_eval's help section):
#
#  qid iter docno rank sim run_id
#
# A method is provided for each field, named as it is above
#  calling any of these methods without arguments acts as
#  an accessor. With a single argument, they act as mutators
#  and additional arguments lead to errors
#
#    Copyright 2017 David Lillis ( dave /at/ lill /dot/ is )
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
##
package TREC::ResultSet::Line;
use strict;
use Carp;

# new takes either an array or a single scalar as its argument
# - when an array, it's considered to be the pre-split line from the
#   TREC top file
# - when it's a scalar, it's considered to be that line in its raw state

our %positions;
@positions{ qw/qid iter docno rank sim run_id/ } = 0 .. 5;

sub new {
   my ( $invocant, @line ) = @_;

   # only one line => it must be the unsplit string
   if ( @line == 1 ) {
      chomp $line[ 0 ];
      $line[ 0 ] =~ s/^ //;
      @line = split /\s+/, $line[ 0 ], 6;
   }

   # make sure it has the right number of fields
   if ( @line != keys %positions ) {
      croak "[Error]: Invalid TREC entry: [@line]";
   }

   # create and return the object
   bless \@line, ref( $invocant ) || $invocant;
}

sub all {
   my $self = shift;

   return @$self;
}

sub AUTOLOAD {
   my ( $self, $value ) = @_;

   no strict 'vars';
   return if ( $AUTOLOAD =~ /::DESTROY/ );

   my ( $command ) = $AUTOLOAD =~ /::([^:]+)$/;

   # die if the field doesn't exist
   die "Invalid method: $AUTOLOAD" unless ( defined $positions{ $command } );

   # no arguments supplied => accessor
   if ( $value ) {
      $self->[ $positions{ $command } ] = $value;
   }
   else {
      return $self->[ $positions{ $command } ];
   }
}

1;
__END__

=pod

=head1 NAME

TREC::ResultSet::Line - A class to represent a single line from a TREC result set

=head1 METHODS

=over 4

=item new( @line )

Create a new TREC::ResultSet::Line object based on the contents of @line. If @line has one element, it is considered to be the unsplit raw string from the TREC top file. Otherwise, it must have six elements, corresponding to the six fields in each line (see ``trec_eval -h'' for details).

=item all()

Get all the contents of the line. Returns a list of six elements, each representing one field value. The fields are in the same order as in the trec top files(i.e. qid, iter, docno, rank, sim, run_id)

=item qid()

=item qid($qid)

Get/set the id of the query this line relates to

=item iter()

=item iter($iter)

Get/set the id of the iteration that produced this line (information only)

=item docno()

=item docno($docno)

Get/set the document ID that this line relates to

=item rank()

=item rank($rank)

Get/set the rank of this line within its result set (information only)

=item sim()

=item sim($sim)

Get/set the similarity score between the docno and the qid for this line.

=item run_id()

=item run_id($run_id)

Get/set the ID of the run that produced this line (information only)

=back

=head1 SEE ALSO

=head1 AUTHOR

Written and maintained by David Lillis.

=cut
