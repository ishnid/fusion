##
#
# TREC::Fusion::CombMNZ
#
# A class to perform data fusion using the CombMNZ algorithm
#
# Algorithm originally in:
#    Fox, E.A. and Shaw, J.A. Combination of Multiple Searches.
#    In Proceedings of the 2nd Text REtrieval Conference (TREC-2),
#    NIST, 1994
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
package TREC::Fusion::CombMNZ;
use base 'TREC::Fusion::Fuser';

use strict;
use TREC::ResultSet;
use TREC::ResultSet::Line;
use TREC::QRelFile;

sub new {
   my ( $invocant, $qrel_file ) = @_;

   print "[WARN]: CombMNZ does not require a qrel_file, however inconsistencies may arise if it is not specified\n" unless $qrel_file;

   my $self = { iter => 1, run_id => 'CombMNZ', qrel_file => ref $qrel_file ? $qrel_file : new TREC::QRelFile( $qrel_file ) };

   bless $self, ref $invocant || $invocant;
}

sub fuse {
   my ( $self, @result_sets ) = @_;

   die 'Invalid result sets' if grep +( !ref || ref ne 'TREC::ResultSet' ), @result_sets;

   my ( %sums, %mnzs );

   for my $rs ( @result_sets ) {

      $rs->normalise;

      for my $i ( 0 .. $rs->size - 1 ) {

         # get the line in position $i
         my $line = $rs->get_line( $i );

         # normalise the score
         $sums{ $line->docno } += $line->sim;

         # increase the number of non-zeroes
         $mnzs{ $line->docno }++;

      }
   }

   # now that we're done processing the result sets - multiply the scores by the mnzs
   # if we remove this block, we have CombSUM
   for my $docid ( keys %sums ) {

      $sums{ $docid } *= $mnzs{ $docid };
   }

   my $to_return = new TREC::ResultSet;

   my $qid  = $result_sets[ 0 ]->qid;
   my $rank = 0;

   #    print "[$_][$sums{$_}]\n" for keys %sums;

   for my $docid ( sort { $sums{ $b } <=> $sums{ $a } } keys %sums ) {

      # 1000 lines max (TREC limit)
      # no longer do this - use the parameter to 'save' in TREC::ResultSet instead
      # last if ( $rank == 999 );

      $to_return->add( new TREC::ResultSet::Line( $qid, $self->{ iter }, $docid, $rank, $sums{ $docid }, $self->{ run_id } ) );

      $rank++;
   }

   return $to_return;
}

1;

__END__

=pod

=head1 NAME

TREC::Fusion::CombMNZ - A module to perform data fusion using the CombMNZ algorithm

=head1 METHODS

=over 4

=item new( $options )

Create a new CombMNZ object. $options should be a hash reference containing information that should be included in the fused result set. Available fields to set are ``iter'' and ``run_id''. If these are not set, ``iter'' defaults to ``1'' and ``run_id'' defaults to ``CombMNZ''.

=item fuse( @result_sets )

Fuse @result_sets together using the CombMNZ algorithm. Each element in @result_sets must be a TREC::ResultSet object. Returns a TREC::ResultSet object.

=back

=head1 SEE ALSO

=head1 AUTHOR

Written and maintained by David Lillis.

=cut
