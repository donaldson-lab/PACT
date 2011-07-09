use strict;
use IOManager;

my $io = IOManager->new();

package Parser;

package FASTAParser;

package BlastParser;
use Bio::SearchIO;
use Bio::SeqIO;
use XML::Simple;

sub new {
     
     my ($class,$name) = @_;
     
     my $self = {
     	BlastFile => undef,
     	FastaFile =>  undef,
     	In => undef,
     	FastaMemory => undef,
     	Parameters => undef,
     	HasTaxonomy => 0,
     	Name => $name,
     	DoneParsing => 0
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
	
	chdir($io->{Directory});
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
			my $hitdata = $self->HitData($result,$firsthit,$firsthsp);
			for my $process(@{$self->{Processes}}) {
				$process->HitRoutine($hitdata);
			}
		}
		else {
			#$self->NoHits($result->query_name);
		}
		
	}
	
	for my $process(@{$self->{Processes}}) {
				$process->EndRoutine();
	}
	for my $process(@{$self->{Processes}}) {
				$process->SaveRoutine($self->{Name});
	}
	
}

# Base class of working with table data. Not to be confused with SendTable.
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
     
     my ($class) = @_;
     
     my $self = {
     	Data => undef
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
	my ($self,$parser_name) = @_;
}

package TextPrinter;
use base ("Process");
use IOManager;

sub new {
	 my ($class,$dir) = @_;
     
     my $self = {
     	OutputDirectory => $dir, # Parent directory in which local output directory will be printed.
	 };
     
     $self->{Processes} = ();
     $self->{IO} = IOManager->new();
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
	open(HITFILE, '>>' . $self->{IO}->ReadyForFile($hitname) . ".pact.txt");
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
	my $dir = $parent . $self->{IO}->{path_separator} . $self->{IO}->ReadyForFile($hitname);
	mkdir($dir);
	# Header?
	$self->PrintHitFile($dir,$hitname,$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq);
	$self->PrintFasta($dir,$hitname,$query,$sequence);
	chdir($self->{OutputDirectory});
}

sub PrintHitFile {
	my ($self,$dir,$hitname,$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq) = @_;
	
	chdir($dir);
	open(HITFILE, '>>' . $self->{IO}->ReadyForFile($hitname) . ".pact.txt");
		
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
	open(FASTAFILE, '>>' . $self->{IO}->ReadyForFile($hitname) . ".pact.fasta");
	
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
	my ($self,$parser_name) = @_;
	for my $process(@{$self->{Processes}}) {
		$process->SaveRoutine($parser_name);
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
	my ($class,$dir,$flag_file) = @_;
	my $self = $class->SUPER::new($dir);
	$self->Generate($flag_file);
	return $self;
}

sub Generate {
	my ($self,$flag_file) = @_;
	
	open(FLAG,$flag_file);
	my $flagtitle = <FLAG>;
	chomp $flagtitle;
	$self->{Title} = $flagtitle;
	
	$self->{FlagDir} = $self->{OutputDirectory} . $self->{IO}->{path_separator} . $flagtitle;
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
	my ($class,$dir,$taxonomy) = @_;
	my $self = $class->SUPER::new($dir);
	$self->{Taxonomy} = $taxonomy;
	$self->{UnclassifiedDir} = $self->{OutputDirectory} . $self->{IO}->{path_separator} . "Unclassified";
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
	my $output = $self->{UnclassifiedDir} . $self->{IO}->{path_separator} . $self->{IO}->ReadyForFile($hitname);
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
		$dir = $self->{IO}->ReadyForFile($name) . $self->{IO}->{path_separator} . $dir;
	}
	mkpath($dir);
	$self->PrintHitFile($dir,$hitname,$query,$qlength,$descr,$hitlength,$starth,$endh,$bit,$startq,$endq);
	$self->PrintFasta($dir,$hitname,$query,$sequence);
	chdir($self->{OutputDirectory});
}

sub SaveRoutine {
	my ($self,$parser_name) = @_;
	for my $process(@{$self->{Processes}}) {
		$process->SaveRoutine($parser_name);
	}
	$self->{Taxonomy}->SaveRoutine($parser_name);
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
use XML::Writer;
use base ("Process");

sub new {
	my ($class) = @_;
     
    my $self = $class->SUPER::new();
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
	my ($self,$parser_name) = @_;
	
	sub RecursiveTraversal {
		my ($root,$writer) = @_;
		my @nodes = $root->each_Descendent;
		for my $node(@nodes) {
			$writer->startTag("node","rank"=>$node->rank,"taxonid"=>$node->id,"name"=>$node->node_name,"seqid"=>0 ,"value"=>$self->{Data}{$node->id});
			RecursiveTraversal($node,$writer);
			$writer->endTag("node");
		}
	}
	
	my $tax_dir = $io->{TaxonomyDirectory} . $io->{path_separator} . $parser_name;
	mkdir($tax_dir);
	chdir($tax_dir);
	
	my $trees = $self->GetTrees();
	
	for my $tree (@$trees) {
		my $root = $tree->get_root_node();
		my $output = new IO::File(">" . $root->node_name . ".xml");
		my $writer = new XML::Writer(OUTPUT => $output);
		$writer->startTag("root","rank"=>$root->rank,"taxonid"=>$root->id,"name"=>$root->node_name,"seqid"=>0 ,"value"=>$self->{Data}{$root->id});
		RecursiveTraversal($root,$writer);
		$writer->endTag("root");
		$writer->end();
		$output->close();
	}
	chdir($io->{Directory});
}

## add file format as parameter. Save trees in individual files.
sub SaveTrees {
	my ($self,$dir,$trees) = @_;
	for my $tree (@$trees) {
		my $title = $tree->get_root_node()->node_name;
		for my $node($tree->get_nodes) {
			my $id = $node->id;
			my $name = $node->node_name;
			$node->id($name . ":" . $self->{Data}{$id});
		}
		chdir($dir);
		open(my $handle, ">>" . $title . ".tre");
		my $out = new Bio::TreeIO(-fh => $handle, -format => 'newick');
		$out->write_tree($tree);
		close $handle;
	}
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
	my ($class,$nodesfile,$namesfile,$ranks,$roots) = @_;
	my $self = $class->SUPER::new();
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
	my ($class,$ranks,$roots) = @_;
	my $self = $class->SUPER::new();
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
use base ("Process");

sub new {
	my ($class,$file_name) = @_;
	my $self = $class->SUPER::new();
	$self->Generate($file_name);
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
	my ($self,$parser_name) = @_;
}


package SendTable;
use DBI;
use base ("Process");

sub new {
     
     my ($class,$name) = @_;
     
     my $self = {
     	Connection => undef,
     	DatabaseName => $name,
     	QueryTable => $name,
     	HitTable => $name . "Hits"
	 };
	 chdir($io->{SQLiteDatabaseDirectory});
	 $self->{Connection} = DBI->connect("dbi:SQLite:" . $self->{DatabaseName} . ".db","","") or die("Couldn't open database");
	 chdir($io->{Directory});
	 # 13 total fields
	 $self->{Connection}->do("CREATE TABLE IF NOT EXISTS " . $self->{QueryTable} .  "(query TEXT,qlength INTEGER,sequence TEXT)");
     $self->{Connection}->do("CREATE TABLE IF NOT EXISTS " . $self->{HitTable} .  "(hitname TEXT,gi INTEGER,query TEXT,rank INTEGER,description TEXT,percent REAL,bit REAL,
	evalue REAL,starth INTEGER,endh INTEGER,startq INTEGER,endq INTEGER,hlength INTEGER)");
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
	
    
    $self->{Connection}->do("INSERT INTO " . $self->{QueryTable} . "(query,qlength,sequence) VALUES(?,?,?)",undef,($query,$qlength,$sequence));
    $self->{Connection}->do("INSERT INTO " . $self->{HitTable} . "(hitname,gi,query,rank,description,percent,bit,evalue,starth,endh,startq,endq,hlength) 
    VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",undef,($hitname,$gi,$query,$rank,$descr,$percid,$bit,$evalue,$starth,$endh,$startq,$endq,$hlength));
}

package TableOperations;
use base ("Table");

sub new {
	my ($class,$connection_name) = @_;
	my $self = $class->SUPER::new();
	$self->Connect($connection_name);
	return $self;
}

sub GetDistinctHits {
	my ($self) = @_;
	my $hits = $self->{Connection}->selectall_arrayref("SELECT DISTINCT hitname FROM " . $self->{HitTable});
	return $hits;
}

sub GetHitCount {
	my ($self,$hitname) = @_;
	my $count = $self->{Connection}->selectrow_arrayref("SELECT COUNT(hitname) FROM " .
	$self->{HitTable} . " WHERE hitname=?",undef,$hitname);
	return $count->[0];
}

sub GetDistinctHitsCount {
	my ($self) = @_;
	my %hit_to_count = ();
	my $uniques = $self->GetDistinctHits();
	for my $unique(@$uniques) {
		$hit_to_count{$unique->[0]} = $self->GetHitCount($unique->[0]);
	}
	return \%hit_to_count;
}

sub GetHitsBitThresh {
	my ($self,$thresh) = @_;
	my $rows = $self->{Connection}->selectall_arrayref("SELECT * FROM " .
	$self->{HitTable} . " WHERE bit>?",undef,$thresh);
	return $rows;
}

sub ByUniqueHit {
	my ($self,$processes) = @_;
	my $uniques = $self->{Connection}->selectall_arrayref("SELECT * FROM " 
	. $self->{HitTable} . " GROUP BY hitname"); #could this be a hash?
	for my $unique(@$uniques) {
		my $hitname = $unique->[0];
		my $hrows = $self->{Connection}->selectall_arrayref("SELECT * FROM " . $self->{HitTable} . " WHERE hitname=?",undef,$hitname);
		 for my $hrow(@$hrows) {
				my ($hitname,$gi,$query,$rank,$descr,$percid,$bit,$evalue,$starth,$endh,$startq,$endq,$hlength) = @$hrow;
				my $qrow = $self->{Connection}->selectall_arrayref("SELECT * FROM " . $self->{QueryTable} . " WHERE query=?",undef,$query)->[0];
				my $sequence = $qrow->[2];
				my $qlength = $qrow->[1];
				my $hitdata = [$query,$qlength,$sequence,$hitname,$gi,$rank,$descr,$percid,$bit,$evalue,$starth,$endh,$startq,$endq,$hlength];
				for my $process(@$processes) {
					$process->HitRoutine($hitdata);
				} 
		 }
	}
}

package TaxonomyXML;
use XML::Simple;

sub new {
	my ($class,$file_name) = @_;
	my $self = {
	};
	$self->{XML} = new XML::Simple;
	$self->{TaxonomyHash} = $self->{XML}->XMLin($file_name);
	bless ($self,$class);
	return $self;
}

sub GetXMLHash {
	my $self = shift;
	return $self->{TaxonomyHash};
}

# node is a hash starting at a node.
sub PieDataRank {
	my ($self,$node,$rank) = @_;
	my %pie_data = ();
	my @names = ();
	my @values = ();
	my $total = 0;
	
	sub RecursiveTraversal {
		my ($rnode,$parent) = @_;

		if (not defined $rnode->{"taxonid"}) {
			for my $key(keys(%$rnode)) {
				RecursiveTraversal($rnode->{$key},$key);
			}
		}
		else {
			if ($rnode->{"rank"} eq $rank) {
				my $name;
				if (not $rnode->{"name"}) {
					$name = $parent;
				}
				else {
					$name = $rnode->{"name"};
				}
				push(@names,$name);
				push(@values,$rnode->{"value"});
				$total += $rnode->{"value"};
			}
			
			if (defined $rnode->{"node"}) {
				RecursiveTraversal($rnode->{"node"},"");
			}
			else {
				return 0;
			}
		}
	}

	RecursiveTraversal($node,"");
	$pie_data{"Names"} = \@names;
	$pie_data{"Values"} = \@values;
	$pie_data{"Total"} = $total;
	return \%pie_data;
}

sub PieDataNode {
	my ($self,$node_name,$sub_rank) = @_;
	
	my $sub_node;
	
	sub RecursiveTraversalFindNode {
		my ($node,$parent) = @_;
		if (not defined $node->{"taxonid"}) {
			for my $key(keys(%$node)) {
				if ($key eq $node_name) {
					$sub_node = $node->{$key};
					return 1;
				}
				else {
					RecursiveTraversalFindNode($node->{$key},$key);
				}
			}
		}
		else {
			if (defined $node->{"node"}) {
				if ($node->{"name"} eq $node_name) {
					$sub_node = $node;
					return 1;
				}
				else {
					RecursiveTraversalFindNode($node->{"node"},"");
				}
			}
			else {
				return 0;
			}
		}
	}
	
	RecursiveTraversalFindNode($self->{TaxonomyHash},"");
	return $self->PieDataRank($sub_node,$sub_rank);
}



1;