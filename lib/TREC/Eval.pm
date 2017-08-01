##
#
# TREC::Eval
#
# Thin wrapper around the trec_eval program that permits 
# Perl programs to access evaluation figures.
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
package TREC::Eval;

=pod

=head1 NAME

TREC::Eval - A simple wrapper around the trec_eval program

=head1 DESCRIPTION

This module serves as a wrapper around the B<trec_eval> program, so that a single result set can be evaluated.
In order to use this module, the B<trec_eval> program must be in B<$PATH>. 

Functionality is, at present, limited to single result sets and limited to the major evaluation measures.

Additionally, because of the way B<trec_eval> works,
it is necessary to have write permission in the present working directory, as a temporary file named
F<result_set.temp> must be created to facilitate evaluation.

=head1 METHODS

=over 4

=item my $eval = TREC::Eval->new( $result_set, $qrel_file )

=item my $eval = TREC::Eval->new( $result_set, $qrel_file, '-a' )

Create a new L<TREC::Eval|TREC::Eval> object. $result_set should be a L<TREC::ResultSet|TREC::ResultSet> object and $qrel_file should be a L<TREC::QRelFile|TREC::QRelFile> object or the path to a TREC qrel file.

If '-a' is passed as a third parameter, minor evaluation measures will also be available in the C<get> method (by passing
the -a switch to trec_eval). This is currently the only such flag supported.

The B<trec_eval> program is run as soon as this method is called.

=cut

sub new {
   my ( $invocant, $result_set, $qrel_file, $flag ) = @_;

   warn "Invalid flag passed to trec_eval" if defined $flag && $flag ne '-a';
   $flag = '' if !defined $flag || $flag ne '-a';

   if ( ref $qrel_file eq 'TREC::QRelFile' ) {
      $qrel_file = $qrel_file->get_file;
   }

   my $self = {};

   # create a temporary file to hold this result set
   $result_set->save( 'result_set.temp' );

   for ( qx/trec_eval $flag $qrel_file result_set.temp/ ) {
      my @fields = split;

      $self->{ $fields[ 0 ] } = $fields[ 2 ];
   }

   # delete the temporary file
   unlink 'result_set.temp';

   bless $self, ref $invocant || $invocant;

}

=item $eval->get( $field )

Get one of the values calculated by B<trec_eval>. $field should be the name of the field required (e.g. num_q, 
map, P5, ircl_prn.0.30 ). The full list of available fields is found by running B<trec_eval -h>. It is listed
under the heading "Major measures (again) with their relational names".

The list of available major measures is as follows:

=over

=item * num_ret         Total number of documents retrieved over all queries

=item * num_rel         Total number of relevant documents over all queries

=item * num_rel_ret     Total number of relevant documents retrieved over all queries

=item * map             Mean Average Precision (MAP)

=item * R-prec          R-Precision (Precision after R (= num-rel for topic) documents retrieved)

=item * bpref           Binary Preference, top R judged nonrel

=item * recip_rank      Reciprical rank of top relevant document

=item * ircl_prn.0.00   Interpolated Recall - Precision Averages at 0.00 recall

=item * ircl_prn.0.10   Interpolated Recall - Precision Averages at 0.10 recall

=item * ircl_prn.0.20   Interpolated Recall - Precision Averages at 0.20 recall

=item * ircl_prn.0.30   Interpolated Recall - Precision Averages at 0.30 recall

=item * ircl_prn.0.40   Interpolated Recall - Precision Averages at 0.40 recall

=item * ircl_prn.0.50   Interpolated Recall - Precision Averages at 0.50 recall

=item * ircl_prn.0.60   Interpolated Recall - Precision Averages at 0.60 recall

=item * ircl_prn.0.70   Interpolated Recall - Precision Averages at 0.70 recall

=item * ircl_prn.0.80   Interpolated Recall - Precision Averages at 0.80 recall

=item * ircl_prn.0.90   Interpolated Recall - Precision Averages at 0.90 recall

=item * ircl_prn.1.00   Interpolated Recall - Precision Averages at 1.00 recall

=item * P5              Precision after 5 docs retrieved

=item * P10             Precision after 10 docs retrieved

=item * P15             Precision after 15 docs retrieved

=item * P20             Precision after 20 docs retrieved

=item * P30             Precision after 30 docs retrieved

=item * P100            Precision after 100 docs retrieved

=item * P200            Precision after 200 docs retrieved

=item * P500            Precision after 500 docs retrieved

=item * P1000           Precision after 1000 docs retrieved

=back

The minor measures are available if the '-a' flag was passed to the contstructor.

=cut

sub get {
   my ( $self, $field ) = @_;

   return $self->{ $field };
}

1;

__END__

=back

=head1 SEE ALSO

L<TREC::QRelFile|TREC::QRelFile>, L<TREC::ResultSet|TREC::ResultSet>

=head1 AUTHOR

Written and maintained by David Lillis.

=cut
