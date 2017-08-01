##
#
# TREC::Fusion::MAPFuse
#
# A class to perform data fusion using a function of MAP to approximate probability
#
# Algorithm originally in:
#    Lillis, D., Zhang, L., Toolan, F., Collier, R. W., Leonard, D., and Dunnion, J.
#    Estimating Probabilities for Effective Data Fusion.
#    In Proceedings of the 33rd Annual ACM SIGIR Conference on Research and Development
#    in Information Retrieval. Geneva, Switzerland: ACM, pp. 347–354, 2010.
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
package TREC::Fusion::MAPFuse;
use base 'TREC::Fusion::Fuser';

use strict;
use TREC::QRelFile;
use TREC::ResultSet::Functions;
use Log::Log4perl qw(:easy);
use File::Basename;

sub new {
	my ( $inv, $qrel_file, $config ) = @_;
	
	unless ( defined $qrel_file ) {
		ERROR "[MAPFuse]: Cannot train MAPFuse as no qrel_file was specified\n" and exit( 1 )
	}
	
	my $self = {
		qrel_file => ref $qrel_file ? $qrel_file : new TREC::QRelFile( $qrel_file ),
		probabilities => [],
		window        => [],
		iter          => 'Q0',
		run_id        => "MAPFuse",
		config		  => $config
	};

	bless $self, ref $inv || $inv;
}

# argument is a list of TREC::ResultSet objects: one from each of the data fusion techniques we're training
sub train {
	
	my ( $self, @result_sets ) = @_;
	# no training to be done
	# the MAP scores should be in the config file
	# ... so any error will be found at fusion time
	
	# set the number of result_sets if it's not set already
    $self->{ rs_number } ||= @result_sets;
}


sub finalise {
	my $self = shift;
	# no training, so this sub is not required to do anything either
	$self->{ training_done } = 1;
}

sub fuse {
	my ( $self, @result_sets ) = @_;

	$self->finalise unless $self->{ training_done };

	LOGDIE '[MAPFuse]: Inconsistent number of result sets used' unless ( $self->{ rs_number } == @result_sets );
	LOGDIE '[MAPFuse]: Result sets relate to different queries'  unless ( TREC::ResultSet::Functions::same_qid( @result_sets ) );

	my $qid = $result_sets[ 0 ]->qid;

print "THING TO BE SPLIT IS: " , $self->{config}->{dir}, "\n";

	my $base = join( '_', ( split( '/', $self->{ config }->{ dir } ) )[-2,-1] );    
	
	my %scores;

	for my $rsi ( 0 .. $#result_sets ) {
		my @docs = $result_sets[ $rsi ]->get_docnos;
		( my $source = basename( $result_sets[ $rsi ]->topfile->path ) ) =~ s/input\.//;
				
		my $map = $self->{ config }->{ lc "${base}_$source" };
		
		LOGDIE "[MAPFuse]: No MAP score set for $source (entry should be \"${base}_${source}\"" unless $map;

		for my $posn ( 0 .. $#docs ) {
			$scores{ $docs[ $posn ] } += $map / ( $posn + 1 );
		}
	}

	my $to_return = new TREC::ResultSet;

	my $rank = 0;

	for my $docid ( sort { $scores{ $b } <=> $scores{ $a } } keys %scores ) {

		# 1000 lines max (TREC limit)
		# no longer do this - use the parameter to 'save' in TREC::ResultSet instead
		# last if ( $rank == 999 );

		$to_return->add( TREC::ResultSet::Line->new( $qid, $self->{ iter }, $docid, $rank, $scores{ $docid }, $self->{ run_id } ) );

		$rank++;
	}

	return $to_return;
}

sub dump_training {
	my $self = shift;

	$self->finalise unless $self->{ training_done };

	for my $tech_no ( 0 .. $#{ $self->{ window } } ) {
		print "\nTechnique: $tech_no\n\n";
		for my $posn ( 0 .. $#{ $self->{ window }->[ $tech_no ] } ) {
			my $wind = $self->{ window }->[ $tech_no ]->[ $posn ];
			my $prob = $self->{ probabilities }->[ $tech_no ]->[ $posn ];
			printf "%02d: %f %f\n", $posn++, $wind, $prob;
		}
	}
}

1;
__END__

=pod 

=head1 NAME

TREC::Fusion::MAPFuse - A module to perform data fusion using the MAPFuse algorithm

=head1 METHODS

=over 4

=item new($qrel)

Create a new TREC::Fusion::MAPFuse object. $qrel can either be the path to the qrel file or a TREC::QRelFile object. This is necessary for training purposes.

=item train(@result_sets)

MAPFuse doesn't require training, so this subroutine does nothing. The MAP scores used for fusion should be specified in the fusion.conf file

=item fuse(@result_sets)

Fuse @result_sets using the MAPFuse algorithm. The same number of result sets must be passed each time and in the same order.Returns a TREC::ResultSet object.

=back

=head1 SEE ALSO

=head1 AUTHOR

Written and maintained by David Lillis.

=cut
