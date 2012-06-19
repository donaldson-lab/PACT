=head1 NAME

Process

=head1 SYNOPSIS

Do not use directly.

=head1 DESCRIPTION

This is a base class for all objects taking a Parser query result one at a time while parsing.

=cut

package Process;

sub new {
     my ($class,$control) = @_;
     
     my $self = {
     	Data => undef,
     	IdToName => undef,
     	Control => $control # parent IOHandler (same as in Display.pl)
	 };
     
     bless($self,$class);
     return $self;
}

sub PrintSummaryText {
	my ($self,$dir) = @_;
}

# For specifics on hitdata, see HitData in Parser (above)
sub HitRoutine {
	my ($self,$hitdata) = @_;
}

sub AddData {
	my ($self,$id,$name) = @_;

	if (not defined $self->{Data}{$id}) {
		$self->{Data}{$id} = 1;
	}
	else {
		$self->{Data}{$id} += 1;
	}
	$self->{IdToName}{$id} = $name;
}

# Save internally the values and structures obtained.
sub SaveRoutine {
	my ($self,$output_directory,$parser_name) = @_;
}

=head1 NAME

Parser

=head1 SYNOPSIS

Not to be used directly.

=head1 DESCRIPTION

This is a base class for parsing sequence similarity search output files.
Add processes (see below) which each have a HitRoutine to handle BLAST query result. 

=cut

use strict;

package Parser;
use Bio::SearchIO;
use Bio::SeqIO;
use Bio::Search::Iteration::GenericIteration;
use XML::Simple;
use File::Path;
use base ("Process");

sub new {
     
     my ($class,$control,$label,$dir) = @_;
     my $self = $class->SUPER::new($control);
     $self->{SequenceFile} = undef;
     $self->{OutputDirectory} = $dir;
     $self->{In} = undef;
     $self->{SequenceMemory} = undef;
     $self->{NumSeqs} = 0;
     $self->{NoHits} = undef; # Directory where No-Hits FASTA will be located
     $self->{NoHitIds} = (); # Hash of Sequence id's that did not match
     $self->{Label} = $label;
     $self->{DoneParsing} = 0;
     $self->{Processes} = ();
	 
     bless($self,$class);
     return $self;

}

# called before the parsing is done. See RunParsers in Display.pl
sub prepare {
	my ($self) = @_;
	$self->NoHitsFolder();
	$self->SetSequences();
}

# Sets the class member "SequenceFile" to the FASTA file specified. See GenerateParser in Display.pl
sub SetSequenceFile {
	my ($self,$fasta_name) = @_;
	if (-e $fasta_name and $fasta_name ne "") {
		$self->{SequenceFile} = $fasta_name;
		return 1;
	}
	return 0;
}

## Finds the count of the query sequences and puts them in memory
sub SetSequences {
	my ($self) = @_;
	my $inFasta = Bio::SeqIO->new(-file => $self->{SequenceFile} , '-format' => 'Fasta');
	my $count = 0;
	while ( my $seq = $inFasta->next_seq) {
		$self->{SequenceMemory}{$seq->id} = $seq->seq;
		$count++;
	}
	$self->{NumSeqs} = $count;
}

# void routine to add a process object to Processes array 
sub AddProcess {
	my ($self,$process) = @_;
	push(@{$self->{Processes}},$process);
}

# routine to convert the hit description from the BLAST output file to a shorter name to be used
# in summaries, file names, etc. 
sub HitName {
	my ($self,$description) = @_;
	
	if (my $bracket_match = $description =~ m/\[(.*?)\]/) {
    	return $1;
    }
    else {
    	my @refined = split(/,/,$description);
    	return $refined[0]; ## This is a crude way of filtering the name. Will be replaced by another (user-defined?) method.
    }
}

## one problem here is the consistency of data types across databases. This needs to be fixed
sub HitData {
	my ($self,$result,$hit,$hsp) = @_;
	
	my $hitname = $self->HitName($hit->description);
	my $query = $result->query_name;
	my @ids = split(/\|/,$hit->name);
	my $gi = $ids[1]; #gi is specific to GenBank. This needs to be changed.
	my $rank = 1;
	my $descr = $hit->description;
	my $qlength = $result->query_length;
	my $percid = $hsp->percent_identity;
	my $bit = $hsp->bits;
	my $evalue = $hsp->evalue;
	my $starth = $hit->start('hit');
	my $endh =  $hit->end('hit');
	my $startq = $hit->start('query');
	my $endq =  $hit->end('query');
	my $hlength = $hit->length;
	my $sequence = $self->{SequenceMemory}{$query}; # $hsp->query_string;
	
	return [$query,$qlength,$sequence,$hitname,$gi,1,$descr,$percid,$bit,$evalue,$starth,$endh,$startq,$endq,$hlength];
}

# creates the folder called "NoHits."  See below. 
sub NoHitsFolder {
	my ($self) = @_;
	chdir($self->{OutputDirectory});
	$self->{NoHits} = $self->{OutputDirectory} . $self->{Control}->{PathSeparator} . "NoHits";
	mkdir($self->{NoHits});
}

# Save all the queries that did not produce hit alignments in a fasta file in a folder called "NoHits."
sub WriteNoHits {
	my ($self) = @_;
	chdir($self->{NoHits});
	open(NOHITSFASTA, '>>' . "NoHits.fasta");
	my $inFasta = Bio::SeqIO->new(-file => $self->{SequenceFile} , '-format' => 'Fasta');
	while ( my $seq = $inFasta->next_seq) {
		my $id = $seq->id;
    	if (exists $self->{NoHitIds}{$id}) {
    		print NOHITSFASTA ">" . $id . "\n";
  		print NOHITSFASTA $seq->seq . "\n";
  		print NOHITSFASTA "\n";
    	}
	}
	close NOHITSFASTA;
}

# The Parser implementation of Process HitRoutine. Just increments the count for the hit. See AddData.
sub HitRoutine {
	my ($self,$hitdata) = @_;
	my $hitname = $hitdata->[3];
	my $gi = $hitdata->[4];
	$self->AddData($gi,$hitname);
}

# Parsing the sequence similarity output file. Just a loop.
# Args: wxProgressDialog. Perhaps not ideal, but the ProgressDialog needs updating
# during the parsing. 

sub Parse {
	
	my ($self,$progress_dialog) = @_;
	
	my $count = 0;
	push(@{$self->{Processes}},$self);
	
	while( my $result = $self->{In}->next_result) {
		
		#update the ProgressDialog.
		$count++;
		my $progress_ratio = int(($count/$self->{NumSeqs})*98);
		$progress_dialog->Update($progress_ratio);
		
		my $rank = 0;
		if (my $firsthit = $result->next_hit) {
			if (my $firsthsp = $firsthit->next_hsp) {
				
				## Check threshold parameters.
				if ($firsthsp->evalue > $self->{Evalue}) {
					next;
				}
				
				if ($firsthsp->bits < $self->{Bit}) {
					next;
				}
				
				## Get hit information.
				my $hitdata = $self->HitData($result,$firsthit,$firsthsp);
				
				for my $process(@{$self->{Processes}}) {
					$process->HitRoutine($hitdata);
				}
			}
			else {
			}
		}
		else {
			# the case when the query did not produce a hit alignment
			$self->{NoHitIds}{$result->query_name} = 1;
		}
		
	}
	
	# print the no hits FASTA file in the "No Hits" folder
	$self->WriteNoHits();
	
	$progress_dialog->Update(99,"Saving ...");
	for my $process(@{$self->{Processes}}) {
		$process->SaveRoutine($self->{OutputDirectory},$self->{Label});
	}
	chdir($self->{Control}->{CurrentDirectory});
	$progress_dialog->Update(100);
}

# Implementation of Process SaveRoutine
sub SaveRoutine {
	my ($self,$dir,$name) = @_;
	$self->PrintSummaryText($dir);
}

# The summary text file that prints the (short) name of each hit, followed by a colon,
# then the number found for that hit.
sub PrintSummaryText {
	my ($self,$dir) = @_;
	
	chdir($dir);
	open(STATSFILE, '>>' .  "$self->{Label} HitTotals.txt");
	
	my %hitnames = reverse %{$self->{IdToName}};
	my %hit2ids = ();
	
	##this probably can be done in one-liner? Basically, collects the number found for
	# each short name.
	for my $hitname(keys(%hitnames)){
		for my $key(keys(%{$self->{Data}})) {
			if ($self->{IdToName}{$key} eq $hitname) {
				if (defined $hit2ids{$hitname}) {
					$hit2ids{$hitname} += $self->{Data}{$key};
				}
				else {
					$hit2ids{$hitname} = $self->{Data}{$key};
				}
			}
		}
	}
	
	for my $hitname(keys(%hit2ids)) {
		print STATSFILE $hitname . ": " . $hit2ids{$hitname} . "\n";	
	}
	
	close STATSFILE;
}


=head1 NAME

FASTAParser

=head1 SYNOPSIS

my $fasta_parser = FASTAParser->new();

=head1 DESCRIPTION

Will be similar to BlastParser. Coming soon.

=cut

package FASTAParser;
use base ("Parser");

sub SetFASTAFile {
	my ($self,$fasta_path) = @_;
	$self->{FastaFile} = $fasta_path;
	$self->{In} = Bio::SearchIO->new(-format => 'fasta', -file  => $fasta_path);
}

=head1 NAME

Parser

=head1 SYNOPSIS

my $blast_parser = BlastParser->new();

=head1 DESCRIPTION

This is a base class for parsing sequence similarity search output files.

=cut

package BlastParser;
use Bio::Search::Result::BlastResult;
use Bio::Search::Hit::BlastHit;
use base ("Parser");

sub new {
     
     my ($class,$control,$label,$dir) = @_;
     
     my $self = $class->SUPER::new($control,$label,$dir);
     $self->{BlastFile} = undef;
     $self->{Bit} = 40.0;
     $self->{Evalue} = .001;
     
     bless($self,$class);
     return $self;

}

sub SetBlastFile {
	my ($self,$blast_name) = @_;
	$self->{BlastFile} = $blast_name;
	if (-e $blast_name and $blast_name ne "") {
		eval {
			my $xml = new XML::Simple;
			my $data = $xml->XMLin($blast_name);
			$self->{In} = new Bio::SearchIO(-format => 'blastxml', -file   => $blast_name);
		} or do {
			eval {
				$self->{In} = new Bio::SearchIO(-format => 'blast', -file   => $blast_name);
			} or do {
			};
		};
	}
	else {
	}
}

sub SetParameters {
	my ($self,$bit,$evalue) = @_;
	$self->{Bit} = scalar($bit);
	$self->{Evalue} = scalar($evalue);
}

=head1 NAME

TextPrinter

=head1 SYNOPSIS

my $printer = TextPrinter->new($output_path,$control);

=head1 DESCRIPTION

This is for printing parser results to a specified folder.  Each unique hit
will have a folder with a FASTA file containing those hits and a corresponding
text file containing information on each query. There is also a FASTA file containing
all queries that did not produce any hit alignments, and a Stats text file
showing the number found for each hit name. This is also a base class for TaxonomyTextPrinter.

=cut

package TextPrinter;
use File::Copy;
use base ("Process");

sub new {
	 my ($class,$dir,$control) = @_; # $dir is the path where all output ends up.
     my $self = $class->SUPER::new($control);
     $self->{Data} = ();
     $self->{IdToName} = ();
     $self->{OutputDirectory} = $dir; # Parent directory in which local output directory will be printed.
     bless($self,$class);
     return $self;
}

# Temporary file that prints the name of the hit and the number found. 
sub PrintHitFileHeader {
	my ($self,$dir,$hitname,$num_queries) = @_;
	
	chdir($dir);
	open(HITFILE, '>>' . $self->{Control}->ReadyForFile($hitname) . ".txt");
	print HITFILE $hitname . "\n",
			"Total Number of Queries per Hit: " . $num_queries . "\n" . "\n";
	close HITFILE;
}

# Implementation of Process HitRoutine. 
sub HitRoutine {
	my ($self,$hitdata) = @_;
	
	my $query = $hitdata->[0];
	my $qlength = $hitdata->[1];
	my $sequence = $hitdata->[2];
	my $hitname = $hitdata->[3];
	my $gi = $hitdata->[4];
	my $descr = $hitdata->[6];
	my $bit = $hitdata->[8];
	my $starth = $hitdata->[10];
	my $endh = $hitdata->[11];
	my $startq = $hitdata->[12];
	my $endq = $hitdata->[13];
	my $hitlength = $hitdata->[14];
	
	$self->AddData($gi,$hitname); # is there double-counting here?
	$self->PrintHit($self->{OutputDirectory},$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq,$hitname,$gi,$sequence);
}

# routine that calls the hit info and FASTA printing 
sub PrintHit {
	my ($self,$parent,$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq,$hitname,$gi,$sequence) = @_;
	my $dir = $parent . $self->{Control}->{PathSeparator} . $self->{Control}->ReadyForFile($hitname);
	mkdir($dir);
	# Header?
	$self->PrintHitFile($dir,$hitname,$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq);
	$self->PrintFasta($dir,$hitname,$query,$sequence);
	chdir($self->{OutputDirectory});
}

# Prints the information about the hit to the hit info text file
sub PrintHitFile {
	my ($self,$dir,$hitname,$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq) = @_;
	
	chdir($dir);
	open(HITFILE, '>>' . $self->{Control}->ReadyForFile($hitname) . ".pact.txt");
		
	print HITFILE $query . "\n",
	"Query Length: " . $qlength . "\n",
	"Hit Name: " . $descr . "\n",
	"Hit Id: " . $hitname . "\n",
	"Hit Length: " . $hitlength . "\n",
	"Start Position of Alignment on Hit: " . $starth . "\n",
	"End Position of Alignment on Hit: " . $endh . "\n",
	"Bit score of Hit: " . $bit . "\n",
	"Start Position of Alignment on Query: " . $startq . "\n",
	"End Position of Alignment on Query: " . $endq . "\n",
	"\n";
	
	close HITFILE;
}

# Print the query sequence to the associated FASTA file
sub PrintFasta {
	my ($self,$dir,$hitname,$query_name,$sequence) = @_;
	
	chdir($dir);
	open(FASTAFILE, '>>' . $self->{Control}->ReadyForFile($hitname) . ".fasta");
	
	print FASTAFILE ">" . $query_name . "\n";
  	print FASTAFILE $sequence . "\n";
  	print FASTAFILE "\n";
  	
  	close FASTAFILE;
}

=head1 NAME

FlagItems

=head1 DESCRIPTION

Class for Reading the flag flag, keeping the flag items in memory, and determine whetherm 
through parsing, a hit is to be flagged.
=cut

package FlagItems;
use base ("TextPrinter");

sub new {
	my ($class,$dir,$flag_file,$control) = @_;
	my $self = $class->SUPER::new($dir,$control);
	$self->Generate($flag_file);
	return $self;
}

# read and store the contents of the flag file
sub Generate {
	my ($self,$flag_file) = @_;
	
	open(FLAG,$flag_file);
	my $flagtitle = <FLAG>;
	chomp $flagtitle;
	$self->{Title} = $flagtitle;
	
	$self->{FlagDir} = $self->{OutputDirectory} . $self->{Control}->{PathSeparator} . $flagtitle;
	mkdir($self->{FlagDir});
	
    while (<FLAG>) {
		chomp;
	    $self->{Data}{$_} = 0;
    }
}

# implementation of Process HitRoutine
sub HitRoutine {
	my ($self,$hitdata) = @_;
	
	my $query = $hitdata->[0];
	my $qlength = $hitdata->[1];
	my $descr = $hitdata->[6];
	my $hitlength = $hitdata->[14];
	my $starth = $hitdata->[10];
	my $endh = $hitdata->[11];
	my $bit = $hitdata->[8];
	my $startq = $hitdata->[12];
	my $endq = $hitdata->[13];
	my $gi = $hitdata->[4];
	my $sequence = $hitdata->[2];
	my $hitname = $hitdata->[3];
	
	chdir($self->{OutputDirectory});
	# determine if any part of any flag item matches that of the hit description.
	for my $flag (keys(%{$self->{Data}})) {
		  if ($descr =~ /$flag/ig) {
		  	  # if so, print the hit info and FASTA in a hit folder in the flagged items folder!
			  $self->PrintHit($self->{FlagDir},$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq,$hitname,$gi,$sequence);
			  last;
		  }
      }
}

package TaxonomyTextPrinter;
use File::Path;
use base ("TextPrinter");

sub new {
	my ($class,$dir,$taxonomy,$control) = @_;
	my $self = $class->SUPER::new($dir,$control);
	$self->{Taxonomy} = $taxonomy;
	$self->{UnidentifiedDir} = $self->{OutputDirectory} . $self->{Control}->{PathSeparator} . "Unidentified";
	mkdir($self->{UnidentifiedDir});
	$self->{NameToPath} = ();
	bless($self,$class);
	return $self;
}

sub PrintHit {
	my ($self,$parent,$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq,$hitname,$hitid,$sequence) = @_;
	eval {
		my $path_names = $self->{Taxonomy}->GenerateBranch($hitname,$hitid);
		if (@$path_names > 0) {
			$self->{NameToPath}{$hitname} = $path_names;
			$self->PrintFound($path_names,$hitname,$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq,$sequence);
		}
		else {
		}
	};
	if ($@) {
		$self->PrintNotFound($hitname,$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq,$sequence);
	};
}

sub PrintNotFound {
	my ($self,$hitname,$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq,$sequence) = @_;
	chdir($self->{UnidentifiedDir});
	my $output = $self->{UnidentifiedDir} . $self->{Control}->{PathSeparator} . $self->{Control}->ReadyForFile($hitname);
	mkdir($output);
	$self->PrintHitFile($output,$hitname,$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq);
	$self->PrintFasta($output,$hitname,$query,$sequence);
	chdir($self->{OutputDirectory});
}

sub PrintFound {
	my ($self,$path_names,$hitname,$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq,$sequence) = @_;
	chdir($self->{OutputDirectory});
	my $dir = "";
	for my $name(@$path_names) {
		$dir = $self->{Control}->ReadyForFile($name) . $self->{Control}->{PathSeparator} . $dir;
	}
	mkpath($dir);
	$self->PrintHitFile($dir,$hitname,$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq);
	$self->PrintFasta($dir,$hitname,$query,$sequence);
	chdir($self->{OutputDirectory});
}

sub SaveRoutine {
	my ($self,$output_directory,$parser_name) = @_;
	#$self->SUPER::SaveRoutine($output_directory,$parser_name);
	$self->{Taxonomy}->GetTrees();
	$self->{Taxonomy}->SaveRoutine($output_directory,$parser_name);
	$self->{Taxonomy}->PrintSummaryText($output_directory,$parser_name);
}

package Taxonomy;
use Bio::DB::Taxonomy;
use Bio::TreeIO;
use Bio::TreeIO::phyloxml;
use File::Temp qw(tempfile);
use base ("Process");

sub new {
	my ($class,$control) = @_;
     
    my $self = $class->SUPER::new($control);
	$self->{TaxonomyDB} = undef;
	$self->{Data} = (); # Data is hit id to value.
	$self->{SpeciesToAncestor} = (); # hash of species id to ancestor id.
	$self->{IdToSpeciesTaxon} = ();
    bless($self,$class);
    return $self;
}

sub SetSearchFilters {
	my ($self,$ranks,$roots) = @_;
	my %hranks =  map {$_ => 1} @$ranks;
	$self->{Ranks} = \%hranks;
	my %hroots = map {$_ => 1} @$roots;
	$self->{Roots} = \%hroots;
}

sub HitRoutine {
	my ($self,$hitdata) = @_;
	my $gi = $hitdata->[4];
	my $hitname = $hitdata->[3];
	eval {
		$self->GenerateBranch($hitname,$gi);
	};
	if ($@) {
	};
}

## Implementation specific
sub GetSpeciesTaxon {
	my ($self,$hitname,$id) = @_;
}

sub GenerateBranch {
	my ($self,$hitname,$id) = @_;
	my $species = $self->GetSpeciesTaxon($hitname,$id);

	$self->{IdToSpeciesTaxon}{$id} = $species;
	$self->AddData($species->id,$hitname);
	my @path_names = ($hitname);
	while (my $parent = $self->{TaxonomyDB}->ancestor($species)) {
		$species = $parent;
		my $descendent_name = $species->node_name;
		my $descendent_id = $species->id;
		my $rank = $species->rank;
		if (keys %{$self->{Ranks}} and not defined $self->{Ranks}->{$species->rank}) {
			next;
		}
		
		$self->AddData($descendent_id,$descendent_name); #wasted space in Data if branch is not in Roots.
		
		if (keys %{$self->{Roots}}) {
			if (defined $self->{Roots}->{$descendent_name}) {
				$self->{SpeciesToAncestor}{$id} = $descendent_id;
				push(@path_names,$descendent_name);
				last;
			}
			else {
				@path_names = ();
				last;
			}
		}
		else {
			if (not defined $species->parent_id) {
				$self->{SpeciesToAncestor}{$id} = $descendent_id;
				push(@path_names,$descendent_name);
				last;
			}
			else {
				push(@path_names,$descendent_name);
			}
		}
	}
	return \@path_names;
}

sub GetTrees {
	my ($self) = @_;
	
	if (not defined $self->{SpeciesToAncestor}) {
		return 0;	
	}
	
	my %reverse = reverse %{$self->{SpeciesToAncestor}};
	my %taxonomies = ();
	
	for my $ancestor(keys(%reverse)) {
		my @species = map {$_} grep {$self->{SpeciesToAncestor}{$_} == $ancestor} keys(%{$self->{SpeciesToAncestor}});
		$taxonomies{$ancestor} = \@species;
	}
	
	$self->{Trees} = ();
	for my $ancestor(keys(%taxonomies)) {
		my $tree;
		for my $id(@{$taxonomies{$ancestor}}) {
			my $taxon = $self->{IdToSpeciesTaxon}{$id};
			# code somewhat borrowed from BioPerl db::Taxonomy get_tree, but for ids
			eval {
				if (defined $tree) {
                	$tree->merge_lineage($taxon);
            	}
	            else {
	                $tree = Bio::Tree::Tree->new(-verbose => $self->{TaxonomyDB}->verbose, -node => $taxon);
	            }
			};
			if ($@) {
				#print "Unable to merge or create tree $id\n"
			};
		}
		if (defined $tree and $tree->number_nodes > 0) {
			push(@{$self->{Trees}},$tree);
		}
	}
}

sub SaveRoutine {
	my ($self,$output_directory,$parser_name) = @_;
	if (not defined $self->{Trees}) {
		$self->GetTrees();
	}
	chdir($output_directory);
	$self->SaveTrees($parser_name);
}

# This routine will be moved to TaxonomyData?
sub SaveTrees {
	my ($self,$parser_name) = @_;
	for my $tree (@{$self->{Trees}}) {
		my $title = $parser_name . " " . $tree->get_root_node()->node_name;

		my $temp = new File::Temp( UNLINK => 0 );;
		my $temp_out = new Bio::TreeIO(-fh => $temp, -format => 'phyloxml');
		$temp_out->write_tree($tree);
		$temp_out->DESTROY;
		
		my $in = new Bio::TreeIO(-file => $temp, -format => 'phyloxml');
		my $in_tree = $in->next_tree;
		for my $node($in_tree->get_nodes) {
			my $id = $node->id;
			my $taxon = $tree->find_node($id);
			my $name = $taxon->node_name;
			my $rank = $taxon->rank;
			my $value = $self->{Data}{$node->id};
			$in->add_phyloXML_annotation(-obj=>$node,-xml=>"<taxonomy><scientific_name>$name</scientific_name><rank>$rank</rank></taxonomy><value>$value</value>");
		}
		
		open(my $handle, ">>" . $title . ".xml");
		my $out = new Bio::TreeIO(-fh => $handle, -format => 'phyloxml');
		
		$in_tree->remove_all_tags();
		$in_tree->add_tag_value("Title",$title);
		
		$out->write_tree($in_tree);
	}
}

sub PrintSummaryText {
	my ($self,$dir,$parser_name) = @_;
	
	chdir($dir);
	
	## BioPerl's depth routine does not seem to work well.
	sub GetDepth {
		my ($node) = @_;
		my $depth = 0;
		while (defined $node->ancestor) {
			$depth++;
			$node = $node->ancestor;
		}
		return $depth;
	}
	if (not defined $self->{Trees}) {
		$self->GetTrees();
	}
	
	for my $tree (@{$self->{Trees}}) {
		my $root = $tree->get_root_node;
		open(TREE,'>>' . $parser_name . " " . $root->node_name . '.txt');
		for my $node($tree->get_nodes) {
			my $space = "";
			for (my $i=0; $i<GetDepth($node); $i++) {
				$space = $space . "  ";
			}
			print TREE $space . $node->node_name . ": " . $self->{Data}->{$node->id} . "\n";
		}
		close TREE;
	}
}

package FlatFileTaxonomy;
use base ("Taxonomy");

sub new {
	my ($class,$nodesfile,$namesfile,$ranks,$roots,$control) = @_;
	my $self = $class->SUPER::new($control);
	$self->SetSearchFilters($ranks,$roots);
	$self->{TaxonomyDB} = Bio::DB::Taxonomy->new(-source => 'flatfile',-nodesfile => $nodesfile, -namesfile => $namesfile);
	bless($self,$class);
    return $self;
}

sub GetSpeciesTaxon {
	my ($self,$hitname,$id) = @_;
	return $self->{TaxonomyDB}->get_taxon(-name => $hitname);
}

package ConnectionTaxonomy;
use base ("Taxonomy");

sub new {
	my ($class,$ranks,$roots,$control) = @_;
	my $self = $class->SUPER::new($control);
	$self->SetSearchFilters($ranks,$roots);
	$self->{TaxonomyDB} = Bio::DB::Taxonomy->new(-source => 'entrez');
	bless($self,$class);
	return $self;
}

sub GetSpeciesTaxon {
	my ($self,$hitname,$id) = @_;
	my $taxon = $self->{TaxonomyDB}->get_taxon(-gi => $id);
	if (not defined $taxon) {
		$taxon = $self->{TaxonomyDB}->get_taxon(-name => $hitname);
	}
	return $taxon;
}


package Classification;
use XML::Writer;
use base ("Process");

sub new {
	my ($class,$file_name,$control) = @_;
	my $self = $class->SUPER::new($control);
	$self->{FilePath} = $file_name;
	bless($self,$class);
	$self->Generate();
	return $self;
}

sub Generate {
	my ($self) = @_;
	my $file_handle = open(CLASS,$self->{FilePath});
	my $title = <CLASS>;
	chomp $title;
	$self->{Title} = $title;
	$self->{ItemToParent} = ();
	$self->{Data}{$title} = 0; # Total
	
	my $current_parent = "";
	
	while(<CLASS>){
		chomp;
		if ($_ =~ /#/g){
			$current_parent = substr($_,1);
			$self->{Data}{$current_parent} = 0;
		}
		else{
			my $current_item = $_;
			$self->{ItemToParent}{$current_item} = $current_parent;
			$self->{Data}{$current_item} = 0;
		}
	}
	close CLASS;
}

sub Find {
	my ($self,$string) = @_;
	for my $item(keys(%{$self->{ItemToParent}})) {
		if ($string =~ /$item/ig){
			return $item;
		}
	} 
	return "";
}

sub Fill {
	my ($self,$string) = @_;
	my $item = $self->Find($string);
	if ($item ne "") {
		$self->{Data}{$item}++;
		my $parent = $self->{ItemToParent}{$item};
		$self->{Data}{$parent}++;
		$self->{Data}{$self->{Title}}++;
	}
	else {		
	}
}

sub HitRoutine {
	my ($self,$hitdata) = @_;
	my $hitname = $hitdata->[3];
	$self->Fill($hitname);
}

sub SaveRoutine {
	my ($self,$output_directory,$parser_name) = @_;
	$self->PrintSummaryText($output_directory,$parser_name);
	$self->SaveXML($output_directory,$parser_name);
}

sub PrintSummaryText {
	my ($self,$dir,$parser_name) = @_;
	chdir($dir);

	open(DATA,'>>' . $parser_name . " " . $self->{Title} . '.txt');
	
	my %reverse = reverse %{$self->{ItemToParent}};
	
	for my $parent(keys(%reverse)){
		print DATA $parent . ": " . $self->{Data}{$parent} . "\n";
		for my $item(keys(%{$self->{ItemToParent}})) {
			if ($self->{ItemToParent}{$item} eq $parent) {
				print DATA "  " . $item . ": " . $self->{Data}{$item} . "\n";
			}
		}
	}
	
	close DATA;
}

# to be moved to ClassificationXML, eventually
sub SaveXML {
	my ($self,$output_directory,$parser_name) = @_;
	chdir($output_directory);
	my $output = new IO::File(">" . $parser_name . " " . $self->{Title} . ".xml");
	my $writer = new XML::Writer(OUTPUT => $output);
	$writer->startTag("root","Title"=>$parser_name . " " . $self->{Title});
	my %parents_hash = reverse %{$self->{ItemToParent}};
	for my $parent(keys(%parents_hash)) {
		$writer->startTag("classifier","name"=>$parent,"value"=>$self->{Data}{$parent});
		my @items = map {$_} grep {$self->{ItemToParent}{$_} eq $parent} keys(%{$self->{ItemToParent}});
		for my $item(@items) {
			$writer->startTag("item","name"=>$item,"value"=>$self->{Data}{$item});
			$writer->endTag("item");
		}
		$writer->endTag("classifier");
	}
	
	$writer->endTag("root");
	$writer->end();
	$output->close();
}


package SendTable;
use DBI;
use base ("Process");

sub new {
     
     my ($class,$control,$parser_name) = @_;
     
     my $self = $class->SUPER::new($control);
     $self->{TableName} = $parser_name;
     $self->MakeTables();
     $self->{GIs} = (); # Hash of gi numbers as primary keys for HitInfo
     bless($self,$class);
     return $self;
}

sub MakeTables {
	my ($self) = @_;
	
	$self->{QueryInfo} = $self->{TableName} . "_QueryInfo";
	$self->{AllHits} = $self->{TableName} . "_AllHits";
	$self->{HitInfo} = $self->{TableName} . "_HitInfo";
		 
	$self->{Control}->{Connection}->do("DROP TABLE IF EXISTS " . $self->{QueryInfo});
	$self->{Control}->{Connection}->do("DROP TABLE IF EXISTS " . $self->{AllHits});
	$self->{Control}->{Connection}->do("DROP TABLE IF EXISTS " . $self->{HitInfo});
		 
	$self->{Control}->{Connection}->do("CREATE TABLE " . $self->{QueryInfo} .  "(query TEXT,qlength INTEGER,sequence TEXT)");
	$self->{Control}->{Connection}->do("CREATE TABLE " . $self->{AllHits} .  "(query TEXT,gi INTEGER,rank INTEGER,percent REAL,bit REAL,
		evalue REAL,starth INTEGER,endh INTEGER,startq INTEGER,endq INTEGER)");
	$self->{Control}->{Connection}->do("CREATE TABLE " . $self->{HitInfo} .  "(gi INTEGER,description TEXT,hitname TEXT,hlength INTEGER)");
}

sub HitRoutine {
	my ($self,$hitdata) = @_;
	
	my $query = $hitdata->[0];
	my $qlength = $hitdata->[1];
	my $sequence = $hitdata->[2];
	my $hitname = $hitdata->[3];
	my $gi = $hitdata->[4];
	my $rank = $hitdata->[5];
	my $descr = $hitdata->[6];
	my $percid = $hitdata->[7];
	my $bit = $hitdata->[8];
	my $evalue = $hitdata->[9];
	my $starth = $hitdata->[10];
	my $endh = $hitdata->[11];
	my $startq = $hitdata->[12];
	my $endq = $hitdata->[13];
	my $hlength = $hitdata->[14];
    
    $self->{Control}->{Connection}->do("INSERT INTO " . $self->{QueryInfo} . "(query,qlength,sequence) VALUES(?,?,?)",undef,($query,$qlength,$sequence));
    $self->{Control}->{Connection}->do("INSERT INTO " . $self->{AllHits} . "(query,gi,rank,percent,bit,evalue,starth,endh,startq,endq) 
    VALUES(?,?,?,?,?,?,?,?,?,?)",undef,($query,$gi,$rank,$percid,$bit,$evalue,$starth,$endh,$startq,$endq));
    if (not defined $self->{GIs}{$gi}) {
    	$self->{Control}->{Connection}->do("INSERT INTO " . $self->{HitInfo} . "(gi,description,hitname,hlength) 
    VALUES(?,?,?,?)",undef,($gi,$descr,$hitname,$hlength));
    $self->{GIs}{$gi} = 1;
    }
}

1;