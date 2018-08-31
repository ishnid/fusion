##
#
# TREC::TopFile
#
# A class to read a TREC top file in linear fashion
#
# It returns TREC::ResultSet objects
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
package TREC::TopFile;
use strict;
use TREC::ResultSet;
use FileHandle;

=pod

=head1 NAME

TREC::TopFile - A read-only class to extract result sets from a TREC top file in a linear fashion.



=head1 METHODS

=over 4

=item my $topfile = TREC::TopFile->new( $path )

Create a new TREC::TopFile object. $path should be the full file path to the file.

=cut

# create new object - supply the FULL file path as the argument
sub new {

   my ( $invocant, $path ) = @_;
   my $self = {};

   bless $self, ref $invocant || $invocant;

   $self->{ path } = $path;

   $self->openfile;

   return $self;

}

# get the next result set in the topfile, as a TREC::ResultSet object
# or undef if there are no more in the set

=item $topfile->get_resultset

Get the next result set from this top file. This will return a L<TREC::ResultSet|TREC::ResultSet> object.

Changes made to the returned result set are not reflected in the topfile.

=cut

sub get_resultset {
   my $self = shift;

   # return undef if there are no more lines
   return undef unless ( $self->has_more );

   my $rs = new TREC::ResultSet;

   # add the first line to the result set
   # this will set the query id in the result set itself
   $rs->add( $self->{ current_line } );

   # keep adding lines until either the filehandle returns undef (i.e. the end of the file is reached)
   #  or $rs->add returns false (the current_line has a different qid
   1 while ( $self->readline && $rs->add( $self->{ current_line } ) );

   # result set came straight from a topfile - no need to sort it
   $rs->is_sorted( 1 );

   $rs->topfile( $self );

   return $rs;
}

=item $topfile->has_more

Returns true if there is another result set in the file, false otherwise.

=cut

sub has_more {
   my $self = shift;

   return ( ! $self->{ filehandle }->eof || defined( $self->{ current_line } ) );
}

# Opens the file for reading (for internal use only => not formally documented).
sub openfile {

   my $self = shift;

   my $path = $self->{ path };

   # close existing filehandle if there is one
   $self->{ filehandle }->close if $self->{ filehandle };

   # open a filehandle to the topfile
   my $fh = new FileHandle;

   # open via gzip if it has a .gz extension (requires gzcat to be in path)
   if ( $path =~ /\.gz$/ ) {
      $fh->open( "gzcat $path |" ) || die "Failed to open TREC top file $path";
   }
   else {
      $fh->open( "<$path" ) || die "Failed to open TREC top file $path";
   }

   $self->{ filehandle } = $fh;

   # read in the first line
   $self->readline;

}

=item $topfile->reset

Reset this topfile to the beginning again. The next subsequent call to C<get_resultset> will return the first result set in the file.

=cut

sub reset {
   my $self = shift;

   # try to do a 'seek'

   unless ( $self->{ filehandle }->seek( 0, 0 ) ) {

      # if it's from a zless filehandle, seek will fail - reopen the file instead
      $self->closefile;

      $self->openfile;
   }

   # read the first line
   $self->readline;
}

=item $topfile->closefile

Close the file currently being read

=cut

sub closefile {
   my $self = shift;
   $self->{ filehandle }->close;
}

=item $topfile->readline

Read a line from the currently opened file

=cut

sub readline {
   my $self = shift;
   return defined( $self->{ current_line } = $self->{ filehandle }->getline );
}

=item my $path = $topfile->path

Returns the filesystem path this topfile was loaded from

=cut
sub path {
   my $self = shift;
   return $self->{ path };
}

1;

__END__

=back

=head1 SEE ALSO

=head1 AUTHOR

Written and maintained by David Lillis.

=cut
