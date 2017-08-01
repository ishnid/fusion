##
#
# TREC::Config
#
# A class to parse the configuration file
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
package TREC::Config;
use FindBin;
use File::Basename;
use File::Spec::Functions;



sub load_config {
   my $config_file = "$FindBin::Bin/../etc/fusion.conf";

   my %config;

   print STDERR "[Error]: Config File $config_file not found\n" and exit unless ( -f $config_file );

   open( my $in, "<$config_file" );
   while ( <$in> ) {
      chomp;

      # skip everything that doesn't have an '=' in it
      # also, anything starting with a # is a comment
      next if !/=/ or /^\s+#/;

      # remove comments
      s/#.+$//;

      my ( $key, $value ) = split /=/, $_;

      # all user-defined configuration should be lowercase
      $config{ lc $key } = $value;
   }
   close $in;

   # add extra config options we might want, in uppercase
   $config{ BASE_DIR } = dirname( $FindBin::Bin );

   $config{ VAR_DIR } = catdir( $config{ BASE_DIR }, 'var' );

   $config{ INPUT_DIR } = catdir( $config{ VAR_DIR }, 'input' );

   $config{ RESULT_DIR } = catdir( $config{ VAR_DIR }, 'result' );

	$config{ EVAL_DIR } = catdir( $config{ VAR_DIR }, 'eval' );

   return %config;
}

1;
__END__
=pod 

=head1 NAME

TREC::Config - A module keep track of configuration data

=head1 METHODS

=over 4

=item my %config = Config->load_config

Load the configuration file (located in etc/fusion.conf).

=back

=head1 SEE ALSO

=head1 AUTHOR

Written and maintained by David Lillis.

=cut
