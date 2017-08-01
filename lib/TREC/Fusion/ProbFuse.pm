##
#
# TREC::Fusion::ProbFuse
#
# A class to perform data fusion using the ProbFuse algorithm
#
# Algorithm originally in:
#    Lillis, D., Toolan, F., Mur, A., Peng, L., Collier, R. and Dunnion, J.
#    Probability-Based Fusion of Information Retrieval Result Sets.
#    In Proceedings of the 16th Irish Conference on Artificial Intelligence
#    and Cognitive Science (AICS 2005), pages 147--156, Portstewart,
#    Northern Ireland, 2005. University of Ulster.
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
package TREC::Fusion::ProbFuse;
use base 'TREC::Fusion::Fuser';

use strict;

use TREC::ResultSet::Functions;
use TREC::QRelFile;
use POSIX;

# denominator can be 'all' (default) or 'judged';
our $denominator = 'all';

sub new {
   my ( $inv, $qrel_file, $options ) = @_;

   print STDERR "[Error]: Cannot train ProbFuse as no qrel_file was specified\n" and exit( 1 ) unless defined $qrel_file;

   # to maintain backwards compatibility, a single non-reference parameter is taken as the 'x' value
   my $x = ref $options ? $options->{ 'probfuse.x' } : $options;

   print STDERR "[Error]: Cannot run ProbFuse as the 'probfuse.x' parameter was not set\n" and exit( 1 ) unless defined $x;

   my $self = {
      qrel_file => ref $qrel_file ? $qrel_file : new TREC::QRelFile( $qrel_file ),
      x => $x,
      denominator => ref $options ? $options->{ denominator } : undef,
      segments    => [],
      iter        => 'Q0',
      run_id      => "ProbFuse_x$x",
   };

   bless $self, ref $inv || $inv;
}

# this is for testing purposes only - print out the training data
sub dump_training {

   my $self = shift;

   my @segments = @{ $self->{ segments } };

   my $num = 0;
   for my $i ( @segments ) {
      print "Model $num\n";

      my %hash = %$i;

      for my $k ( sort { $a <=> $b } keys %hash ) {
         print "$k - $hash{ $k }\n";
      }
      print "\n";
      $num++;
   }
}

sub train {
   my ( $self, @result_sets ) = @_;

   die 'Training finished, as fusion has occurred' if ( $self->{ training_done } );

   # set the number of result_sets if it's not set already
   $self->{ rs_number } ||= @result_sets;

   die 'Inconsistent number of result sets used' unless ( $self->{ rs_number } == @result_sets );
   die 'Result sets relate to different queries' unless ( TREC::ResultSet::Functions::same_qid( @result_sets ) );

   my @segments = map $self->segment( $_ ), @result_sets;

   # add to training data here
   $self->calculate_probabilities( $result_sets[ 0 ]->qid, @segments );

   #    $self->{ training_number }++;

}

sub fuse {
   my ( $self, @result_sets ) = @_;

   # ensure no training occurs after fusion has begun
   $self->{ training_done } = 1;

   die 'Cannot fuse before training' unless ( $self->{ rs_number } );
   die 'Inconsistent number of result sets used' unless ( $self->{ rs_number } == @result_sets );
   die 'Result sets relate to different queries' unless ( TREC::ResultSet::Functions::same_qid( @result_sets ) );

   my $qid = $result_sets[ 0 ]->qid;

   my @segmented = map $self->segment( $_ ), @result_sets;

   # the score for each document (key is docno and value is score)
   my %scores;

   for my $i ( 0 .. $#segmented ) {

      for my $docno ( keys %{ $segmented[ $i ] } ) {

         my $seg_no = $segmented[ $i ]{ $docno };

         $scores{ $docno } += $self->{ segments }[ $i ]{ $seg_no } / $seg_no;

      }
   }

   my $to_return = new TREC::ResultSet;

   my $rank = 0;
   for my $docid ( sort { $scores{ $b } <=> $scores{ $a } } keys %scores ) {

      # 1000 lines max (TREC limit)
      # no longer do this - use the parameter to 'save' in TREC::ResultSet instead
      # last if ( $rank == 999 );
      
      $to_return->add( TREC::ResultSet::Line->new( $qid, $self->{ iter }, $docid, $rank, $scores{ $docid }, $self->{ run_id } ) );

      $rank++;
   }

   return $to_return;
}

# Split a result set into segments
# The first argument should be a reference to the TREC::ResultSet object to be segmented
# This returns a reference to a hash in which each key is a document id and the value is the number of the segment it appears in.
sub segment {
   my ( $self, $rs ) = @_;
   my %segmented;
   my $x = $self->{ x };

   # k = n / x and must be an integer, so we round up (to avoid divide-by zero errors if $x is too big)

   # when i looked at this code, i'd commented out the following line and put
   # in the one after instead, for some reason - thought I'd point it out just
   # in case it's useful later on

   my $k = POSIX::ceil( $rs->size / $x );

   # my $k = $rs->size / $x;

   for my $position ( 0 .. $rs->size - 1 ) {

      $segmented{ $rs->get_line( $position )->docno } = POSIX::floor( $position / $k ) + 1;
   }

   my %unique_segments = map { $_ => 1 } values %segmented;

   unless ( keys( %unique_segments ) == $x ) {
      print STDERR "[WARN]: X is $x but there are " . keys( %unique_segments ) . " segments, made from " . $rs->size . " documents\n";
   }

   return \%segmented;
}

# first argument shoud be the query id, so that we can look up relevance
# second argument should be a hash returned by segment().
# returns a hashref. This contains the segment numbers (key) and probabilities (value) for each result set

sub calculate_probabilities {
   my ( $self, $qid, @segmented_results ) = @_;

   # After it is fully done, the key of each hash will be the segment number and the value will be the number of judged relevant
   #  or nonrelevant documents in that segment

   my @relevant;
   my @nonrelevant;
   my @unjudged;

   # The key is the segment number and the value is the number of documents in that segment.
   my @nums;

   for my $i ( 0 .. $#segmented_results ) {

      # get the probability for each segment
      for my $doc ( keys %{ $segmented_results[ $i ] } ) {

         # increase the number of docs found in this segment
         $nums[ $i ]{ $segmented_results[ $i ]{ $doc } }++;

         # increase the number of relevant docs in this segment if necessary
         my $is_relevant = $self->{ qrel_file }->is_relevant( $qid, $doc ); # save this to save typing!

         # defined and true => judged relevant
         $relevant[ $i ]{ $segmented_results[ $i ]{ $doc } }++ if ( $is_relevant );

         # defined and false => judged nonrelevant
         $nonrelevant[ $i ]{ $segmented_results[ $i ]{ $doc } }++ if ( defined $is_relevant && !$is_relevant );

         # undefined => unjudged
         $unjudged[ $i ]{ $segmented_results[ $i ]{ $doc } }++ if ( !defined $is_relevant );
      }
   }

   # now @probabilities and @nums contain the number of relevant documents in each segment for each result set
   # and the total number of documents in each segment for each result set respectively
   #  - divide the former by the latter to get the probability for THIS TRAINING INSTANCE ONLY

   for my $i ( 0 .. $#segmented_results ) {

      # for each segment (starting at 1 - no such thing as segment #0
      for my $k ( 1 .. $self->{ x } ) {

         my $judged_relevant    = $relevant[ $i ]{ $k }    || 0;
         my $judged_nonrelevant = $nonrelevant[ $i ]{ $k } || 0;
         my $unjudged           = $unjudged[ $i ]{ $k }    || 0;

         # if this segment contains documents for which we have relevant judgments

         # get the number of training instances already processed (and increase it, as we're adding a new one).
         # This needs to be incremented regardless of
         # whether or not there are judged documents.
         my $old_number = $self->{ training_numbers }[ $i ]{ $k }++;

         if ( $judged_relevant || $judged_nonrelevant ) {

            # calculate the probability for this training instance in this segment
            my $probability;

            if ( $denominator eq 'all' ) {
               $probability = $judged_relevant / ( $judged_relevant + $judged_nonrelevant + $unjudged );
            }
            elsif ( $denominator eq 'judged' ) {
               $probability = $judged_relevant / ( $judged_relevant + $judged_nonrelevant );
            }
            else {
               die 'Invalid $denominator option chosen';
            }

            # fetch the old value for the previous training instances
            my $old_value = $self->{ segments }[ $i ]{ $k } || 0;

            # multiply the old value by the number of training instances
            # add the probability for this training instance
            # divide by the new number of training instances to get the new average
            my $new_value = ( ( $old_value * $old_number ) + $probability ) / ( $old_number + 1 );

            $self->{ segments }[ $i ]{ $k } = $new_value;
         }
      }
   }

   #return it
   # return \%probabilities;
}

# # first argument should be a scalar containing the k value
# # second argument should be a reference to a hash where each key is a document id and the value is a true/false value indicating its relevance
# # third argument should be a reference to an array of arrays document ids, each representing a result set
# # fourth argument should be an array of hashes of probabilities
# sub run {

#     my ( $x, $relevant, $resultsets, $probabilities ) = @_;

#     my $filename = "$x.txt";

#     # @segmented is an array of hashes, where each hash is related to a result set in @resultsets
#     # The key of each hash is a document id - the value is the segment it's contained in in the relevant result set
#     my @segmented = map segment( $_, $x ), @{ $resultsets };

#     # get the probabilities for each segment
#     unless ( $probabilities ) {
# 	$probabilities = [ map probabilities( $_, $relevant ), @segmented ];
#     }

#     # In %finalrs, the keys will be document ids and the values will be the relevance scores calculated by the merging algorithm.
#     my %finalrs;

#     # do the merge
#     for my $i ( 0 .. @{ $resultsets } - 1 ) { # for each result set

# 	# for each document contained in that result set
# 	for my $doc ( @{ $resultsets->[ $i ] } ) {

# 	    unless ( defined $probabilities->[ $i ]->{ $segmented[ $i ]->{ $doc } } ) {
# 		my %unique_segments = map { $_ => 1 } values %{ $segmented[ $i ] };
# 		print STDERR "X is $x\n";
# 		print STDERR "Problem with $i, $doc\n";
# 		print STDERR "Segmented array has " . keys ( %unique_segments ) . " segments\n";
# 		print STDERR "The doc is in segment " . $segmented[ $i ]->{ $doc } . "\n";
# 		print STDERR "The result set has ". @{ $resultsets->[ $i ] }." documents in it\n";
# 		print STDERR "There are probabilities available for the following segments: " . join ( ' ', sort keys %{ $probabilities->[ $i ] } ) . "\n";
# 		print STDERR "\n";
# 	    }

# 	    # prepare the final rs
# 	    # MAKE SURE ONLY ONE OF THE FOLLOWING IS UNCOMMENTED AT ANY ONE TIME
# 	    # $segmented->[ $i ]->{ $doc } is the segment number document $doc appears in in result set $i

# 	    # this variation divides by the sqrt of the segment number
# 	    $finalrs{ $doc } += $probabilities->[ $i ]->{ $segmented[ $i ]->{ $doc } } / sqrt( $segmented[ $i ]->{ $doc } );

# 	    # this variation divides by the log of the segment number
# 	    # $finalrs{ $doc } += $probabilities->[ $i ]->{ $segmented[ $i ]->{ $doc } } / ( log( $segmented[ $i ]->{ $doc } + 1 )/ log( 2 ) );

# 	    # this variation divides by the segment number
# 	    # $finalrs{ $doc } += $probabilities->[ $i ]->{ $segmented[ $i ]->{ $doc } } / $segmented[ $i ]->{ $doc };

# 	    # this variation just adds the probabilities with no division
# 	    # $finalrs{ $doc } += $probabilities->[ $i ]->{ $segmented[ $i ]->{ $doc } };
# 	}
#     }

#     # sort the final result set by the score that has been assigned to each document and return it
#     return wantarray ? %finalrs : [ sort { $finalrs{$b} <=> $finalrs{$a} } keys %finalrs ];
# }

1;

__END__

=pod

=head1 NAME

TREC::Fusion::ProbFuse - A module to perform data fusion using the ProbFuse algorithm

=head1 METHODS

=over 4

=item new($qrel, $x)

Create a new TREC::Fusion::ProbFuse object. $x is the number of segments each result set should be divided into. $qrel can either be the full path to the qrel file or a TREC::QRelFile object.

=item train(@result_sets)

Use @result_sets as training data. The number of result sets passed to this method MUST be the same each time, and result sets from different systems must be in the same order each time.

=item fuse(@result_sets)

Fuse @result_sets using the ProbFuse algorithm. If no training has taken place, an error will occur. Similar to the train() method, the same number of result sets must be passed each time and in the same order. Once fuse() is called once, no more training can be done. Returns a TREC::ResultSet object.

=back

=head1 SEE ALSO

=head1 AUTHOR

Written and maintained by David Lillis.

=cut
