#!/usr/bin/perl -w
##
#
# init.pl
#
# Initialise fusion runs
#
# Input topfiles found in the directory passed as an argument
# will be arranged in subdirectories of INPUT_DIR
# (typically var/input)
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
use strict;
use FindBin;
use File::Basename;
use File::Spec::Functions;
use File::Path;
use File::Copy;
use lib catdir( dirname( $FindBin::Bin ), 'lib' );
use TREC::Config;
use TREC::TopFile;
use List::Util qw(shuffle);
use File::Copy;
use Log::Log4perl qw(:easy);

Log::Log4perl->easy_init( $DEBUG );

my $base_dir = dirname( $FindBin::Bin );

# needs to specify a source directory
print STDERR "Usage: $0 source_dir\n" and exit unless ( @ARGV == 1 );

my $source_dir = shift;

my %config = TREC::Config::load_config();

print STDERR "[ERROR]: Source directory '$source_dir' not found\n" and exit unless( -d $source_dir );

# get file list (in random order)
my @files = shuffle glob "$source_dir/*";

my ( $runs, $inputs_per_run, $k_folds ) = @config{ qw/runs inputs_per_run k_folds/ };

print STDERR "[ERROR]: Required configuration options 'runs', 'inputs_per_run' and 'k_folds' not set\n" and exit unless( defined $runs && defined $inputs_per_run && defined $k_folds );

print "[INFO]: Found " . @files . " input files\n";

if ( @files < $runs * $inputs_per_run ) {
   print STDERR "[ERROR]: Insuffient input files found for experiment\n" and exit(1);
}

my $var_dir = $config{ VAR_DIR };
my $data_dir = $config{ INPUT_DIR };

if ( -d $data_dir && glob( "$data_dir/*" ) ) {
   print STDERR "[ERROR]: Input dir '$data_dir' not empty\n" and exit;
}

mkpath( $data_dir );

for my $run ( 1 .. $runs ) {
	print "[INFO]: Creating directory for run $run\n";
   mkpath( catdir( $base_dir, 'data', "run$run" ) );

	# take first $inputs_per_run to be the inputs for this
	my @inputs = splice( @files, 0, $inputs_per_run );

	my $out_dir = catdir( $data_dir, "run$run" );
	mkpath( $out_dir );

	for my $input ( @inputs ) {
		copy $input, $out_dir;
	}
}

