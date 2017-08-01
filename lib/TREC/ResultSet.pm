##
#
# TREC::ResultSet
#
# A class to represent a single result set for a single query
#
# It consists of a hashref with three fields
#  - the id of the query (scalar) for which this represents the ResultSet
#  - an array of TREC::ResultSet::Line objects
#  - a scalar indicating whether the result set has been sorted or not
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
package TREC::ResultSet;
use strict;
use TREC::ResultSet::Line;
use FileHandle;
use Log::Log4perl qw(:easy);

=pod

=head1 NAME

TREC::ResultSet - a class to represent a single result set for a single query

=head1 METHODS

=over 4

=item my $rs = TREC::ResultSet->new

Create a new, empty TREC::ResultSet object.

=cut

sub new {
   my ( $invocant, @params ) = @_; 
   bless { @params, sorted => 1, lines => [] }, ref $invocant || $invocant;
}

# normalise the scores in this result set using standard normalisation

=item $rs->normalise

Normalise the scores in this result set using standard normalisation. The maximum similarity score for any 
document in the result set will be mapped to 1, the lowest score will be mapped to 0 and each other
score will be scaled between those values.
If the result set has already been normalised, this will have no effect.

=cut

sub normalise {
   my $self = shift;

   unless ( $self->{ normalised } ) {

      # get the min and the max FIRST!!! (can't fetch as we go along, since it'll change during the process)
      my $max = $self->max_score;
      my $min = $self->min_score;

      # loop through the result set
      for my $i ( 0 .. $self->size - 1 ) {
         my $line = $self->get_line( $i );

         my $score =
           $max == $min ? 1 : ( ( $line->sim - $min ) / ( $max - $min ) );

         $line->sim( $score );
      }
      $self->{ normalised } = 1;
   }
}

=item $rs->score_variance

Get the variance of the scores in this result set.
These are only comparable with other result sets after normalise() has been called first.

=cut

sub score_variance {
   my $self = shift;
   require Statistics::Basic::Variance;
   return Statistics::Basic::Variance->new(
      [ map $self->get_line( $_ )->sim, ( 0 .. $self->size - 1 ) ] )->query;
}

# add a line (a TREC::ResultSet::Line object) to the result set
#  - return true if the line was added successfully
#  - return false if not (i.e. if the query id of the line isn't the
#    same as that which the result set represents

=item $rs->add( $line )

Add a line to this result set. $line can either be a raw, unformatted line directly from a top file
or a L<TREC::ResultSet::Line|TREC::ResultSet::Line> object.
Returns true if the line was added successfully.
Returns false if there was a problem (e.g. if the line relates to a query other than the one the 
to which the result set relates). If there are no lines already in the result set, the query id
identified in $line will be taken as the query that this result set relates to.
Further rows cannot be added to the result set after normalise() has been called.
A fatal error will be thrown if this is attempted.

=cut

sub add {
   my ( $self, $line ) = @_;

   die 'Cannot add lines after normalisation' if ( $self->{ normalised } );

   # convert the line to a TREC::ResultSet::Line object if it isn't already
   if ( ref $line ne 'TREC::ResultSet::Line' ) {
      $line = new TREC::ResultSet::Line( $line );
   }

   # set the query id for this ResultSet if not already set
   if ( !$self->qid ) {
      $self->qid( $line->qid );
      $self->is_sorted( 0 );
   }
   elsif ( $self->qid ne $line->qid ) {
   	# no need for a warning here: this is a document feature that's relied on
   	# by TREC::TopFile
      return 0;
   }

   # add the line and return true
   push @{ $self->{ lines } }, $line;
   return 1;
}

# make sure the order is correct

=item $rs->sort

Ensure the result set is correctly ordered, from most-relevant to least-relevant. 
This method is not intended for external use but is documented for completeness.

=cut

sub sort {
   my $self = shift;

   @{ $self->{ lines } } = sort { $b->sim <=> $a->sim } @{ $self->{ lines } };

   for my $i ( 0 .. $self->size - 1 ) {
      $self->{ lines }->[ $i ]->rank( $i + 1 );
   }

   $self->is_sorted( 1 );
}


=item my $sort_status = $rs->is_sorted( [ $status] );

Find if this result set has already been sorted
Returns 1 if already sorted, 0 if not.
Can also be used to set the sort status (e.g. after sorting).

=cut

sub is_sorted {
   my $self = shift;

	$self->{ sorted } = shift if @_;

	return $self->{ sorted };
}

# returns the number of lines in the result set (for iterative purposes)
=item $rs->size

Get the size (i.e. number of L<TREC::ResultSet::Line|TREC::ResultSet::Line> objects) in this result set.

=cut

sub size {
   my $self = shift;
   return scalar @{ $self->{ lines } };
}

# returns the TREC::ResultSet::Line object at a given position

=item $rs->get_line( $position )

Get the L<TREC::ResultSet::Line|TREC::ResultSet::Line> object at a given position.
These positions begin at zero for the most relevant document.

=cut

sub get_line {
   my $self = shift;

   die 'Illegal number of arguments' if ( @_ != 1 );
   die 'ResultSet line out of range' if ( $_[ 0 ] > $self->size );

   $self->sort unless ( $self->is_sorted );

   return $self->{ lines }->[ shift ];
}


=item $rs->get_line( $position )

Get/set the L<TREC::TopFile|TREC::TopFile> associated with this object.

=cut
sub topfile {
	my ( $self, $topfile ) = @_;
	
	$self->{ topfile } = $topfile if $topfile;
	
	ERROR "Returning no topfile" unless $topfile;
	
	return $self->{ topfile };
	
}

# get the query id this resultset relates to

=item $rs->qid

Get the ID of the query this result set relates to

=cut

sub qid {
   my ( $self, $qid ) = @_;
   $self->{ qid } = $qid if defined $qid;
   return $self->{ qid };
}

# miscellaneous method which can find things such as score variance, relevance
#  proportions, etc.

=item $rs->min_score

Get the minimum similarity score contained in this result set

=cut

sub min_score {
   my $self = shift;

   $self->sort unless ( $self->{ sorted } );

   return $self->get_line( $self->size - 1 )->sim;
}

=item $rs->max_score

Get the maximum similarity score contained in this result set

=cut

sub max_score {
   my $self = shift;

   $self->sort unless ( $self->{ sorted } );

   return $self->get_line( 0 )->sim;
}

=item $rs->save( $file, [$limit] )

Save this result set to a file. $file is either the filename to save it as or a Filehandle object to save to. It will be saved in TREC top file format. $limit is the maximum number of 
lines that will be saved (if this is omitted, saves all lines)

=cut

sub save {
   my ( $self, $file, $limit ) = @_;

   if ( defined $limit ) {
      $limit = $limit > $self->size ? $self->size : $limit;  
   }
   else {
   		$limit = $self->size;
   }

   unless ( defined $file && ref $file eq "FileHandle" ) {
      $file = FileHandle->new( ">$file" ) or die "Cannot open output file";
   }

   for ( 0 .. $limit - 1 ) {
      print $file join( "\t", $self->get_line( $_ )->all ), "\n";
   }
}

=item $rs->get_docnos

Get a list of the document numbers in this result set in order of relevance, without their similarity
scores.

=cut

sub get_docnos {
   my $self = shift;

   my @to_return;
   for my $i ( 0 .. $self->size - 1 ) {
      push( @to_return, $self->get_line( $i )->docno );
   }

   return @to_return;
}

=item $rs->subsets( @positions )

Split this result set into a number of subsets. The first result set returned begins at positon
0 of this result set. Subsequent subsets begin at the positions passed as arguments. Arguments 
that are greater than this result set's size are ignored. A fatal error is caused if any of the
arguments are negative numbers.

Returns a list of L<TREC::ResultSet|TREC::ResultSet> objects. The scores for each document in each
of these subsets will be the same as before this method was called (i.e. if C<normalise> has been
called, no further adjustment will be made to the scores and you may have to call C<normalise> again
on each subset).

=cut

sub subsets {
   my ( $self, @positions ) = @_;

   my $start = 0;
   my @to_return;

   # loop through the end points of the subsets, which includes $self->size if none of
   # the arguments passed are at or beyond the end of the result set
   for my $p ( @positions, $self->size ) {
      last if $p > $self->size;
      die "Negative index cannot be used for subset" if $p < 0;

      my $rs = new TREC::ResultSet;

      for my $i ( $start .. $p - 1 ) {
         $rs->add( $self->get_line( $i ) );
      }
      push( @to_return, $rs );
      $start = $p;
   }

   return @to_return;
}

1;
__END__

=back

=head1 SEE ALSO

=head1 AUTHOR

Written and maintained by David Lillis.

=cut
