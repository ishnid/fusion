##
#
# TREC::Fusion::SlideFuse
#
# A class to perform data fusion using the SlideFuse algorithm
#
# Algorithm originally in:
#    Lillis, D., Toolan, F., Collier, R., and Dunnion, J.
#    Extending Probabilistic Data Fusion Using Sliding Windows.
#    In Proceedings of the 30th European Conference on Information
#    Retrieval (ECIR '08), pages 358--369, 31st March - 2nd April 2008.
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
package TREC::Fusion::SlideFuse;
use base 'TREC::Fusion::Fuser';

use strict;
use TREC::QRelFile;
use TREC::ResultSet::Functions;

# number of positions either side to take into account in the sliding window
our $threshold = 5;

sub new {
   my ( $inv, $qrel_file ) = @_;

   print STDERR "[Error]: Cannot train SlideFuse as no qrel_file was specified\n" and exit( 1 ) unless defined $qrel_file;

   my $self = {
      qrel_file => ref $qrel_file ? $qrel_file : new TREC::QRelFile( $qrel_file ),
      probabilities => [],
      window        => [],
      iter          => 'Q0',
      run_id        => "SlideFuse_x$threshold",
   };

   bless $self, ref $inv || $inv;
}

sub clear {
   my $self = shift;
   $self->{ probabilities } 	= [];
   $self->{ window } 			= [];
   $self->{ training_done }	= 0;
}

# argument is a list of TREC::ResultSet objects: one from each of the data fusion techniques we're training
sub train {
   my ( $self, @result_sets ) = @_;

   die 'Training finished, as fusion has occurred' if ( $self->{ training_done } );

   # set the number of result_sets if it's not set already
   $self->{ rs_number } ||= @result_sets;

   # make sure we have the right number of result sets
   die 'Inconsistent number of result sets used' unless ( $self->{ rs_number } == @result_sets );
   
   # check that the result sets refer to the same query
   die 'Result sets relate to different queries' unless ( TREC::ResultSet::Functions::same_qid( @result_sets ) );

   # for each of the result sets
   for my $rsi ( 0 .. $#result_sets ) {

      # save the current result set in a variable for convenience
      my $rs = $result_sets[ $rsi ];

      # for every position in the result set
      for my $position ( 0 .. $rs->size() - 1 ) {

         # get the line of data in that position
         my $line = $rs->get_line( $position );

         # add one document to this technique's data in this position
         $self->{ totals }[ $rsi ][ $position ]++;

         # add a relevant document to this technique's data in this position (if relevant)
         $self->{ relevant }[ $rsi ][ $position ]++ if ( $self->{ qrel_file }->is_relevant( $line->qid, $line->docno ) );
      }
   }
}

# calculate the probabilities for each position
# and apply the sliding window
sub finalise {
   my $self = shift;

   # do probabilities for each position
   for my $techi ( 0 .. $#{ $self->{ totals } } ) {
      my $tech = $self->{ totals }->[ $techi ];
      for my $posn ( 0 .. $#{ $tech } ) {
         my $total    = $self->{ totals }->[ $techi ]->[ $posn ]   || 0;
         my $relevant = $self->{ relevant }->[ $techi ]->[ $posn ] || 0;

         # divide relevant by total to get the probability (avoid divide-by-zero)
         $self->{ probabilities }->[ $techi ]->[ $posn ] = $total ? $relevant / $total : 0;
      }

      # now do the sliding window
      for my $posn ( 0 .. $#{ $tech } ) {
         my $start = $posn - $threshold >= 0 ? $posn - $threshold : 0;
         my $end = $posn + $threshold <= $#{ $tech } ? $posn + $threshold : $#{ $tech };

         my $counter     = 0;
         my $probability = 0;
         for my $i ( $start .. $end ) {
            $probability += $self->{ probabilities }->[ $techi ]->[ $i ];
            $counter++;
         }

         # window score is the average of the probabilities for each position in the window
         $self->{ window }->[ $techi ]->[ $posn ] = $probability / $counter;
      }
   }

   delete $self->{ totals };
   delete $self->{ relevant };

   $self->{ training_done } = 1;
}

sub fuse {
   my ( $self, @result_sets ) = @_;

   $self->finalise unless $self->{ training_done };

   die 'Cannot fuse before training' unless ( $self->{ rs_number } );
   die 'Inconsistent number of result sets used' unless ( $self->{ rs_number } == @result_sets );
   die 'Result sets relate to different queries' unless ( TREC::ResultSet::Functions::same_qid( @result_sets ) );

   my $qid = $result_sets[ 0 ]->qid;

   my %scores;

   for my $rsi ( 0 .. $#result_sets ) {
      my @docs = $result_sets[ $rsi ]->get_docnos;
      for my $posn ( 0 .. $#docs ) {
         $scores{ $docs[ $posn ] } += $self->{ window }->[ $rsi ]->[ $posn ] || 0;
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

sub dump_training {
   my $self = shift;

   $self->finalise unless $self->{ training_done };

   for my $tech_no ( 0 .. $#{ $self->{ window } } ) {
      print "\nTechnique: $tech_no\n\n";
      for my $posn ( 0 .. $#{ $self->{ window }->[ $tech_no ] } ) {
         my $wind = $self->{ window }->[ $tech_no ]->[ $posn ];
         my $prob = $self->{ probabilities }->[ $tech_no ]->[ $posn ];
         printf "%02d: %f %f\n", $posn++, $wind, $prob;
      }
   }
}

1;
__END__
=pod 

=head1 NAME

TREC::Fusion::SlideFuse - A module to perform data fusion using the SlideFuse algorithm

=head1 METHODS

=over 4

=item new($qrel)

Create a new TREC::Fusion::SlideFuse object. $qrel can either be the path to the qrel file or a TREC::QRelFile object. This is necessary for training purposes.

=item train(@result_sets)

Use @result_sets as training data. The number of result sets passed to this method MUST be the same each time, and result sets from different systems must be in the same order each time.

=item fuse(@result_sets)

Fuse @result_sets using the SlideFuse algorithm. If no training has taken place, an error will occur. Similar to the train() method, the same number of result sets must be passed each time and in the same order. Once fuse() is called once, no more training can be done. Returns a TREC::ResultSet object.

=back

=head1 SEE ALSO

Algorithm originally in: Lillis, D., Toolan, F., Collier, R., and Dunnion, J., Extending Probabilistic Data Fusion Using Sliding Windows. In Proceedings of the 30th European Conference on Information Retrieval (ECIR '08), pages 358--369, 31st March - 2nd April 2008.

=head1 AUTHOR

Written and maintained by David Lillis.

=cut
