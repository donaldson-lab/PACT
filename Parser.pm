use strict;

package Parser;

package FASTAParser;
use Bio::SearchIO;
use Bio::SeqIO;

package BlastParser;
use Bio::SearchIO;
use Bio::SeqIO;
use XML::Simple;
use File::Path;

sub new {
     
     my ($class,$name,$internal_directory) = @_;
     
     my $self = {
     	BlastFile => undef,
     	FastaFile =>  undef,
     	InternalDirectory => $internal_directory,
     	In => undef,
     	FastaMemory => undef,
     	HasTaxonomy => 0,
     	Name => $name,
     	DoneParsing => 0,
     	Bit =>40.0,
     	Evalue => .001,
     	Check => 0
	 };
	 $self->{Processes} = ();
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

## Needs to be split.
sub SetFastaFile {
	my ($self,$fasta_name) = @_;
	if (-e $fasta_name and $fasta_name ne "") {
		my $inFasta = Bio::SeqIO->new(-file => $fasta_name , '-format' => 'Fasta');
		while ( my $seq = $inFasta->next_seq) {
	    	$self->{FastaMemory}{$seq->id} = $seq->seq;
		}
		$self->{FastaFile} = $fasta_name;
		return 1;
	}
	else {
		return 0;
	}
}

sub SetParameters {
	my ($self,$bit,$evalue) = @_;
	# check if values are numbers if ()
	$self->{Bit} = $bit;
	$self->{Evalue} = $evalue;
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
	
	
	my $sequence = $self->{FastaMemory}{$result->query_name};
	
	return [$query,$qlength,$sequence,$hitname,$gi,1,$descr,$percid,$bit,$evalue,$starth,$endh,$startq,$endq,$hlength];
}

sub NoHits {
	my ($self,$query_name) = @_;
	
	my $sequence = $self->{FastaMemory}{$query_name};
	
	chdir($self->{InternalDirectory});
	open(NOHITSFASTA, '>>' . "NoHits.pact.fasta");
	
	print NOHITSFASTA ">" . $query_name . "\n";
  	print NOHITSFASTA $sequence . "\n";
  	print NOHITSFASTA "\n";
  	
  	close NOHITSFASTA;
}

sub Parse {
	
	my ($self) = @_;
	
	while( my $result = $self->{In}->next_result) {

		if (my $firsthit = $result->next_hit) {
			my $firsthsp = $firsthit->next_hsp;
			
			## Check threshold parameters.
			if ($firsthsp->evalue > $self->{Evalue}) {
				next;
			}
			
			if ($firsthsp->bits < $self->{Bit}) {
				next;
			}
			
			my $hitdata = $self->HitData($result,$firsthit,$firsthsp);
			for my $process(@{$self->{Processes}}) {
				$process->HitRoutine($hitdata);
			}
		}
		else {
			$self->NoHits($result->query_name);
		}
		
	}
	
	for my $process(@{$self->{Processes}}) {
		$process->EndRoutine();
	}
	for my $process(@{$self->{Processes}}) {
		$process->SaveRoutine($self->{Name},$self->{InternalDirectory});
	}
	
}

# Base class of working with table data. Not to be confused with SendTable. To be moved to separate file.
package Table;
use DBI;

sub new {
     
     my ($class) = @_;
     
     my $self = {
     	Connection => undef,
     	DatabaseName => undef,
     	QueryTable => undef,
     	HitTable => undef
	 };
     bless($self,$class);
     return $self;

}

sub Connect {
	my ($self,$name) = @_;
	$self->{DatabaseName} = $name;
	$self->{QueryTable} = $name;
	$self->{HitTable} = $name . "Hits";
	$self->{Connection} = DBI->connect("dbi:SQLite:" . $self->{DatabaseName} . ".db","","") or die("Couldn't open database");
}

package Process;

sub new {
     
     my ($class,$control) = @_;
     
     my $self = {
     	Data => undef,
     	Control => $control
	 };
     
     bless($self,$class);
     return $self;
}

sub PrintSummaryText {
	my ($self,$dir) = @_;
}

sub HitRoutine {
	my ($self,$hitdata) = @_;
}

sub EndRoutine {
	my ($self) = @_;
}

sub SaveRoutine {
	my ($self,$parser_name,$parser_directory) = @_;
}

package TextPrinter;
use base ("Process");

sub new {
	 my ($class,$dir,$control) = @_;
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
	my ($self) = @_;
	
	# Needs: cleaning up header files and,
	# Creating No Hits folder and fasta file
	
	for my $process(@{$self->{Processes}}) {
				$process->EndRoutine();
	}
	
	$self->PrintSummaryTexts();
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
		
		  if ($hitname =~ m/$flag/igx) {
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
	$self->{UnclassifiedDir} = $self->{OutputDirectory} . $self->{Control}->{PathSeparator} . "Unclassified";
	mkdir($self->{UnclassifiedDir});
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
	chdir($self->{UnclassifiedDir});
	my $output = $self->{UnclassifiedDir} . $self->{Control}->{PathSeparator} . $self->{Control}->ReadyForFile($hitname);
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
		$process->SaveRoutine($parser_name);
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
	$self->AddData($species->id);
	my @path_names = ($hitname);
	while (my $parent = $self->{TaxonomyDB}->ancestor($species)) {
		$species = $parent;
		my $descendent_name = $species->node_name;
		my $descendent_id = $species->id;

		if (keys %{$self->{Ranks}} and not defined $self->{Ranks}->{$species->rank}) {
			next;
		}
		
		$self->AddData($descendent_id);  #wasted space in Data if branch is not in Roots.
		
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

sub AddData {
	my ($self,$id) = @_;
	if (not defined $self->{Data}{$id}) {
		$self->{Data}{$id} = 1;
	}
	else {
		$self->{Data}{$id} += 1;
	}
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
	chdir($self->{Control}->{CurrentDirectory});
}

## add file format as parameter. Save trees in individual files.
sub SaveTrees {
	my ($self,$trees) = @_;
	dbmopen(my %NAMES,"NAMES",0644) or die "Cannot open NAMES: $!";
	dbmopen(my %RANKS,"RANKS",0644) or die "Cannot open RANKS: $!";
	dbmopen(my %SEQIDS,"SEQIDS",0644) or die "Cannot open SEQIDS: $!";
	dbmopen(my %VALUES,"VALUES",0644) or die "Cannot open VALUES: $!";
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
	dbmclose(%NAMES);
	dbmclose(%RANKS);
	dbmclose(%SEQIDS);
	dbmclose(%VALUES);
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
	$self->Generate($file_name);
	bless($self,$class);
	return $self;
}

sub Generate {
	my ($self,$file_name) = @_;
	my $file_handle = open(CLASS,$file_name);
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

	my $output = new IO::File(">" . $self->{Title} . ".pact.classification.xml");
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
		
	chdir($self->{Control}->{CurrentDirectory});
}


package SendTable;
use DBI;
use base ("Process");

sub new {
     
     my ($class,$parser_name,$control) = @_;
     
     my $self = $class->SUPER::new($control);
     
     $self->{TableName} = $parser_name;
	 $self->{QueryInfo} = $self->{TableName} . "_QueryInfo";
	 $self->{AllHits} = $self->{TableName} . "_AllHits";
	 $self->{HitInfo} = $self->{TableName} . "_HitInfo";

	 chdir($self->{Control}->{CurrentDirectory});
	 
	 $self->{Control}->{Connection}->do("DROP TABLE IF EXISTS " . $self->{QueryInfo});
	 $self->{Control}->{Connection}->do("DROP TABLE IF EXISTS " . $self->{AllHits});
     $self->{Control}->{Connection}->do("DROP TABLE IF EXISTS " . $self->{HitInfo});
	 
	 
	 $self->{Control}->{Connection}->do("CREATE TABLE " . $self->{QueryInfo} .  "(query TEXT,qlength INTEGER,sequence TEXT)");
	 $self->{Control}->{Connection}->do("CREATE TABLE " . $self->{AllHits} .  "(query TEXT,rank INTEGER,hitname TEXT,percent REAL,bit REAL,
	evalue REAL,starth INTEGER,endh INTEGER,startq INTEGER,endq INTEGER)");
     $self->{Control}->{Connection}->do("CREATE TABLE " . $self->{HitInfo} .  "(hitname TEXT,gi INTEGER,description TEXT,hlength INTEGER)");
     bless($self,$class);
     return $self;

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
    $self->{Control}->{Connection}->do("INSERT INTO " . $self->{AllHits} . "(query,rank,hitname,percent,bit,evalue,starth,endh,startq,endq) 
    VALUES(?,?,?,?,?,?,?,?,?,?)",undef,($query,$rank,$hitname,$percid,$bit,$evalue,$starth,$endh,$startq,$endq));
    $self->{Control}->{Connection}->do("INSERT INTO " . $self->{HitInfo} . "(hitname,gi,description,hlength) 
    VALUES(?,?,?,?)",undef,($hitname,$gi,$descr,$hlength));
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
use File::Basename;

sub new {
	my ($class,$newick_file) = @_;
	my $self = {};
	$self->{TreeIO} = new Bio::TreeIO(-file=>$newick_file,-format=>'newick');
	$self->{Tree} = $self->{TreeIO}->next_tree;
	$self->{NAMES} = ();
	$self->{RANKS} = ();
	$self->{SEQIDS} = ();
	$self->{VALUES} = ();
	my ($filename,$directories) = fileparse($newick_file);
	chdir($directories);
	dbmopen(%{$self->{NAMES}},"NAMES",0644) or die "Cannot open tree data: $!";
	dbmopen(%{$self->{RANKS}},"RANKS",0644) or die "Cannot open tree data: $!";
	dbmopen(%{$self->{SEQIDS}},"SEQIDS",0644) or die "Cannot open tree data: $!";
	dbmopen(%{$self->{VALUES}},"VALUES",0644) or die "Cannot open tree data: $!";
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
	for my $sub_sub_node($sub_node->get_all_Descendents) {
		if ($self->{RANKS}{$sub_sub_node->id} eq $rank) {
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