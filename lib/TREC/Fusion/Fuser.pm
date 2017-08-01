##
#
# TREC::Fusion::Fuser
#
# A base class for fusion TREC::Fusion::* implementations
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
package TREC::Fusion::Fuser;

sub qrels {
   my $self = shift;
   return $self->{ qrel_file };
}

sub description {
   my $self = shift;
   return $self->{ run_id };
}

sub run_id {
   my ( $self, $run_id ) = @_;

   $self->{ run_id } = $run_id if $run_id;

   return $self->{ run_id };
}

1;
__END__
=back

=head1 SEE ALSO

=head1 AUTHOR

Written and maintained by David Lillis.

=cut
