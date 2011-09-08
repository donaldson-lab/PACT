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
use XML::Simple;
use File::Path;

sub new {
     
     my ($class,$label) = @_;
     
     my $self = {
     	SequenceFile =>  undef,
     	InternalDirectory => undef,
     	In => undef, # The bioperl SearchIO object
     	SequenceMemory => undef,
     	Key => undef,
     	Label => $label,
     	DoneParsing => 0,
     	NumSeqs => 0,
	 };
	 $self->{Processes} = ();
     bless($self,$class);
     return $self;

}

sub prepare {
	my ($self,$key,$internal_directory) = @_;
	$self->{Key} = $key;
	$self->{InternalDirectory} = $internal_directory;
	for my $process(@{$self->{Processes}}) {
		$process->prepare($self->{Label},$key);
	}
	$self->SetSequences();
}

sub SetSequenceFile {
	my ($self,$fasta_name) = @_;
	if (-e $fasta_name and $fasta_name ne "") {
		$self->{SequenceFile} = $fasta_name;
		return 1;
	}
	return 0;
}

sub SetSequences {
	my ($self) = @_;
	my $inFasta = Bio::SeqIO->new(-file => $self->{SequenceFile} , '-format' => 'Fasta');
	while ( my $seq = $inFasta->next_seq) {
    	$self->{SequenceMemory}{$seq->id} = $seq->seq;
	}
	$self->{NumSeqs} = keys(%{$self->{SequenceMemory}});
}

sub AddProcess {
	my ($self,$process) = @_;
	push(@{$self->{Processes}},$process);
}

sub HitName {
	my ($self,$description) = @_;
	
	if (my $bracket_match = $description =~ m/\[(.*?)\]/) {
    	return $1;
    }
    else {
    	my @refined = split(/,/,$description);
    	return $refined[0]; ## This is a crude way of filtering the name.
    }
}

sub HitData {
	my ($self,$result,$hit,$hsp) = @_;
	
	my $hitname = $self->HitName($hit->description);
	my $query = $result->query_name;
	my @ids = split(/\|/,$hit->name);
	my $gi = $ids[1];
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
	
	
	my $sequence = $self->{SequenceMemory}{$result->query_name};
	
	return [$query,$qlength,$sequence,$hitname,$gi,1,$descr,$percid,$bit,$evalue,$starth,$endh,$startq,$endq,$hlength];
}

sub NoHits {
	my ($self,$query_name) = @_;
	
	my $sequence = $self->{SequenceMemory}{$query_name};
	
	chdir($self->{InternalDirectory});
	open(NOHITSFASTA, '>>' . "NoHits.fasta");
	
	print NOHITSFASTA ">" . $query_name . "\n";
  	print NOHITSFASTA $sequence . "\n";
  	print NOHITSFASTA "\n";
  	
  	close NOHITSFASTA;
}

sub Parse {
	
	my ($self,$progress_dialog) = @_;
	
	my $count = 0;
	
	while( my $result = $self->{In}->next_result) {
		$count++;
		my $progress_ratio = int(($count/$self->{NumSeqs})*98);
		$progress_dialog->Update($progress_ratio);

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
			$self->NoHits($result->query_name);
		}
		
	}
	
	$progress_dialog->Update(99,"Saving ...");
	for my $process(@{$self->{Processes}}) {
		$process->EndRoutine($self->{Key},$self->{InternalDirectory});
	}
	for my $process(@{$self->{Processes}}) {
		$process->SaveRoutine($self->{Key},$self->{InternalDirectory});
	}
	$progress_dialog->Update(100);
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
use base ("Parser");

sub new {
     
     my ($class,$label) = @_;
     
     my $self = $class->SUPER::new($label);
     $self->{BlastFile} = undef;
     $self->{Bit} = 40.0;
     $self->{Evalue} = .001;
     
     bless($self,$class);
     return $self;

}

sub SetBlastFile {
	my ($self,$blast_name) = @_;
	if (-e $blast_name and $blast_name ne "") {
		eval {
			my $xml = new XML::Simple;
			my $data = $xml->XMLin($blast_name);
			$self->{In} = new Bio::SearchIO(-format => 'blastxml', -file   => $blast_name);
			$self->{BlastFile} = $blast_name;
			return 1;
		} or do {
			eval {
				$self->{In} = new Bio::SearchIO(-format => 'blast', -file   => $blast_name);
				$self->{BlastFile} = $blast_name;
				return 1;
			} or do {
				return 0;
			};
		};
	}
	else {
		return 0;
	}
}

sub SetParameters {
	my ($self,$bit,$evalue) = @_;
	$self->{Bit} = scalar($bit);
	$self->{Evalue} = scalar($evalue);
}

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
     	Data => undef, # Usually Id to total number found for that value.
     	IdToName => undef, # Sequence Id to short name
     	Control => $control # parent ProgramControl (same object as in Display.pl)
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

# increment the Data hashes
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

sub EndRoutine {
	my ($self,$parser_name,$parser_directory) = @_;
}

# Save internally the values and structures obtained.
sub SaveRoutine {
	my ($self,$parser_name,$parser_directory) = @_;
}

# To be called before the parsing
sub prepare {
	my ($self,$parser_name,$parser_key) = @_;
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
     
     $self->{OutputDirectory} = $dir; # Parent directory in which local output directory will be printed.
     $self->{Processes} = ();
     bless($self,$class);
     return $self;
}

sub SetOutputDir {
	my ($self,$path) = @_;
	$self->{OutputDirectory} = $path;
}

sub AddProcess {
	my ($self,$process) = @_;
	push(@{$self->{Processes}},$process);
}

sub PrintHitFileHeader {
	my ($self,$dir,$hitname,$num_queries) = @_;
	
	chdir($dir);
	open(HITFILE, '>>' . $self->{Control}->ReadyForFile($hitname) . ".pact.txt");
	print HITFILE $hitname . "\n",
			"Total Number of Queries per Hit: " . $num_queries . "\n" . "\n";
	
	close HITFILE;
}

sub HitRoutine {
	my ($self,$hitdata) = @_;
	
	for my $process(@{$self->{Processes}}) {
		$process->HitRoutine($hitdata);
	}
	
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
	
	$self->AddData($gi,$hitname);
	$self->PrintHit($self->{OutputDirectory},$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq,$hitname,$gi,$sequence);
}

sub PrintHit {
	my ($self,$parent,$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq,$hitname,$gi,$sequence) = @_;
	my $dir = $parent . $self->{Control}->{PathSeparator} . $self->{Control}->ReadyForFile($hitname);
	mkdir ($dir);
	# Header?
	$self->PrintHitFile($dir,$hitname,$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq);
	$self->PrintFasta($dir,$hitname,$query,$sequence);
	chdir($self->{OutputDirectory});
}

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

sub PrintFasta {
	my ($self,$dir,$hitname,$query_name,$sequence) = @_;
	
	chdir($dir);
	open(FASTAFILE, '>>' . $self->{Control}->ReadyForFile($hitname) . ".pact.fasta");
	
	print FASTAFILE ">" . $query_name . "\n";
  	print FASTAFILE $sequence . "\n";
  	print FASTAFILE "\n";
  	
  	close FASTAFILE;
}

sub EndRoutine {
	my ($self,$parser_name,$parser_directory) = @_;
	$self->NoHitsFolder($parser_name,$parser_directory);
	$self->StatsFile();
	
	for my $process(@{$self->{Processes}}) {
			$process->EndRoutine($parser_name,$parser_directory);
	}
	
	$self->PrintSummaryTexts();
}

sub NoHitsFolder {
	my ($self,$parser_name,$parser_directory) = @_;
	# Needs: cleaning up header files
	chdir($self->{OutputDirectory});
	$self->{NoHits} = $self->{OutputDirectory} . $self->{Control}->{PathSeparator} . "NoHits";
	mkdir($self->{NoHits});
	copy ($parser_directory . $self->{Control}->{PathSeparator} . "NoHits.fasta",$self->{NoHits} . $self->{Control}->{PathSeparator} . $self->{Control}->GetParserName($parser_name) . ".NoHits.fasta");
}

sub StatsFile {
	my $self = shift;
	chdir($self->{OutputDirectory});
	open(STATSFILE, '>>' . "HitTotals.txt");
	
	my %hitnames = reverse %{$self->{IdToName}};
	my %hit2ids = ();
	
	##this probably can be done in one-liner
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

sub SaveRoutine {
	my ($self,$parser_name,$parser_directory) = @_;
	for my $process(@{$self->{Processes}}) {
		$process->SaveRoutine($parser_name,$parser_directory);
	}
}

sub PrintSummaryTexts {
	my ($self) = @_;
	for my $process (@{$self->{Processes}}) {
		$process->PrintSummaryText($self->{OutputDirectory});
	}
}


package FlagItems;
use base ("TextPrinter");

sub new {
	my ($class,$dir,$flag_file,$control) = @_;
	my $self = $class->SUPER::new($dir,$control);
	$self->Generate($flag_file);
	return $self;
}

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
	for my $flag (keys(%{$self->{Data}})) {
		  if ($descr =~ /$flag/ig) {
			  $self->PrintHit($self->{FlagDir},$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq,$hitname,$gi,$sequence);
			  last;
		  }
      }
}

sub EndRoutine {
	my ($self,$parser_name,$parser_directory) = @_;
}

# Save internally the values and structures obtained.
sub SaveRoutine {
	my ($self,$parser_name,$parser_directory) = @_;
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
	my ($self,$parser_name,$parser_directory) = @_;
	for my $process(@{$self->{Processes}}) {
		$process->SaveRoutine($parser_name,$parser_directory);
	}
	$self->{Taxonomy}->SaveRoutine($parser_name,$parser_directory);
}

sub PrintSummaryTexts {
	my ($self) = @_;
	$self->{Taxonomy}->PrintSummaryText($self->{OutputDirectory});
	for my $process (@{$self->{Processes}}) {
		$process->PrintSummaryText($self->{OutputDirectory});
	}
}

package Taxonomy;
use Bio::DB::Taxonomy;
use Bio::TreeIO;
use DB_File;
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
	
	my %reverse = reverse %{$self->{SpeciesToAncestor}};
	my %taxonomies = ();
	
	for my $ancestor(keys(%reverse)) {
		my @species = map {$_} grep {$self->{SpeciesToAncestor}{$_} == $ancestor} keys(%{$self->{SpeciesToAncestor}});
		$taxonomies{$ancestor} = \@species;
	}
	
	my @trees = ();
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
				print "Unable to merge or create tree $id\n"
			};
		}
		if (defined $tree and $tree->number_nodes > 0) {
			push(@trees,$tree);
		}
	}
	return \@trees;
}

sub SaveRoutine {
	my ($self,$parser_name,$parser_directory) = @_;
	chdir($parser_directory);
	my $trees = $self->GetTrees();
	$self->SaveTrees($trees);
}

## add file format as parameter. Save trees in individual files.
sub SaveTrees {
	my ($self,$trees) = @_;
	tie(my %NAMES,'DB_File',"NAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
	tie(my %RANKS,'DB_File',"RANKS.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
	tie(my %SEQIDS,'DB_File',"SEQIDS.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
	tie(my %VALUES,'DB_File',"VALUES.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
	for my $tree (@$trees) {
		my $title = $tree->get_root_node()->node_name;
		my $tree_key = $self->{Control}->AddTaxonomy($title);
		for my $node($tree->get_nodes) {
			$NAMES{$node->id} = $node->node_name;
			$RANKS{$node->id} = $node->rank;
			$SEQIDS{$node->id} = 0;
			$VALUES{$node->id} = $self->{Data}{$node->id};
		}
		open(my $handle, ">>" . $tree_key . ".tre");
		my $out = new Bio::TreeIO(-fh => $handle, -format => 'newick');
		$out->write_tree($tree);
		close $handle;
	}
	untie(%NAMES);
	untie(%RANKS);
	untie(%SEQIDS);
	untie(%VALUES);
}

sub PrintSummaryText {
	my ($self,$dir) = @_;
	
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
	
	my $trees = $self->GetTrees();
	
	for my $tree (@$trees) {
		my $root = $tree->get_root_node;
		open(TREE,'>>' . $root->node_name . '.pact.txt');
		for my $node($tree->get_nodes) {
			my $space = "";
			for (my $i=0; $i<GetDepth($node); $i++) {
				$space = $space . "  ";
			}
			print TREE $space . $node->node_name . ": " . $self->{Data}->{$node->id} . "\n";
		}
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
	return $self->{TaxonomyDB}->get_taxon(-gi => $id);
}


package Classification;
use XML::Writer;
use base ("Process");

sub new {
	my ($class,$file_name,$control) = @_;
	my $self = $class->SUPER::new($control);
	$self->{FilePath} = $file_name;
	bless($self,$class);
	return $self;
}

sub prepare {
	my ($self) = @_;
	$self->Generate();
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

sub PrintSummaryText {
	my ($self,$dir) = @_;
	chdir($dir);

	open(DATA,'>>' . $self->{Title} . '.pact.txt');
	
	my %reverse = reverse %{$self->{ItemToParent}};
	
	for my $parent(keys(%reverse)){
		print DATA $parent . ": " . $self->{Data}{$parent} . "\n";
		for my $item(keys(%{$self->{ItemToParent}})) {
			if ($self->{ItemToParent}{$item} eq $parent) {
				print DATA "  " . $item . ": " . $self->{Data}{$item} . "\n";
			}
		}
	}	
}


sub SaveRoutine {
	my ($self,$parser_name,$parser_directory) = @_;
	chdir($parser_directory);
	my $output = new IO::File(">" . $self->{Control}->AddClassification($self->{Title}) . ".xml");
	my $writer = new XML::Writer(OUTPUT => $output);
	$writer->startTag("root","Title"=>$self->{Title});
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
     
     my ($class,$control) = @_;
     
     my $self = $class->SUPER::new($control);
     $self->{GIs} = (); # Hash of gi numbers as primary keys for HitInfo
     bless($self,$class);
     return $self;

}

sub prepare {
	my ($self,$parser_name,$parser_key) = @_;
	$self->{TableName} = $parser_key;
	$self->MakeTables();
	$self->{Control}->AddTableName($parser_name,$parser_key);
}

sub MakeTables {
	my ($self) = @_;
	
	$self->{QueryInfo} = $self->{TableName} . "_QueryInfo";
	$self->{AllHits} = $self->{TableName} . "_AllHits";
	$self->{HitInfo} = $self->{TableName} . "_HitInfo";
	
	chdir($self->{Control}->{CurrentDirectory});
		 
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

package ClassificationXML;
use XML::Simple;

sub new {
	my ($class,$file_name) = @_;
	my $self = {
	};
	$self->{XML} = new XML::Simple;
	$self->{ClassificationHash} = $self->{XML}->XMLin($file_name);
	bless ($self,$class);
	return $self;
}

sub GetClassifiers {
	my ($self) = @_;
	my @classifier_list = ();
	my $classifiers =  $self->{ClassificationHash}->{"classifier"};
	# case of only one classifier
	if (defined $classifiers->{"item"}) {
		push(@classifier_list,$classifiers->{"name"});
	}
	else {
		for my $key (keys(%{$classifiers})) {
			push(@classifier_list,$key);
		}
	}
	return \@classifier_list;
}

sub PieClassifierData {
	my ($self,$input_class) = @_;
	my $piedata = {"Names"=>[],"Values"=>[],"Total"=>0};
	my $classifiers =  $self->{ClassificationHash}->{"classifier"};
	if (defined $classifiers->{"item"}) {
		for my $item (keys(%{$classifiers->{"item"}})) {
			my $value = $classifiers->{"item"}->{$item}->{"value"};
			if ($value == 0) {
				next;
			}
			push(@{$piedata->{Names}},$item);
			push(@{$piedata->{Values}},$value);
			$piedata->{Total} += $value;
		}
	}
	else {
		for my $class (keys(%{$classifiers})) {
			if ($class eq $input_class) {
				for my $item(keys(%{$classifiers->{$class}->{"item"}})) {
					my $value = $classifiers->{$class}->{"item"}->{$item}->{"value"};
					if ($value == 0) {
						next;
					}
					push(@{$piedata->{Names}},$item);
					push(@{$piedata->{Values}},$value);
					$piedata->{Total} += $value;
				}
			}
		}
	}
	return $piedata;
}

sub PieAllClassifiersData {
	my ($self) = @_;
	my $piedata = {"Names"=>[],"Values"=>[],"Total"=>0};
	my $classifiers =  $self->{ClassificationHash}->{"classifier"};
	if (defined $classifiers->{"item"}) {
		my $value = $classifiers->{"value"};
		if ($value == 0) {
			next;
		}
		push(@{$piedata->{Names}},$classifiers->{"name"});
		push(@{$piedata->{Values}},$value);
		$piedata->{Total} += $value;
	}
	else {
		for my $class (keys(%{$classifiers})) {
			my $value = $classifiers->{$class}->{"value"};
			if ($value == 0) {
				next;
			}
			push(@{$piedata->{Names}},$class);
			push(@{$piedata->{Values}},$value);
			$piedata->{Total} += $value;
		}
	}
	return $piedata;
}

package TaxonomyData;
use Bio::Tree::Tree;
use Bio::TreeIO;
use Fcntl;
use DB_File;

sub new {
	my ($class,$newick_file,$names,$ranks,$seqids,$values) = @_;
	my $self = {};
	$self->{TreeIO} = new Bio::TreeIO(-file=>$newick_file,-format=>'newick');
	$self->{Tree} = $self->{TreeIO}->next_tree;
	$self->{NAMES} = $names;
	$self->{RANKS} = $ranks;
	$self->{SEQIDS} = $seqids;
	$self->{VALUES} = $values;
	$self->{RootName} = $self->{NAMES}{$self->{Tree}->get_root_node()->id};
	bless ($self,$class);
	return $self;
}


sub PieDataNode {
	my ($self,$sub_node_name,$rank) = @_;
	my $sub_node = $self->FindNode($sub_node_name);
	return $self->PieDataRank($sub_node,$rank);
}

sub PieDataRank {
	my ($self,$sub_node,$rank) = @_;
	my %pie_data = {"Names"=>[],"Values"=>[],"Total"=>0};
	if ($sub_node->descendent_count == 0) {
		if ($self->{RANKS}{$sub_node->id} eq $rank) {
			push(@{$pie_data{"Names"}},$self->{NAMES}{$sub_node->id});
			push(@{$pie_data{"Values"}},$self->{VALUES}{$sub_node->id});
			$pie_data{"Total"} += $self->{VALUES}{$sub_node->id};
		}
		elsif ($rank eq "species" and $self->{RANKS}{$sub_node->ancestor()->id} eq "species") {
			push(@{$pie_data{"Names"}},$self->{NAMES}{$sub_node->id});
			push(@{$pie_data{"Values"}},$self->{VALUES}{$sub_node->id});
			$pie_data{"Total"} += $self->{VALUES}{$sub_node->id};
		}
	}
	
	for my $sub_sub_node($sub_node->get_all_Descendents) {
		if ($self->{RANKS}{$sub_sub_node->id} eq $rank){	
			push(@{$pie_data{"Names"}},$self->{NAMES}{$sub_sub_node->id});
			push(@{$pie_data{"Values"}},$self->{VALUES}{$sub_sub_node->id});
			$pie_data{"Total"} += $self->{VALUES}{$sub_sub_node->id};
		}
		elsif ($rank eq "species" and $self->{RANKS}{$sub_sub_node->ancestor()->id} eq "species") {
			push(@{$pie_data{"Names"}},$self->{NAMES}{$sub_sub_node->id});
			push(@{$pie_data{"Values"}},$self->{VALUES}{$sub_sub_node->id});
			$pie_data{"Total"} += $self->{VALUES}{$sub_sub_node->id};
		}
	}
	return \%pie_data;
}

sub FindNode {
	my ($self,$sub_node_name) = @_;
	for my $node($self->{Tree}->get_nodes) {
		if ($self->{NAMES}{$node->id} eq $sub_node_name) {
			return $node;
		}
	}
}

sub GetNodesAlphabetically {
	my ($self) = @_;
	my @node_names = ();
	for my $node($self->{Tree}->get_nodes) {
		push(@node_names,$self->{NAMES}{$node->id});
	}
	my @alpha = (sort {lc($a) cmp lc($b)} @node_names);
	return \@alpha;
}


1;