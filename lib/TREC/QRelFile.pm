##
#
# TREC::QRelFile
#
# A class to read qrel files for the TREC evaluations
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
package TREC::QRelFile;
use strict;
use TREC::QRel::Line;

# create a new object
# the full path to the qrel_file should be passed as an argument
sub new {
   my ( $invocant, $file ) = @_;

   print STDERR "[Error]: No qrel_file specified\n" and exit( 1 ) unless defined $file;
   print STDERR "[Error]: qrel_file not found [$file]\n" and exit( 1 ) unless -f $file;

   print "[INFO]: Parsing qrel_file [$file]\n";

   # set up a hashref to store the qrels
   my $self = { file => $file };

   # read the file and store its contents in memory
   open IN, "<$file" or die 'Could not open qrel file';

   while ( <IN> ) {

      my $line = new TREC::QRel::Line( $_ );

      $self->{ qrels }->{ $line->qid }{ $line->docno } = $line->rel;

   }
   close IN;

   # save the number of queries for which we have relevance judgments
   $self->{ number_of_queries } = scalar keys %{ $self->{ qrels } };

   print "[INFO]: Finished parsing qrel_file\n";

   # create and return the object
   bless $self, ref $invocant || $invocant;
}

# return the number of queries we have qrels for
sub queries {
   my $self = shift;

   return $self->{ number_of_queries };
}

# Is a given relevant to a given query?
#  returns 1 if judged relevant, 0 if judged nonrelevant and undef if unjudged
#  params - query_id, doc_id
sub is_relevant {
   die 'Invalid number of parameters' unless ( @_ == 3 );

   my ( $self, $query, $docid ) = @_;

   return $self->{ qrels }->{ $query }{ $docid };
}

# return the file from which the qrels were loaded
sub get_file {
   my $self = shift;
   return $self->{ file };
}

##
# Find which documents in a result set are relevant
#  Parameter is a TREC::ResultSet
#  Returns a list of relevant documents contained in the result set
##
sub get_relevant {
   my ( $self, $rs ) = @_;

   die 'No result set specified' unless ( $rs && ref $rs eq 'TREC::ResultSet' );

   unless ( defined $self->{ qrels }->{ $rs->qid } ) {
      warn 'No relevance judgments for query ' . $rs->qid . ' appears in this qrel file';
   }

   return map $_->docno,
     grep $self->is_relevant( $_->qid, $_->docno ),
     map $rs->get_line( $_ ), ( 0 .. $rs->size - 1 );
}

sub get_nonrelevant {

   my ( $self, $rs ) = @_;
   die 'No result set specified'
     unless ( $rs && ref $rs eq 'TREC::ResultSet' );

   unless ( defined $self->{ qrels }->{ $rs->qid } ) {
      warn 'No relevance judgments for query ' . $rs->qid . ' appears in this qrel file';
   }

   return map $_->docno,
     grep !$self->is_relevant( $_->qid, $_->docno ),
     map $rs->get_line( $_ ), ( 0 .. $rs->size - 1 );
}

1;

__END__

=pod 

=head1 NAME

TREC::QRelFile - A class to read qrel files for the TREC evaluations

=head1 METHODS

=over 4

=item new($path)

Create a new TREC::QRelFile object. The parameter is the full path to the qrel file to be used. Each line in this file must be parseable by L<TREC::QRel::Line>.

=item is_relevant( $query_id, $document_id )

Returns true if $document_id is relevant to $query_id, and false otherwise

=item get_relevant( $result_set )

The parameter must be a TREC::ResultSet object. Returns a list of docids in the result set that are relevant to the query 
the result set is related to. Will throw a warning if there are no qrels for that query in this qrel file.

=item queries()

The number of queries for which qrels are available in this file. This will usually be the same as the number of queries results are available for in each of the topfiles.

=back

=head1 SEE ALSO

=head1 AUTHOR

Written and maintained by David Lillis.

=cut
