##
#
# TREC::Fusion::SegFuse
#
# A class to perform data fusion using the SegFuse algorithm
#
# Algorithm originally in:
#    Shokouhi, M., Segmentation of Search Engine Results for
#    Effective Data Fusion. In Proceedings of the 29th European Conference on
#    Information Retrieval Research (ECIR 2007), Rome, 2006
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
package TREC::Fusion::SegFuse;
use base 'TREC::Fusion::Fuser';

use TREC::ResultSet::Functions;

sub new {
   my ( $inv, $qrel_file ) = @_;

   print STDERR "[Error]: Cannot train SegFuse as no qrel_file was specified\n" and exit( 1 ) unless defined $qrel_file;

   my $self = {
      qrel_file => ref $qrel_file ? $qrel_file : new TREC::QRelFile( $qrel_file ),
      segments => _calculate_segments(),
      iter     => 'Q0',
      run_id   => 'SegFuse',
   };

   bless $self, ref $inv || $inv;
}

# calculate which segment each position belongs to
sub _calculate_segments {
   my $segments;

   # positions start at zero
   my $i = 0;
   my $k = 1;
   while ( $i <= 1000 ) {

      # this is the Size_k portion of equation 5
      my $size = ( 10 * ( 2**( $k - 1 ) ) ) - 5;
      for ( $i .. $i + $size ) {
         $segments->{ $_ } = $k;
      }
      $i += $size;
      $k++;
   }
   return $segments;
}

sub clear {
   my $self = shift;
   $self->{ probabilities } 		= [];
   $self->{ training_queries }	= 0;
   $self->{ training_done }		= 0;
}

sub train {

   my ( $self, @result_sets ) = @_;

   die 'Training finished, as fusion has occurred' if ( $self->{ training_done } );

   # set the number of result_sets if it's not set already
   $self->{ rs_number } ||= @result_sets;

   die 'Inconsistent number of result sets used' unless ( $self->{ rs_number } == @result_sets );
   die 'Result sets relate to different queries' unless ( TREC::ResultSet::Functions::same_qid( @result_sets ) );

   my $qid = $result_sets[ 0 ]->qid;

   for my $rsi ( 0 .. $#result_sets ) {
      my %relevant = my %total = ();

      # for each row in the result set
      for my $row ( 0 .. $result_sets[ $rsi ]->size() - 1 ) {

         # what segment is that row in
         my $segment = $self->{ segments }->{ $row };

         # increase total number of documents
         $total{ $segment }++;

         # increase number of relevant documents if appropriate
         if ( $self->{ qrel_file }->is_relevant( $qid, $result_sets[ $rsi ]->get_line( $row )->docno ) ) {
            $relevant{ $segment }++;
         }
      }

      # add to the probabilities - this will be divided by the number of queries to get the average
      for my $segment ( keys %total ) {

         #	    $self->{ probabilities }{ $segment } += ( ( $relevant{ $segment } || 0 ) / $total{ $segment } );
         $self->{ probabilities }[ $rsi ]{ $segment } += ( ( $relevant{ $segment } || 0 ) / $total{ $segment } );
      }
      $self->{ training_queries }++;
   }
}

# calculate final probabilities
sub finalise {
   my $self = shift;

   unless ( $self->{ training_done } ) {

      for my $rsi ( 0 .. $#{ $self->{ probabilities } } ) {

         for ( keys( %{ $self->{ probabilities }->[ $rsi ] } ) ) {
            $self->{ probabilities }->[ $rsi ]->{ $_ } /= $self->{ training_queries };
         }

         $self->{ training_done } = 1;
      }
   }
}

sub fuse {

   my ( $self, @result_sets ) = @_;

   # ensure no training occurs after fusion has begun
   $self->finalise();

   die 'Cannot fuse before training' unless ( $self->{ rs_number } );
   die 'Inconsistent number of result sets used' unless ( $self->{ rs_number } == @result_sets );
   die 'Result sets relate to different queries' unless ( TREC::ResultSet::Functions::same_qid( @result_sets ) );

   my $qid = $result_sets[ 0 ]->qid;

   my %scores = ();

   for my $rsi ( 0 .. $#result_sets ) {
      $result_sets[ $rsi ]->normalise();
      for my $posn ( 0 .. $result_sets[ $rsi ]->size() - 1 ) {
         my $row     = $result_sets[ $rsi ]->get_line( $posn );
         my $docno   = $row->docno();
         my $segment = $self->{ segments }->{ $posn };

         $scores{ $docno } += $self->{ probabilities }->[ $rsi ]->{ $segment } * ( $row->sim + 1 );
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
   $self->finalise();

   for my $rsi ( 0 .. $#{ $self->{ probabilities } } ) {

      print "Technique $rsi\n\n";

      # for each position from 0 to 999
      for my $posn ( 0 .. 999 ) {

         # get the segment this position is in
         my $segment = $self->{ segments }->{ $posn };

         # get the probability associated with that segment
         my $probability = $self->{ probabilities }->[ $rsi ]->{ $segment };

         printf( "%s:%f\n", $posn, $probability );
      }
   }

}

1;
__END__
=pod 

=head1 NAME

TREC::Fusion::SegFuse - A module to perform data fusion using the SegFuse algorithm

=head1 METHODS

=over 4

=item new($qrel)

Create a new TREC::Fusion::SegFuse object. $qrel can either be the path to the qrel file or a TREC::QRelFile object. This is necessary for training purposes.

=item train(@result_sets)

Use @result_sets as training data. The number of result sets passed to this method MUST be the same each time, and result sets from different systems must be in the same order each time.

=item fuse(@result_sets)

Fuse @result_sets using the SegFuse algorithm. If no training has taken place, an error will occur. Similar to the train() method, the same number of result sets must be passed each time and in the same order. Once fuse() is called once, no more training can be done. Returns a TREC::ResultSet object.


=back

=head1 SEE ALSO

Algorithm originally in: Shokouhi, M., Segmentation of Search Engine Results for Effective Data Fusion. In Proceedings of the 29th European Conference on Information Retrieval Research (ECIR 2007), Rome, 2006

=head1 AUTHOR

Written and maintained by David Lillis.

=cut
