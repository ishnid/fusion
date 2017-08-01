#!/usr/bin/perl -w
##
#
# eval.pl
#
# Perform evaluations on output result sets contained
# in the RESULT_DIR (typically var/result)
#
# Save trec_eval output in the EVAL_DIR (typically var/eval)
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
use File::Spec::Functions qw( catdir catfile abs2rel );
use File::Basename;
use File::Path;
use lib catdir( dirname( $FindBin::Bin ), 'lib' );

use TREC::Config;
use File::Find::Rule;
use Log::Log4perl qw(:easy);

Log::Log4perl->easy_init( $INFO );

my %config = TREC::Config->load_config;

# find all results files
my @files = File::Find::Rule->name( '*.out' )->in( $config{ RESULT_DIR } );

my $qrel_file = $config{ qrel_file };

LOGDIE( 'No qrel file specified' ) unless $qrel_file;

INFO( "Using qrel file [$qrel_file]" );

for ( @files ) {
	my $outfile = abs2rel( $_, $config{ RESULT_DIR } );
	$outfile =~ s{/}{_};
	$outfile =~ s{out$}{eval};

	$outfile = catfile( $config{ EVAL_DIR }, $outfile );

	INFO( "Evaluating [$_]" );

	my $eval_output = qx{trec_eval $qrel_file $_};

	LOGDIE( "No eval output. Is trec_eval in your PATH?" ) unless $eval_output;

	INFO( "Saving output to [$outfile]" );

	mkpath( $config{ EVAL_DIR } );

	open( my $out, ">$outfile" ) or LOGDIE( "Failed to open output file for writing" );
	print $out $eval_output;
	close( $out );
}

