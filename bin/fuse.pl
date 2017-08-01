#!/usr/bin/perl -w
##
#
# fuse.pl
#
# Perform fusion on input result sets contained
# in the INPUT_DIR and subdirectories (typically var/input)
#
# Save fusion output in the RESULT_DIR (typically var/result)
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
use File::Spec::Functions;
use File::Basename;
use lib catdir( dirname( $FindBin::Bin ), 'lib' );

use TREC::Config;
use TREC::TopFile;
use File::Find;
use File::Path;
use POSIX;
use Log::Log4perl qw(:easy);

Log::Log4perl->easy_init( $DEBUG );

unless ( @ARGV > 0 ) {
	INFO "[fuse.pl]: Usage: $0 technique\n";
	ERROR "[fuse.pl]: A fusion technique must be specified\n";
	exit(1);
}

my %config = TREC::Config::load_config;

my ( $technique, @files ) = @ARGV;

eval "require TREC::Fusion::$technique" or LOGDIE( "[fuse.pl]: TREC::Fusion::$technique not found" );

ERROR "[fuse.pl]: Directory [$config{ INPUT_DIR }] not found\n" and exit(1) unless -d $config{ INPUT_DIR };

INFO "[fuse.pl]: Using $technique for fusion\n";


# find input directories
INFO "[fuse.pl]: Finding input directories in directory [$config{ INPUT_DIR }]\n";

my %dirs;

find( \&wanted, $config{ INPUT_DIR } );

# list of leaf directories within 'inputs'
my @dirs = sort keys %dirs;

my $queries = 0;

# now start the fusion process
# create results directory first, if it's not there already

mkpath( $config{ RESULT_DIR } );


for my $dir ( @dirs ) {

	# create fuser object
	my $f = "TREC::Fusion::$technique"->new( $config{ qrel_file }, \%config );

	if ( ! $queries && $config{ k_folds } ) {

		$f->run_id( $f->run_id . '_f' . $config{ k_folds } );
	
		ERROR "[fuse.pl]: k_folds was set but no qrel_file was specified" and exit(1) unless $f->qrels;

		# number of queries
		$queries = $f->qrels->queries;
	}
	
	my @inputs = glob catdir( $dir, 'input.*' );
	print "[INFO]: Fusing inputs from directory [$dir]\n", map "\t[$_]\n", @inputs;

	my @topfiles = map TREC::TopFile->new( $_ ), @inputs;

	# read all results into memory
	my @result_sets;

	INFO "[fuse.pl]: Training\n";
	for ( 1 .. $queries ) {
		#$f->train( map $_->get_resultset, @topfiles );
		push @result_sets, [ map $_->get_resultset, @topfiles ];
	}


   for my $k ( 1 .. $config{ k_folds } ) {
		# output filename - 
		my $output_filename = catfile( $dir, $f->description."${k}_fold.out" );

		# remove path to the input directory from it
		substr( $output_filename, 0, length $config{ INPUT_DIR }, '' );

		# replaces slashes with dashes
		$output_filename =~ y{/}{-};

		# strip any leading dashes
		$output_filename =~ s/^-+//;	

		# train
		my $fold_size = $queries / $config{ k_folds };

		my $first_training = ( $k - 1 ) * $fold_size;
		my $last_training = $k * $fold_size - 1;

		INFO "[fuse.pl]: Fusing fold $k\n";

		INFO "[fuse.pl]: Training\n";

		for ( $first_training .. $last_training ) {
		   $f->train( @{ $result_sets[ $_ ] } );
		}


		my $out = FileHandle->new( '>'. catfile( $config{ RESULT_DIR }, $output_filename ) );

		for ( 0 .. $#result_sets ) {
			# skip training result sets
			next if $_ >= $first_training or $_ <= $last_training;
			my $rs = $f->fuse( @{ $result_sets[ $_ ] } );

			$rs->save( $out );
		}

		$out->close;
		$f->clear;
	}
}

sub wanted {
   if ( -d $File::Find::name ) {
		delete $dirs{ $File::Find::dir };
		$dirs{ $File::Find::name } = 1;
	}
}
