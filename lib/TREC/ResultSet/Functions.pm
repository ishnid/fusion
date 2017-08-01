##
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
# THIS CAN ONLY BE USED OVER TWO RESULT SETS
#
##
package TREC::ResultSet::Functions;
use strict;

sub lee_overlap {
   my ( $qrel, @result_sets ) = @_;

   if ( @result_sets != 2 ) {
      die 'Can only get overlap between 2 result sets';
   }

   my $first_relevant  = $qrel->get_relevant( $result_sets[ 0 ] );
   my $second_relevant = $qrel->get_relevant( $result_sets[ 1 ] );

   my $first_nonrelevant  = $result_sets[ 0 ]->size - $first_relevant;
   my $second_nonrelevant = $result_sets[ 1 ]->size - $second_relevant;

   my %temp;

   $temp{ $_ }++ for ( map $qrel->get_relevant( $_ ), @result_sets );
   my $rcommon = grep $temp{ $_ } > 1, keys %temp;

   %temp = ();
   $temp{ $_ }++ for ( map $qrel->get_nonrelevant( $_ ), @result_sets );
   my $ncommon = grep $temp{ $_ } > 1, keys %temp;

   my ( $roverlap, $noverlap ) = ( 0, 1 );
   if ( $first_relevant || $second_relevant ) {
      $roverlap = ( $rcommon * 2 ) / ( $first_relevant + $second_relevant );
   }

   if ( $second_nonrelevant || $first_nonrelevant ) {
      $noverlap =
        ( ( $ncommon * 2 ) / ( $first_nonrelevant + $second_nonrelevant ) )
        || 1;
   }

   return ( $roverlap / $noverlap );

}

sub unique_relevant {
   my ( $qrel, @result_sets ) = @_;

   my %all_relevant;

   # construct a hash containing document ids of relevant documents as the keys
   #  and the number of result sets it appears in as its values - the ones with a value
   #  of 1 are the unique relevant documents
   $all_relevant{ $_ }++ for ( map $qrel->get_relevant( $_ ), @result_sets );

   # now figure out which unique rel belongs to which result set.
   my @to_return;

   for my $rs ( @result_sets ) {
      push @to_return,
        [ grep $all_relevant{ $_ } == 1, $qrel->get_relevant( $rs ) ];
   }

   return map scalar @$_, @to_return;
}

sub same_qid {
   my @result_sets = @_;

   die 'No result sets specified' unless ( @result_sets );

	my $defined = 1;
	for ( @result_sets ) {
		$defined = 0 unless defined $_;
	}

	unless ( $defined ) {
      for ( @result_sets ) {
			if ( defined $_ ) {
				print $_->get_line( 0 )->run_id . " defined\n";
			}
			else {
				print "[Warning]: A result set was Undefined\n";
			}
		}
	}

   return grep +( $_->qid eq $result_sets[ 0 ]->qid ), @result_sets[ 1 .. $#result_sets ];
}

1;

__END__

=pod

=head1 NAME

TREC::ResultSet::Functions - A collections of functions relating to result set manipulation

=head1 FUNCTIONS

=over 4

=item unique_relevant( $qrel_obj, @result_sets )

$qrel_obj must be a TREC::QRelFile object and @result_sets must be TREC::ResultSet objects. Returns a list of arrayrefs. Each arrayref is a list of the relevant documents contained in an input result set (in the same order as they were inputted in) that are unique to that result set (i.e. appear in no others).

=item same_qid( @result_sets )

Returns true if all the TREC::ResultSet items in @result_sets relate to the same query.

=item lee_overlap( $qrel_obj, @result_sets )

=back

=head1 AUTHOR

Written and maintained by David Lillis.

=cut
