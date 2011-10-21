use strict;
use Wx;
use Parser;
use PieViewer;
use TaxonomyViewer;
use IO::File;
use Cwd;

# Global colors
my $turq = Wx::Colour->new("SEA GREEN");
my $blue = Wx::Colour->new("SKY BLUE");

package ProgramControl;
use DBI;
use Cwd;
use LWP::Simple;
use Archive::Tar;
use Fcntl;
use DB_File;
use File::Path;
use File::Find;
use File::Basename;

sub new {
	my $class = shift;
	my $self = {};
	bless ($self,$class);
	$self->GetPathSeparator();
	$self->GetCurrentDirectory();
	$self->MakeResultsFolder();
	$self->ParserNames();
	$self->CreateDatabase();
	$self->MakeColorPrefsFolder();
	$self->SetTaxDump();
	return $self;
}

sub GetCurrentDirectory {
	my ($self) = @_;
	if (($self->{OS} eq "darwin") or ($self->{OS} eq "MacOS")) {
		my $owner = getpwuid($>);
		$self->{CurrentDirectory} = "/Users/" . $owner . "/PACT";
	}
	else {
		
	}
}

sub SetTaxDump {
	my ($self) = @_;
	$self->{TaxDump} = $self->{CurrentDirectory} . $self->{PathSeparator} . "taxdump";
	mkdir($self->{TaxDump});
	chdir($self->{TaxDump});
	$self->{NodesFile} = $self->{TaxDump} . $self->{PathSeparator} . "nodes.dmp";
	$self->{NamesFile} = $self->{TaxDump} . $self->{PathSeparator} . "names.dmp";
}

sub DownloadNCBITaxonomies {
	my $self = shift;
	
	## errors: what if no connection? File does not exist?
	
	my $url = "ftp://ftp.ncbi.nih.gov/pub/taxonomy/";
	my $file = "taxdump.tar.gz";
	getstore("$url/$file",$file);
	my $tar = Archive::Tar->new;
	$tar->read($file);
	$tar->extract();
	unlink($file);
}

sub MakeResultsFolder {
	my $self = shift;
	$self->{Results} = $self->{CurrentDirectory} . $self->{PathSeparator} . "Results";
	mkdir $self->{Results};
}

sub CreateResultFolder {
	my ($self,$parser_key) = @_;
	my $internal_directory = $self->{Results} . $self->{PathSeparator} . $parser_key;
	if (-d $internal_directory) {
		rmtree($internal_directory);
	}
	mkdir($internal_directory);
	$internal_directory;
}

sub DeleteResult {
	my ($self,$key) = @_;
	chdir($self->{Results});
	tie(my %PARSERNAMES,'DB_File',"PARSERNAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
	if (defined $PARSERNAMES{$key}) {
		$self->RemoveResultFolder($key);
		delete $PARSERNAMES{$key};
	}
	tie(my %TABLENAMES,'DB_File',"TABLENAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
	if (defined $TABLENAMES{$key}) {
		$self->RemoveResultTables($key);
		delete $TABLENAMES{$key};
	}
}

## Gets the size of the results folder in megabytes
sub GetDirSize {
	my ($self,$key) = @_;
	chdir($self->{Results});
	my $size = 0;
	opendir(DIR, $key) or die $!;

    while (my $file = readdir(DIR)) {
    	next if ($file =~ m/^\./);
		my $file_path = $self->{Results} . $self->{PathSeparator} . $key . $self->{PathSeparator} . $file;
		$size += -s $file_path;
    }
    close DIR;
    my $mega = sprintf("%.1f",$size/1000000);
	return "$mega MB";
}

sub RemoveResultFolder {
	my ($self,$key) = @_;
	chdir($self->{Results});
	rmtree($key);
}

sub ParserNames {
	my ($self) = @_;
	chdir($self->{Results});
	tie(my %PARSERNAMES,'DB_File',"PARSERNAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
}

sub AddParserName {
	my ($self,$parser_name) = @_;
	chdir($self->{Results});
	# Assigns a unique identifier to a parser name. the identifier will be used as a Result folder name/ database table name.
	tie(my %PARSERNAMES,'DB_File',"PARSERNAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
	my $name_key = $self->GenerateResultKey();
	while (defined $PARSERNAMES{$name_key}) {
		$name_key = $self->GenerateResultKey();
	}
	$PARSERNAMES{$name_key} = $parser_name;
	return $name_key;
}

sub GetParserName {
	my ($self,$key) = @_;
	chdir($self->{Results});
	tie(my %PARSERNAMES,'DB_File',"PARSERNAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
	$PARSERNAMES{$key};
}

sub GetParserNames {
	my ($self) = @_;
	chdir($self->{Results});
	tie(my %PARSERNAMES,'DB_File',"PARSERNAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
	return \%PARSERNAMES;
}

sub AddResultsBox {
	my ($self,$box) = @_;
	chdir($self->{Results});
	tie(my %TABLENAMES,'DB_File',"TABLENAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
	while ( my ($key, $value) = each(%TABLENAMES) ) {
		$box->AddFile($key,$value);
	}
}

sub AddTableName {
	my ($self,$label,$key) = @_;
	chdir($self->{Results});
	tie(my %TABLENAMES,'DB_File',"TABLENAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open TableNames: $!";
	$TABLENAMES{$key} = $label;
}

sub GetTableNames {
	my ($self) = @_;
	chdir($self->{Results});
	tie(my %TABLENAMES,'DB_File',"TABLENAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open TableNames: $!";
	return \%TABLENAMES;
}

sub GenerateResultKey {
	my ($self) = @_;
	my @alpha = ("a".."z");
	my @timeData = localtime(time);
	srand;
	my $name_key = "";
	foreach (1..3) 
	{    
		my $rand = int(rand scalar(@alpha));
		$name_key = $name_key . $alpha[$rand];
	}
	$name_key = $name_key . "d" . $timeData[3] . "m" . $timeData[4] . "y" . $timeData[5];
	return $name_key;
}

sub AddTaxonomy {
	my ($self,$tax_name) = @_;
	tie(my %TAXES,'DB_File',"TAXONOMIES.db",O_CREAT|O_RDWR,0644) or die "Cannot open Taxonomies: $!";
	my $key = $self->GenerateTaxonomyKey();
	while (defined $TAXES{$key}) {
		$key = $self->GenerateTaxonomyKey();
	}
	$TAXES{$key} = $tax_name;
	dbmclose(%TAXES);
	return $key;
}

sub AddClassification {
	my ($self,$class_name) = @_;
	tie(my %CLASSES,'DB_File',"CLASSIFICATIONS.db",O_CREAT|O_RDWR,0644) or die "Cannot open Taxonomies: $!";
	my $key = $self->GenerateClassificationKey();
	while (defined $CLASSES{$key}) {
		$key = $self->GenerateClassificationKey();
	}
	$CLASSES{$key} = $class_name;
	dbmclose(%CLASSES);
	return $key;
}

sub GenerateClassificationKey {
	my ($self) = @_;
	my @alpha = ("a".."z");
	srand;
	my $name_key = "C";
	foreach (1..3) 
	{    
		my $rand = int(rand scalar(@alpha));
		$name_key = $name_key . $alpha[$rand];
	}
	return $name_key;
}

sub GetClassificationLabel {
	my ($self,$key,$parser_name) = @_;
	chdir($self->{Results} . $self->{PathSeparator} . $parser_name);
	tie(my %CLASSES,'DB_File',"CLASSIFICATIONS.db",O_CREAT|O_RDWR,0644) or die "$!";
	my $label = $CLASSES{$key};
	dbmclose(%CLASSES);
	return $label;
}

sub GetTaxonomyLabel {
	my ($self,$key,$parser_name) = @_;
	chdir($self->{Results} . $self->{PathSeparator} . $parser_name);
	tie(my %TAXES,'DB_File',"TAXONOMIES.db",O_CREAT|O_RDWR,0644) or die "$!";
	my $label = $TAXES{$key};
	dbmclose(%TAXES);
	return $label;
}

# Loops through all parsing results to get all Taxonomy files. Inserts parser name and label into a file box.
sub GetTaxonomyFiles {
	my ($self,$file_box) = @_;
	
	my $parser_names = $self->GetParserNames();
	
	my $dir = $self->{Results};
	opendir(DIR, $dir) or die $!;

    while (my $key = readdir(DIR)) {
    	next if ($key =~ m/^\./);
		next unless (-d "$dir/$key");  #needs to be path separator
		opendir(RESULTDIR, "$dir/$key") or die $!;
		while (my $file = readdir(RESULTDIR)) {
        	next if ($file =~ m/^\./ or not $file =~ m/\.tre/);
        	my @splitnames = split(/\./,$file);
        	my $label = $parser_names->{$key} . ": " . $self->GetTaxonomyLabel($splitnames[0],$key);
			$file_box->AddFile("$dir/$key/$file",$label);
   		}
   		close RESULTDIR;
    }
    close DIR;
}

sub GetTaxonomyNodeNames {
	my ($self,$file_path) = @_;
	my ($filename,$directories) = fileparse($file_path);
	chdir($directories);
	tie(my %NAMES,'DB_File',"NAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
	return \%NAMES;
}

sub GetTaxonomyNodeRanks {
	my ($self,$file_path) = @_;
	my ($filename,$directories) = fileparse($file_path);
	chdir($directories);
	tie(my %RANKS,'DB_File',"RANKS.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
	return \%RANKS;
}

sub GetTaxonomyNodeIds {
	my ($self,$file_path) = @_;
	my ($filename,$directories) = fileparse($file_path);
	chdir($directories);
	tie(my %SEQIDS,'DB_File',"SEQIDS.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
	return \%SEQIDS;
}

sub GetTaxonomyNodeValues {
	my ($self,$file_path) = @_;
	my ($filename,$directories) = fileparse($file_path);
	chdir($directories);
	tie(my %VALUES,'DB_File',"VALUES.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
	return \%VALUES;
}

sub GenerateTaxonomyKey {
	my ($self) = @_;
	my @alpha = ("a".."z");
	srand;
	my $name_key = "";
	foreach (1..3) 
	{    
		my $rand = int(rand scalar(@alpha));
		$name_key = $name_key . $alpha[$rand];
	}
	return $name_key;
}

sub GetClassificationFiles {
	my ($self,$file_box) = @_;
	
	my $parser_names = $self->GetParserNames();
	
	my $dir = $self->{Results};
	opendir(DIR, $dir) or die $!;

    while (my $key = readdir(DIR)) {
    	next if ($key =~ m/^\./);
		next unless (-d "$dir/$key");
		opendir(RESULTDIR, "$dir/$key") or die $!;
		while (my $file = readdir(RESULTDIR)) {
        	next if ($file =~ m/^\./ or not $file =~ m/\.xml/);
        	my @splitnames = split(/\./,$file);
        	my $label = $parser_names->{$key} . ": " . $self->GetClassificationLabel($splitnames[0],$key);;
			$file_box->AddFile("$dir/$key/$file",$label);
   		}
   		close RESULTDIR;
    }
    close DIR;
}

sub MakeColorPrefsFolder {
	my $self = shift;
	$self->{ColorPrefs} = $self->{CurrentDirectory} . $self->{PathSeparator} . "ColorPrefs";
	mkdir $self->{ColorPrefs};
}

sub CreateDatabase {
	my ($self) = @_;
	chdir($self->{Results});
	#$self->{Connection} = DBI->connect("DBI:mysql:database=test;host=127.0.0.1","","") or die("Cannot open");
	$self->{Connection} = DBI->connect("dbi:SQLite:Results.db","","") or die("Could not open database");
	tie(my %TABLENAMES,'DB_File',"TABLENAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open TableNames: $!";
}

sub RemoveResultTables {
	my ($self,$key) = @_;
	$self->{Connection}->do("DROP TABLE $key" . "_AllHits");
	$self->{Connection}->do("DROP TABLE $key" . "_HitInfo");
	$self->{Connection}->do("DROP TABLE $key" . "_QueryInfo");
	$self->{Connection}->do("VACUUM");
}

sub GetPathSeparator {
	my ($self) = @_;
	$self->{OS} = $^O;
	if (($self->{OS} eq "darwin") or ($self->{OS} eq "MacOS") or ($self->{OS} eq "linux")) {
		$self->{PathSeparator} = "/";
	}
	elsif ($self->{OS} eq "MSWin32") {
		$self->{PathSeparator} = "\/";
	}
	else {
		exit;
	}
}

# Processes string to use as filename
sub ReadyForFile {
    my($self,$name) = @_;
    
    $name =~s/\//_/g;
    $name =~s/\:/_/g;
    $name =~s/\*/_/g;
    $name =~s/\?/_/g;
    $name =~s/\\/_/g;
    $name =~s/\</_/g;
    $name =~s/\>/_/g;
    $name =~s/\"/_/g;
    $name =~s/\|/_/g;
    
    if (length ($name) > 100) {
    	$name = substr($name,0,100)
    }
    return $name;
}

#Processes string for use as a database table name
sub ReadyForDB {
    my($self,$name) = @_;
    
    $name =~s/\./_/g;
    
    if (length ($name) > 100) {
    	$name = substr($name,0,100)
    }
    return $name;
}

sub CheckResultFolder {
	my ($self,$parser_name) = @_;
	if (-d $self->{Results} . $self->{PathSeparator} . $parser_name) {
		return 0;
	}
	return 1;
}

my $control = ProgramControl->new();

package OkDialog;
use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use base 'Wx::Dialog';

# Takes a parent (frame base class), the function and its parameters, and a title. 
sub new {
	my ($class,$parent,$title,$dialog) = @_;
	my $px = $parent->GetPosition()->x;
	my $py = $parent->GetPosition()->y;
	my $pwidth = $parent->GetSize()->width;
	my $pheight = $parent->GetSize()->height;
	my $twidth = $pwidth/4;
	my $theight = $pheight/3;
	my $size = Wx::Size->new($twidth,$theight);
	my $tx = $px + $pwidth/2 - $twidth/2; 
	my $ty = $py + $pheight/2 - $theight/2;
	my $self = $class->SUPER::new(undef,-1,$title,[$tx,$ty],[$twidth,$theight],);
	$self->SetMinSize($size);
	$self->SetMaxSize($size);
	bless ($self,$class);
	$self->Display($parent,$title,$dialog,$twidth);
	return $self;
}

sub Display {
	my ($self,$parent,$title,$dialog,$width) = @_;
	$self->{Panel} = Wx::Panel->new($self,-1);
	$self->{Panel}->SetBackgroundColour($turq);
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $text_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $text = Wx::StaticText->new($self->{Panel},-1,$dialog);
	$text->Wrap($width);
	$text_sizer->Add($text,1,wxCENTER);
	
	my $button_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{Ok} = Wx::Button->new($self->{Panel},wxID_OK,"Ok");
	$self->{Cancel} = Wx::Button->new($self->{Panel},wxID_CANCEL,"Cancel");
	$button_sizer->Add($self->{Ok},1,wxCENTER|wxRIGHT,10);
	$button_sizer->Add($self->{Cancel},1,wxCENTER|wxLEFT,10);
	
	$sizer->Add($text_sizer,1,wxCENTER);
	$sizer->Add($button_sizer,2,wxCENTER);
	$self->{Panel}->SetSizer($sizer);
}


package FileBox;
use Wx qw /:everything/;

sub new {
	my ($class,$parent) = @_;
	
	my $self = {};
	$self->{FileArray} = ();
	$self->{ListBox} = Wx::ListBox->new($parent,-1);
	bless ($self,$class);
	return $self;
}

sub AddFile {
	my ($self,$file_path,$file_label) = @_;
	$self->{ListBox}->Insert($file_label,$self->{ListBox}->GetCount);
	push(@{$self->{FileArray}},$file_path);
}

sub GetFile {
	my $self = shift;
	return $self->{FileArray}[$self->{ListBox}->GetSelection];
}

sub GetAllFiles {
	my $self = shift;
	return $self->{FileArray};
}

sub DeleteFile {
	my $self = shift;
	my $selection = $self->{ListBox}->GetSelection;
	splice(@{$self->{FileArray}},$selection,1);
	$self->{ListBox}->Delete($selection);
}


package TreeMenu;
use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use Wx::Event qw(EVT_LISTBOX_DCLICK);
use base 'Wx::Panel';
use Cwd;
use Fcntl;
use DB_File;

sub new {
	my ($class,$parent) = @_;
	
	my $self = $class->SUPER::new($parent,-1);
	$self->SetBackgroundColour($turq);
	$self->{TreeListBox} = undef;
	$self->{TreeFormats} = {"Newick"=>"newick","New Hampshire"=>"nhx","PhyloXML"=>"phyloxml"};
	bless ($self,$class);
	$self->TreeBox();
	$self->FillTrees();
	$self->Layout;
	return $self;
}

sub TreeBox {
	my ($self) = @_;
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $center_panel = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$center_panel->SetBackgroundColour($blue);
	my $center_panel_sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $label_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $label_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $label = Wx::StaticText->new($self,-1,"Choose a tree to save:");
	$label_sizer_v->Add($label,1,wxCENTER);
	$label_sizer_h->Add($label_sizer_v,1,wxCENTER);
	
	my $tree_list_sizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{TreeFileListBox} = FileBox->new($center_panel);
	$tree_list_sizer->Add($self->{TreeFileListBox}->{ListBox},1,wxEXPAND);
	my $f_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $f_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $format_label = Wx::StaticBox->new($center_panel,-1,"File format:");
	my $format_sizer = Wx::StaticBoxSizer->new($format_label,wxVERTICAL);
	my @formats = keys(%{$self->{TreeFormats}});
	$self->{FormatChoice} = Wx::ComboBox->new($center_panel,-1,"",wxDefaultPosition(),wxDefaultSize(),\@formats,wxCB_DROPDOWN);
	$format_sizer->Add($self->{FormatChoice},1,wxEXPAND);
	$f_sizer_v->Add($format_sizer,1,wxCENTER);
	$f_sizer_h->Add($f_sizer_v,1,wxCENTER);
	my $button_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $button_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $save_button = Wx::Button->new($self,-1,"Save");
	$button_sizer_v->Add($save_button,1,wxCENTER);
	$button_sizer_h->Add($button_sizer_v,1,wxCENTER);

	$center_panel_sizer->Add($tree_list_sizer,4,wxEXPAND);
	$center_panel_sizer->Add($f_sizer_h,1,wxEXPAND);
	$center_panel->SetSizer($center_panel_sizer);
	
	$sizer->Add($label_sizer_h,1,wxEXPAND);
	$sizer->Add($center_panel,8,wxEXPAND|wxLEFT|wxRIGHT,10);
	$sizer->Add($button_sizer_h,1,wxCENTER);
	$self->SetSizer($sizer);

	EVT_BUTTON($self,$save_button,sub{$self->SaveTree()});
}

sub FillTrees {
	my ($self) = @_;
	$control->GetTaxonomyFiles($self->{TreeFileListBox});
}

sub SaveTree {
	my ($self) = @_;
	my $save_dialog = Wx::FileDialog->new($self,"",$control->{CurrentDirectory},"","*.*",wxFD_SAVE);
	if ($save_dialog->ShowModal == wxID_OK) {
		my $file = $self->{TreeFileListBox}->GetFile();
		my $format = $self->{TreeFormats}->{$self->{FormatChoice}->GetValue};
		if ($format eq "") {
			$format = "newick";
		}
		my $names = $control->GetTaxonomyNodeNames($file);
		my $treeio = new Bio::TreeIO(-format => "newick", -file => $file);
		my $tree = $treeio->next_tree;
		open(my $handle, ">>" . $save_dialog->GetPath() . ".tre");
		my $savetree = new Bio::TreeIO(-format => $format, -fh => $handle);
		for my $node($tree->get_nodes) {
			$node->id($names->{$node->id});
		}
		$savetree->write_tree($tree);
	}
	$save_dialog->Destroy;
}

package ClassificationTypePanel;

use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use Wx::Event qw(EVT_TEXT);
use Wx::Event qw(EVT_CHECKBOX);
use Wx::Event qw(EVT_COMBOBOX);
use Wx::Event qw(EVT_LISTBOX);
use Wx::Event qw(EVT_LISTBOX_DCLICK);

use base 'Wx::Panel';

sub new {
	my ($class,$parent,$class_file,$class_label) = @_;
	
	my $self = $class->SUPER::new($parent,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$self->{Label} = $class_label;
	$self->{DataReader} = undef;
	$self->{TitleBox} = undef;
	$self->{ClassifierBox} = undef;
	
	bless ($self,$class);
	$self->Display($class_file);
	return $self;
}

sub Display {
	my ($self,$class_file) = @_;
	$self->SetBackgroundColour($blue);
	
	if ($class_file ne "") {
		$self->{DataReader} = ClassificationXML->new($class_file);
	}
	
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $title_label = Wx::StaticBox->new($self,-1,"Title");
	my $title_label_sizer = Wx::StaticBoxSizer->new($title_label,wxHORIZONTAL);
	my $title_sizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{TitleBox} = Wx::TextCtrl->new($self,-1,"");
	$title_sizer->Add($self->{TitleBox},1,wxEXPAND|wxCENTER);
	$title_label_sizer->Add($title_sizer,1,wxEXPAND);
	
	my $fill_label = Wx::StaticBox->new($self,-1,"Choose Classifier");
	my $fill_label_sizer = Wx::StaticBoxSizer->new($fill_label,wxVERTICAL);
	$self->{ClassifierBox} = Wx::ListBox->new($self,-1,wxDefaultPosition(),wxDefaultSize(),[]);
	if (defined $self->{DataReader}) {
		$self->FillClassifiers($self->{ClassifierBox},$self->{DataReader});
	}
	$fill_label_sizer->Add($self->{ClassifierBox},5,wxCENTER|wxEXPAND);
	
	$sizer->Add($title_label_sizer,1,wxEXPAND|wxTOP,10);
	$sizer->Add($fill_label_sizer,3,wxCENTER|wxEXPAND,5);
	
	$self->SetSizer($sizer);
	$self->Layout;
	$self->Show;
}

sub FillClassifiers {
	my ($self,$listbox,$data_reader) = @_;
	my $classifiers = $data_reader->GetClassifiers();
	$listbox->Insert("All",0);
	my $count = 1;
	for my $classifier (@$classifiers) {
		$listbox->Insert($classifier,$count);
		$count++;
	}
	$self->Refresh;
}

sub CopyData {
	my ($self,$panel) = @_;
	$self->{DataReader} = $panel->{DataReader};
	$self->{TitleBox}->SetValue($panel->{TitleBox}->GetValue);
	$self->{ClassifierBox}->SetSelection($panel->{ClassifierBox}->GetSelection);
}

package TaxonomyTypePanel;

use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use Wx::Event qw(EVT_TEXT);
use Wx::Event qw(EVT_CHECKBOX);
use Wx::Event qw(EVT_COMBOBOX);
use Wx::Event qw(EVT_LISTBOX);
use Wx::Event qw(EVT_LISTBOX_DCLICK);

use base 'Wx::Panel';

sub new {
	my ($class,$parent,$tax_file,$tax_label) = @_;
	my $self = $class->SUPER::new($parent,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$self->{Label} = $tax_label;
	$self->{DataReader} = undef;
	$self->{TitleBox} = undef;
	$self->{RankBox} = undef;
	$self->{NodeBox} = undef;
	bless ($self,$class);
	$self->Display($tax_file);
	return $self;
}

sub Display {
	my ($self,$tax_file) = @_;
	$self->SetBackgroundColour($blue);
	
	if ($tax_file =~ /.tre/) {
		my $names = $control->GetTaxonomyNodeNames($tax_file);
		my $ranks = $control->GetTaxonomyNodeRanks($tax_file);
		my $seqids = $control->GetTaxonomyNodeIds($tax_file);
		my $values = $control->GetTaxonomyNodeValues($tax_file);
		$self->{DataReader} = TaxonomyData->new($tax_file,$names,$ranks,$seqids,$values);
	}
	elsif ($tax_file ne "") {
		$self->{DataReader} = TaxonomyXML->new($tax_file);
	}

	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	$self->AddTitleBox($sizer);
	
	my $level_sizer = Wx::BoxSizer->new(wxHORIZONTAL);	
	my $tax_label = Wx::StaticBox->new($self,-1,"Select Level: ");
	my $tax_label_sizer = Wx::StaticBoxSizer->new($tax_label,wxHORIZONTAL);
	my $levels = ["kingdom","phylum","order","family","genus","species"];
	$self->{RankBox} = Wx::ComboBox->new($self,-1,"",wxDefaultPosition(),wxDefaultSize(),$levels,wxCB_DROPDOWN);
	$tax_label_sizer->Add($self->{RankBox},1,wxCENTER);
	
	my $fill_label = Wx::StaticBox->new($self,-1,"Select Node");
	my $fill_label_sizer = Wx::StaticBoxSizer->new($fill_label,wxVERTICAL);
	$self->{NodeBox} = Wx::ListBox->new($self,-1,wxDefaultPosition(),wxDefaultSize(),[]);
	$fill_label_sizer->Add($self->{NodeBox},1,wxCENTER|wxEXPAND|wxTOP|wxLEFT|wxRIGHT,10);
	if (defined $self->{DataReader}) {
		$self->FillNodes($self->{NodeBox},$self->{DataReader});
	}

	$sizer->Add($fill_label_sizer,3,wxCENTER|wxEXPAND,5);
	$sizer->Add($tax_label_sizer,1,wxCENTER|wxEXPAND,5);

	
	$self->SetSizer($sizer);
	$self->Layout;
}

sub AddTitleBox {
	my ($self,$sizer) = @_;
}

sub CopyData {
	my ($self,$panel) = @_;
	$self->{DataReader} = $panel->{DataReader};
	$self->{TitleBox}->SetValue($panel->{TitleBox}->GetValue);
	my @ranks = ();
	for my $rank($self->{RankBox}->GetStrings) {
		push(@ranks,$rank);
	}
	$self->{RankBox}->SetValue($panel->{RankBox}->GetValue);
	my @nodes = ();
	for my $node($self->{NodeBox}->GetStrings) {
		push(@nodes,$node);
	}
	$self->{NodeBox}->Set(\@nodes);
	$self->{NodeBox}->SetSelection($panel->{NodeBox}->GetSelection);
}

sub FillNodes {
	my ($self,$listbox,$data_reader) = @_;
	
	my $nodes = $data_reader->GetNamesAlphabetically();
	my $count = 0;
	for my $node (@$nodes) {
		$listbox->Insert($node,$count);
		$count++;
	}
}

package TaxonomyTypePanelTitle;
use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use Wx::Event qw(EVT_TEXT);
use Wx::Event qw(EVT_CHECKBOX);
use Wx::Event qw(EVT_COMBOBOX);
use Wx::Event qw(EVT_LISTBOX);
use Wx::Event qw(EVT_LISTBOX_DCLICK);

use base ("TaxonomyTypePanel");

sub AddTitleBox {
	my ($self,$sizer) = @_;
	my $title_label = Wx::StaticBox->new($self,-1,"Title");
	my $title_label_sizer = Wx::StaticBoxSizer->new($title_label,wxHORIZONTAL);
	my $title_sizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{TitleBox} = Wx::TextCtrl->new($self,-1,"");
	$title_sizer->Add($self->{TitleBox},1,wxEXPAND|wxCENTER);
	$title_label_sizer->Add($title_sizer,1,wxEXPAND);
	
	$sizer->Add($title_label_sizer,1,wxEXPAND,10);
}



package ClassificationPiePanel;

use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use Wx::Event qw(EVT_TEXT);
use Wx::Event qw(EVT_CHECKBOX);
use Wx::Event qw(EVT_COMBOBOX);
use Wx::Event qw(EVT_LISTBOX);
use Wx::Event qw(EVT_LISTBOX_DCLICK);

use base 'Wx::Panel';
use Fcntl;
use DB_File;

sub new {
	my ($class,$parent,$file_label,$group_label) = @_;
	
	my $self = $class->SUPER::new($parent,-1);
	$self->SetBackgroundColour($turq);
	
	$self->{TypePanel} = undef;
	$self->{Sizer} = undef; 
	$self->{FileHash} = ();
	$self->{PiePanels} = ();
	$self->{NewPanels} = ();
	
	$self->{FileLabel} = $file_label;
	$self->{GroupLabel} = $group_label;
	
	bless ($self,$class);
	$self->MainDisplay();
	$self->Layout;
	return $self;
}

sub MainDisplay {
	my ($self) = @_;

	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	$self->CenterDisplay();
	
	$self->{GeneratePanel} = Wx::Panel->new($self,-1);
	$self->{GeneratePanel}->SetBackgroundColour($turq);
	
	my $gbutton_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $gbutton_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $generate_button = Wx::Button->new($self->{GeneratePanel},-1,"Generate");
	$gbutton_sizer_v->Add($generate_button,1,wxCENTER);
	$gbutton_sizer_h->Add($gbutton_sizer_v,1,wxCENTER);
	$self->{GeneratePanel}->SetSizer($gbutton_sizer_h);
	
	$sizer->Add($self->{CenterDisplay},7,wxEXPAND);
	$sizer->Add($self->{GeneratePanel},1,wxEXPAND);
	
	$self->SetSizer($sizer);

	$self->Layout;
	
	EVT_BUTTON($self->{GeneratePanel},$generate_button,sub{$self->GenerateCharts()});
}

sub CenterDisplay {

	my ($self) = @_;

	$self->{CenterDisplay} = Wx::BoxSizer->new(wxHORIZONTAL);

	my $file_panel = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$file_panel->SetBackgroundColour($blue);
	my $file_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	
	my $file_list_label = Wx::StaticBox->new($file_panel,-1,$self->{FileLabel});
	my $file_list_label_sizer = Wx::StaticBoxSizer->new($file_list_label,wxVERTICAL);
	my $browse_button = Wx::Button->new($file_panel,-1,"Browse");
	$self->{FileBox} = FileBox->new($file_panel);
	$file_list_label_sizer->Add($browse_button,1,wxCENTER);
	$file_list_label_sizer->Add($self->{FileBox}->{ListBox},7,wxEXPAND);
	
	$file_sizer->Add($file_list_label_sizer,3,wxCENTER|wxEXPAND);
	$file_panel->Layout;
	$file_panel->SetSizer($file_sizer);
	
	my $chart_button_sizer_outer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $chart_button_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $add_button = Wx::Button->new($self,-1,"Add");
	my $remove_button = Wx::Button->new($self,-1,"Remove");
	$chart_button_sizer->Add($add_button,1,wxCENTER|wxBOTTOM,10);
	$chart_button_sizer->Add($remove_button,1,wxCENTER|wxTOP,10);
	$chart_button_sizer_outer->Add($chart_button_sizer,1,wxCENTER);
	
	$self->{EmptyPanel} = $self->NewTypePanel();
	$self->{TypePanel} = $self->{EmptyPanel};
	
	my $chart_panel = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$chart_panel->SetBackgroundColour($blue);
	my $chart_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	
	my $chart_list_label = Wx::StaticBox->new($chart_panel,-1,$self->{GroupLabel});
	my $chart_list_label_sizer = Wx::StaticBoxSizer->new($chart_list_label,wxVERTICAL);
	$self->{ChartBox} = FileBox->new($chart_panel);
	$chart_list_label_sizer->Add($self->{ChartBox}->{ListBox},1,wxEXPAND);
	
	$chart_sizer->Add($chart_list_label_sizer,3,wxCENTER|wxEXPAND);
	$chart_panel->Layout;
	$chart_panel->SetSizer($chart_sizer);
	
	$self->{CenterDisplay}->Add($file_panel,3,wxTOP|wxCENTER|wxEXPAND|wxBOTTOM,10);
	$self->{CenterDisplay}->Add($self->{TypePanel},5,wxTOP|wxBOTTOM|wxCENTER|wxEXPAND,10);
	$self->{CenterDisplay}->Add($chart_button_sizer_outer,1,wxCENTER|wxEXPAND,10);
	$self->{CenterDisplay}->Add($chart_panel,3,wxTOP|wxCENTER|wxEXPAND|wxBOTTOM,10);
	
	EVT_LISTBOX($self,$self->{FileBox}->{ListBox},sub{$self->DisplayNew(); $self->{ChartBox}->{ListBox}->SetSelection(-1);});
	EVT_LISTBOX($self,$self->{ChartBox}->{ListBox},sub{$self->DisplayPiePanel();});
	EVT_BUTTON($self,$browse_button,sub{$self->LoadFile()});
	EVT_BUTTON($self,$add_button,sub{$self->AddPieChart();});
	EVT_BUTTON($self,$remove_button,sub{$self->DeleteChart();});
}

sub AddPieChart {
	my ($self) = @_;
	$self->{ChartBox}->AddFile($self->{FileBox}->GetFile(),$self->{FileBox}->{ListBox}->GetStringSelection());
	my $pie_panel = $self->NewTypePanel();
	$pie_panel->CopyData($self->{TypePanel});
	$pie_panel->Hide;
	push(@{$self->{PiePanels}},$pie_panel);
}

sub DeleteChart {
	my ($self) = @_;
	my $delete_dialog = OkDialog->new($self,"Delete","Remove " . $self->{ChartBox}->{ListBox}->GetStringSelection() . "?");
	if ($delete_dialog->ShowModal == wxID_OK) {
		my $selection = $self->{ChartBox}->{ListBox}->GetSelection();
		$self->{ChartBox}->{ListBox}->Delete($selection);
		my $pie_panel = $self->{PiePanels}->[$selection];
		splice(@{$self->{PiePanels}},$selection,1);
		if (@{$self->{PiePanels}} == 0) {
			$self->{FileBox}->{ListBox}->SetSelection(0);
			$self->DisplayNew();
		}
		else {
			$self->{ChartBox}->{ListBox}->SetSelection(0);
			$self->DisplayPiePanel();
		}
		$pie_panel->Destroy;
	}
	$delete_dialog->Destroy;
}

sub DisplayPiePanel {
	my ($self) = @_;
	my $selection = $self->{ChartBox}->{ListBox}->GetSelection;
	my $pie_panel = $self->{PiePanels}->[$selection];
	while (my ($selection,$panel) = each %{$self->{NewPanels}}) {
		$panel->Hide;
	}
	for my $panel(@{$self->{PiePanels}}) {
		if ($panel eq $pie_panel) {
			$pie_panel->Show;
		}
		else {
			$panel->Hide;
		}
	}
	
	$self->{CenterDisplay}->Replace($self->{TypePanel},$pie_panel);
	$self->{CenterDisplay}->Layout;
	$self->Refresh;
	$self->{TypePanel} = $pie_panel;
	$self->{FileBox}->{ListBox}->SetSelection(-1);
}

sub LoadFile {
	my ($self) = @_;
	my $dialog = 0;
	my $file_label = "";
	$dialog = Wx::FileDialog->new($self,"Choose Results");
	if ($dialog->ShowModal==wxID_OK) {
		my @split = split($control->{PathSeparator},$dialog->GetPath);
		for (my $i=@split - 1; $i>0; $i--) {
			if ($i==@split - 2) {
				$file_label = $split[$i] . $control->{PathSeparator} . $file_label;
				last;
			}
			$file_label = $split[$i] . $file_label;
		}
	}
	$self->{FileBox}->AddFile($dialog->GetPath,$file_label);
	$self->{FileBox}->{ListBox}->SetSelection($self->{FileBox}->{ListBox}->GetCount - 1);
	$self->DisplayNew();
	
}

sub DisplayNew {
	my ($self) = @_;
	my $file_selection = $self->{FileBox}->{ListBox}->GetSelection;
	my $new_panel;
	if (exists $self->{NewPanels}{$file_selection}) {
		$new_panel = $self->{NewPanels}{$file_selection};
		$new_panel->{Label} = $self->{FileBox}->{ListBox}->GetStringSelection;
	}
	else {
		$new_panel = $self->NewTypePanel();
		$self->{NewPanels}{$file_selection} = $new_panel;
	}
	for my $panel(@{$self->{PiePanels}}) {
		$panel->Hide;
	}
	while (my ($selection,$panel) = each %{$self->{NewPanels}}) {
		if ($new_panel eq $panel) {
			$panel->Show;
		}
		else {
			$panel->Hide;
		}
	}
	$self->{CenterDisplay}->Replace($self->{TypePanel},$new_panel);
	$self->{CenterDisplay}->Layout;
	$self->Refresh;
	$self->{TypePanel} = $new_panel;
	if (defined $self->{EmptyPanel}) {
		$self->{EmptyPanel}->Destroy;
		$self->{EmptyPanel} = undef;
	}
}

sub NewTypePanel {
	my ($self) = @_;
	return ClassificationTypePanel->new($self,$self->{FileBox}->GetFile,$self->{FileBox}->{ListBox}->GetStringSelection);
}

sub GenerateChart {
	my ($self,$pie_panel,$chart_data) = @_;
	
	my $classifier = $pie_panel->{ClassifierBox}->GetStringSelection;
	if ($classifier eq "") {
		$classifier = "All";
	}
	
	my $piedata = {};
	if ($classifier eq "All") {
		$piedata = $pie_panel->{DataReader}->PieAllClassifiersData();
	}
	else {
		$piedata = $pie_panel->{DataReader}->PieClassifierData($classifier);
	}
	if ($piedata->{Total} == 0) {
		return 0;
	}
	
	my $title = $pie_panel->{TitleBox}->GetValue;
	my $label = $pie_panel->{Label};
		
	if ($title eq "") {
		if ($classifier ne "" and $classifier ne "All") {
			$title = $classifier;
		}
	}
	
	push(@{$chart_data->[0]},$piedata);
	push(@{$chart_data->[1]},$title);
	push(@{$chart_data->[2]},$label);
}

sub GenerateCharts {
	my ($self) = @_;
	
	my $chart_data = ([],[],[]);
	
	if (not defined $self->{PiePanels}) {
		return 0;
	}
	
	if (@{$self->{PiePanels}} == 0) {
		return 0;
	}
	
	for my $pie_panel(@{$self->{PiePanels}}) {
		$self->GenerateChart($pie_panel,$chart_data);
	}
	
	if (defined $chart_data->[0]) {
		PieViewer->new($chart_data->[0],$chart_data->[1],$chart_data->[2],-1,-1,$control);
	}
	else {
	}
}

package TaxonomyPiePanel;
use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use Wx::Event qw(EVT_TEXT);
use Wx::Event qw(EVT_CHECKBOX);
use Wx::Event qw(EVT_COMBOBOX);
use Wx::Event qw(EVT_LISTBOX);
use Wx::Event qw(EVT_LISTBOX_DCLICK);
use Fcntl;
use DB_File;

use base ("ClassificationPiePanel");

sub FillObjects {
	my ($self) = @_;
	$control->GetTaxonomyFiles($self->{FileBox});
}

sub GenerateChart {
	my ($self,$pie_panel,$chart_data) = @_;
	
	my $node_name = $pie_panel->{NodeBox}->GetStringSelection;
	my $rank = $pie_panel->{RankBox}->GetValue;
	
	if ($rank eq ""){
		$rank = "species";
	}
	if ($node_name eq "") {
		return 0;
	}
	
	my $input_node = $node_name;
	$input_node =~ s/^\s+//;
		
	my $piedata = $pie_panel->{DataReader}->PieDataNode($input_node,$rank);
	if ($piedata->{Total} == 0) {
		return 0;
	}
	
	my $title = $pie_panel->{TitleBox}->GetValue;
	my $label = $pie_panel->{Label};
		
	if ($title eq "") {
		if ($node_name eq "") {
			$title = $label;
			$node_name = $pie_panel->{DataReader}->{RootName};
		}
		else {
			$title = $node_name;
		}
	}
	
	push(@{$chart_data->[0]},$piedata);
	push(@{$chart_data->[1]},$title);
	push(@{$chart_data->[2]},$label);
}

sub NewTypePanel {
	my ($self) = @_;
	return TaxonomyTypePanelTitle->new($self,$self->{FileBox}->GetFile,$self->{FileBox}->{ListBox}->GetStringSelection);
}

package TreeViewPanel;
use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use Wx::Event qw(EVT_TEXT);
use Wx::Event qw(EVT_CHECKBOX);
use Wx::Event qw(EVT_COMBOBOX);
use Wx::Event qw(EVT_LISTBOX);
use Wx::Event qw(EVT_LISTBOX_DCLICK);

use base ("TaxonomyPiePanel");

sub new {
	my ($class,$parent) = @_;
	my $self = $class->SUPER::new($parent,"Available Taxonomies","Taxonomies to View");
	$self->MainDisplay("Available Taxonomies");
	return $self;
}

sub MainDisplay {
	my ($self,$label) = @_;

	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	$self->CenterDisplay($label);
	
	$self->{GeneratePanel} = Wx::Panel->new($self,-1);
	$self->{GeneratePanel}->SetBackgroundColour($turq);
	
	my $gbutton_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $gbutton_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $generate_button = Wx::Button->new($self->{GeneratePanel},-1,"Generate");
	$gbutton_sizer_v->Add($generate_button,1,wxCENTER);
	$gbutton_sizer_h->Add($gbutton_sizer_v,1,wxCENTER);
	$self->{GeneratePanel}->SetSizer($gbutton_sizer_h);
	
	$sizer->Add($self->{CenterDisplay},7,wxEXPAND);
	$sizer->Add($self->{GeneratePanel},1,wxEXPAND);
	
	$self->SetSizer($sizer);

	$self->Layout;
	
	EVT_BUTTON($self->{GeneratePanel},$generate_button,sub{$self->TaxonomyText()});
}

sub NewTypePanel {
	my ($self) = @_;
	return TaxonomyTypePanel->new($self,$self->{FileBox}->GetFile,$self->{FileBox}->{ListBox}->GetStringSelection);
}

sub TaxonomyText {
	my ($self) = @_;
}

sub PrintSpecies {
	my ($self,$tax_file,$result_name) = @_;
	my @tax_file_split = split(/$control->{PathSeparator}/,$tax_file);
	my $result_name = $control->GetParserName($tax_file_split[@tax_file_split - 2]);
	my $names = $control->GetTaxonomyNodeNames($tax_file);
	my $ranks = $control->GetTaxonomyNodeRanks($tax_file);
	my $seqids = $control->GetTaxonomyNodeIds($tax_file);
	my $values = $control->GetTaxonomyNodeValues($tax_file);
	my $data_reader = TaxonomyData->new($tax_file,$names,$ranks,$seqids,$values);
	my $dir = "/Users/virushunter1/Desktop/EpFuResults/By_Species";
	$data_reader->PrintSummaryTextSpecies($dir,$result_name);
}

package QueryTextDisplay;

use Wx qw /:everything/;
use Wx::Event qw(EVT_SIZE);
use Wx::Event qw(EVT_PAINT);
use Wx::Html;
use base 'Wx::Panel';

sub new {
	my ($class,$parent) = @_;
	my $self = $class->SUPER::new($parent,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$self->{Query} = "";
	$self->{GI} = "";
	$self->{Description} = "";
	$self->{HLength} = "";
	$self->{QLength} = "";
	$self->{QStart} = "";
	$self->{QEnd} = "";
	$self->{HStart} = "";
	$self->{HEnd} = "";
	$self->{Bitmap} = Wx::Bitmap->new(1,1,-1);
	$self->SetBackgroundColour(wxWHITE);
	EVT_PAINT($self,\&OnPaint);
	EVT_SIZE($self,\&OnSize);
	return $self;
}

sub OnPaint {
	my ($self,$event) = @_;
	if ($self->{Query} eq "") {
		return 0;
	}
	my $dc = Wx::PaintDC->new($self);
	$dc->DrawBitmap($self->{Bitmap},0,0,1);
}

sub OnSize {
	my ($self,$event) = @_;
	if ($self->{Query} eq "") {
		return 0;
	}
	my $size = $self->GetClientSize();
	my $width = $size->GetWidth();
	my $height = $size->GetHeight();
	$self->{Bitmap} = Wx::Bitmap->new($width,$height,-1);
	my $memory = Wx::MemoryDC->new();
	$memory->SelectObject($self->{Bitmap});
	$self->DisplayTextInfo($memory);
}

sub SetQuery {
	my ($self,$query,$gi,$descr,$hlength,$qlength,$qstart,$qend,$hstart,$hend,$bit) = @_;
	$self->{Query} = "$query";
	$self->{GI} = "$gi";
	$self->{Description} = "$descr";
	$self->{Bit} = $bit;
	$self->{HLength} = "$hlength";
	$self->{QLength} = "$qlength";
	$self->{QStart} = "$qstart";
	$self->{QEnd} = "$qend";
	$self->{HStart} = "$hstart";
	$self->{HEnd} = "$hend";
	$self->OnSize(0);
}

sub DisplayTextInfo {
	my ($self,$dc) = @_;
	my $size = $self->GetClientSize();
	my $width = $size->GetWidth();
	my $height = $size->GetHeight();
	my $window = Wx::HtmlWindow->new($self,-1);
	$window->SetSize($width,$height);
	
	$window->SetPage("
	<html>
  	<head>
    <title></title>
  	</head>
  	<body>
  	<h1>$self->{Query}</h1>
  	<p>GI: $self->{GI}</p>
  	<p>Description: $self->{Description}</p>
  	<br>
  	<br>
  	
    </body>
    </head>
    </html>
    ");

	$self->Refresh;
	$self->Layout;
}

package TableDisplay;
use Wx qw /:everything/;
use Wx::Event qw(EVT_LIST_ITEM_SELECTED);
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED);
use Wx::Event qw(EVT_LIST_COL_CLICK);
use Wx::Event qw(EVT_SIZE);
use base 'Wx::Panel';

sub new {
	my ($class,$parent,$table_names,$bit,$evalue) = @_;
	my $self = $class->SUPER::new($parent,-1);
	$self->{ResultHitListCtrl} = undef;
	$self->{ResultQueryListCtrl} = undef;
	$self->{QueryColumnHash} = ();
	bless ($self,$class);
	$self->MainDisplay($table_names,$bit,$evalue);
	return $self;
}

sub MainDisplay {
	my ($self,$table_names,$bit,$evalue) = @_;
	my $sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $rightsizer = Wx::BoxSizer->new(wxVERTICAL);
	
	$self->{ResultHitListCtrl} = Wx::ListCtrl->new($self,-1,wxDefaultPosition,wxDefaultSize,wxLC_REPORT);
	$self->{ResultHitListCtrl}->InsertColumn(0,"Hit Name");
	$self->{ResultHitListCtrl}->InsertColumn(1,"Count");
	
	$self->{ResultQueryListCtrl} = Wx::ListCtrl->new($self,-1,wxDefaultPosition,wxDefaultSize,wxLC_REPORT);
	$self->{ResultQueryListCtrl}->InsertColumn(0,"Query");
	$self->{ResultQueryListCtrl}->InsertColumn(1,"Rank");
	$self->{ResultQueryListCtrl}->InsertColumn(2,"E-Value");
	$self->{ResultQueryListCtrl}->InsertColumn(3,"Bit Score");
	$self->{ResultQueryListCtrl}->InsertColumn(4,"Percent Id");
	
	my $info_sizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{InfoPanel} = QueryTextDisplay->new($self);
	$info_sizer->Add($self->{InfoPanel},1,wxEXPAND);
	
	my $qlist_sizer = Wx::BoxSizer->new(wxVERTICAL);
	$qlist_sizer->Add($self->{ResultQueryListCtrl},1,wxEXPAND);
	
	$rightsizer->Add($qlist_sizer,1,wxEXPAND);
	$rightsizer->Add($info_sizer,1,wxEXPAND);
	
	my $hlist_sizer = Wx::BoxSizer->new(wxVERTICAL);
	$hlist_sizer->Add($self->{ResultHitListCtrl},1,wxEXPAND);
	
	$sizer->Add($hlist_sizer,1,wxEXPAND);
	$sizer->Add($rightsizer,2,wxEXPAND);
	
	$self->CompareTables($table_names,$bit,$evalue);
	$self->SetSizer($sizer);
	EVT_SIZE($self,\&OnSize);
}

# For resizing the columns of the list controls
sub OnSize {
	my ($self,$event) = @_;

	my $size = $self->{ResultHitListCtrl}->GetClientSize();
	my $width = $size->GetWidth();
	$self->{ResultHitListCtrl}->SetColumnWidth(0,$width*2/3);
	$self->{ResultHitListCtrl}->SetColumnWidth(1,$width/2);
	
	my $size = $self->{ResultQueryListCtrl}->GetClientSize();
	my $width = $size->GetWidth();
	$self->{ResultQueryListCtrl}->SetColumnWidth(0,$width*1/3);
	$self->{ResultQueryListCtrl}->SetColumnWidth(1,$width/6);
	$self->{ResultQueryListCtrl}->SetColumnWidth(2,$width/6);
	$self->{ResultQueryListCtrl}->SetColumnWidth(3,$width/6);
	$self->{ResultQueryListCtrl}->SetColumnWidth(4,$width/5);
	
	$self->{InfoPanel}->Layout;
	$self->Refresh;
	$self->Layout;
}

sub CompareTables {
	my ($self,$table_names,$bit,$evalue) = @_;
	
	# This could probably be done much better
	
	$control->{Connection}->do("DROP TABLE IF EXISTS t_1");
	$control->{Connection}->do("CREATE TEMP TABLE t_1 (query TEXT,gi INTEGER,rank INTEGER,percent REAL,bit REAL,
	evalue REAL,starth INTEGER,endh INTEGER,startq INTEGER,endq INTEGER,ignore_gi INTEGER,description TEXT,hitname TEXT,hlength INTEGER,ignore_query TEXT,qlength INTEGER,sequence TEXT)");

	for my $table(@$table_names) {
		my $all_hits = $table . "_AllHits";
		my $hit_info = $table . "_HitInfo";
		my $query_info = $table . "_QueryInfo";
		my $temp = $control->{Connection}->do("INSERT INTO t_1 SELECT * FROM $all_hits INNER JOIN $hit_info ON $hit_info.gi=$all_hits.gi 
		INNER JOIN $query_info ON $all_hits.query=$query_info.query
		WHERE $all_hits.bit > $bit AND $all_hits.evalue < $evalue");
	}
	
	$control->{Connection}->do("DROP TABLE IF EXISTS t");
	$control->{Connection}->do("CREATE TEMP TABLE t (query TEXT,gi INTEGER,rank INTEGER,percent REAL,bit REAL,
	evalue REAL,starth INTEGER,endh INTEGER,startq INTEGER,endq INTEGER,
	description TEXT,hitname TEXT,hlength INTEGER,qlength INTEGER,sequence TEXT)");

	$control->{Connection}->do("INSERT INTO t SELECT t_1.query,t_1.gi,t_1.rank,t_1.percent,t_1.bit,
	t_1.evalue,t_1.starth,t_1.endh,t_1.startq,t_1.endq,
	t_1.description,t_1.hitname,t_1.hlength,t_1.qlength,t_1.sequence FROM t_1 
	INNER JOIN(SELECT t_1.query,MAX(t_1.bit) AS MaxBit FROM t_1 GROUP BY query) grouped 
	ON t_1.query=grouped.query AND t_1.bit = grouped.MaxBit");

	$control->{Connection}->do("DROP TABLE t_1");
	$self->DisplayHits();
}

my %hmap = ();
my $hcol = 0;
my %hcolstate = (0=>-1,1=>-1);

sub DisplayHits {
	my ($self) = @_;

	$self->{ResultHitListCtrl}->DeleteAllItems;
	
	my $row = $control->{Connection}->selectall_arrayref("SELECT hitname,COUNT(query) FROM t GROUP BY hitname");

	my $i = 0;
	for my $item(@$row) {
		my $hitname = $item->[0];
		next if ($hitname eq "");
		my $count = $item->[1];
		my $item = $self->{ResultHitListCtrl}->InsertStringItem($i,"");
		$self->{ResultHitListCtrl}->SetItemData($item,$i);
		$self->{ResultHitListCtrl}->SetItem($i,0,$hitname);
		$hmap{0}{$i} = $hitname;
		$self->{ResultHitListCtrl}->SetItem($i,1,$count);
		$hmap{1}{$i} = $count;
		$i++;
	}
	
	EVT_LIST_ITEM_ACTIVATED($self,$self->{ResultHitListCtrl},\&Save);
	EVT_LIST_ITEM_SELECTED($self,$self->{ResultHitListCtrl},\&DisplayQueries);
	EVT_LIST_COL_CLICK($self,$self->{ResultHitListCtrl},\&OnSortHit);
} 

my %qmap = ();
my $qcol = 0;
my %qcolstate = (0=>-1,1=>-1,2=>-1,3=>-1,4=>-1);

sub DisplayQueries {
	my ($self,$event) = @_;
	$self->{ResultQueryListCtrl}->DeleteAllItems;
	my $hitname = $event->GetText;
	my $hit_gis = $control->{Connection}->selectall_arrayref("SELECT * FROM t WHERE hitname=?",undef,$hitname);
	
	my $count = 0;
	for my $row(@$hit_gis) {
		my $item = $self->{ResultQueryListCtrl}->InsertStringItem($count,"");
		$self->{ResultQueryListCtrl}->SetItemData($item,$count);
		$self->{ResultQueryListCtrl}->SetItem($count,0,$row->[0]); #query
		$qmap{0}{$count} = $row->[0];
		$self->{ResultQueryListCtrl}->SetItem($count,1,$row->[2]); #rank
		$qmap{1}{$count} = $row->[2];
		$self->{ResultQueryListCtrl}->SetItem($count,2,$row->[5]); #e-value
		$qmap{2}{$count} = $row->[5];
		$self->{ResultQueryListCtrl}->SetItem($count,3,$row->[4]); #bit score
		$qmap{3}{$count} = $row->[4];
		$self->{ResultQueryListCtrl}->SetItem($count,4,sprintf("%.2f",$row->[3])); #percent identity
		$qmap{4}{$count} = $row->[3];
		$count += 1;
	}

	EVT_LIST_COL_CLICK($self,$self->{ResultQueryListCtrl},\&OnSortQuery);
	EVT_LIST_ITEM_SELECTED($self,$self->{ResultQueryListCtrl},\&BindInfoPaint);
}

sub BindInfoPaint {
	my ($self,$event) = @_;
	my $query = $event->GetText;
	my ($query,$gi,$rank,$percid,$bit,$evalue,$starth,$endh,$startq,$endq,$ignore_gi,$descr,$hitname,$hlength,$ignore_query,$qlength,$sequence) = 
	@{ $control->{Connection}->selectrow_arrayref("SELECT * FROM t WHERE query=?",undef,$query)};
	$self->{InfoPanel}->SetQuery($query,$gi,$descr,$hlength,$qlength,$startq,$endq,$starth,$endh,$bit);
}

sub QCompare {
	my ($item1,$item2) = @_;
	my $data1 = $qmap{$qcol}{$item1};
	my $data2 = $qmap{$qcol}{$item2};
	
	if ($data1 > $data2) {
		return $qcolstate{$qcol};
	}
	elsif ($data1 < $data2) {
		return -$qcolstate{$qcol};
	}
	else {
		return 0;
	}
}

sub HCompare {
	my ($item1,$item2) = @_;
	my $data1 = $hmap{$hcol}{$item1};
	my $data2 = $hmap{$hcol}{$item2};
	
	if ($data1 > $data2) {
		return $hcolstate{$hcol};
	}
	elsif ($data1 < $data2) {
		return -$hcolstate{$hcol};
	}
	else {
		return 0;
	}
}

sub OnSortHit {
	my($self,$event) = @_;
	$hcol = $event->GetColumn;
	$hcolstate{$hcol} *= -1;
	$self->{ResultHitListCtrl}->SortItems(\&HCompare);
}

sub OnSortQuery {
	my($self,$event) = @_;
	$qcol = $event->GetColumn;
	$qcolstate{$qcol} *= -1;
	$self->{ResultQueryListCtrl}->SortItems(\&QCompare);
}

sub Save {
	my ($self,$event) = @_;
	my $hitname = $event->GetText;
	my $dialog = Wx::FileDialog->new($self,"Save Queries to FASTA","","",".",wxFD_SAVE);
	if ($dialog->ShowModal==wxID_OK) {
		my $queries = $control->{Connection}->selectall_arrayref("SELECT query FROM t WHERE hitname=?",undef,$hitname);
		open(FASTA, '>>' . $dialog->GetPath);
		for my $query(@$queries) {
			my $sequence = $control->{Connection}->selectrow_arrayref("SELECT sequence FROM t WHERE query=?",undef,$query->[0]);
			print FASTA ">" . $query->[0] . "\n";
		  	print FASTA $sequence->[0] . "\n";
		  	print FASTA "\n";
		}
	  	close FASTA;
	}
	$dialog->Destroy;
}

package TableMenu;

use Wx qw /:everything/;
use Wx::Event qw(EVT_LISTBOX);
use Wx::Event qw(EVT_LISTBOX_DCLICK);
use Wx::Event qw(EVT_BUTTON);
use base 'Wx::Panel';

sub new {
	my ($class,$parent) = @_;
	
	my $self = $class->SUPER::new($parent,-1);
	$self->{Sizer} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{MainPanel} = Wx::Panel->new($self,-1);
	$self->{TableDisplay} = undef;
	$self->{ResultListBox} = undef;
	bless ($self,$class);
	$self->UpdateItems();
	$self->SetSizer($self->{Sizer});
	$self->Layout;
	return $self;
}

sub UpdateItems {
	my ($self) = @_;
	$self->{Sizer}->Clear;
	if (defined $self->{TableDisplay}) {
		$self->{TableDisplay}->Destroy;
	}
	$self->Refresh;
	$self->MainDisplay();
	$self->{MainPanel}->Show;
	$self->Layout;
}

sub MainDisplay {
	my ($self) = @_;
	
	$self->{MainPanel}->DestroyChildren;
	$self->{MainPanel}->SetBackgroundColour($turq);
	
	my $leftpanelsizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $leftsizer = Wx::BoxSizer->new(wxHORIZONTAL);
	
	my $queuetext = Wx::StaticBox->new($self->{MainPanel},-1,"Choose Result");
	my $qtextsizer = Wx::StaticBoxSizer->new($queuetext,wxVERTICAL);
	$self->{ResultListBox} = FileBox->new($self->{MainPanel});
	$qtextsizer->Add($self->{ResultListBox}->{ListBox},1,wxEXPAND);
	$control->AddResultsBox($self->{ResultListBox});
	
	my $add_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $add_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $add_button = Wx::Button->new($self->{MainPanel},-1,"Add");
	$add_sizer_v->Add($add_button,1,wxCENTER);
	$add_sizer_h->Add($add_sizer_v,1,wxCENTER);
	
	my $comparetext = Wx::StaticBox->new($self->{MainPanel},-1,"Result(s) to View");
	my $comparesizer = Wx::StaticBoxSizer->new($comparetext,wxVERTICAL);
	$self->{CompareListBox} = FileBox->new($self->{MainPanel});
	$comparesizer->Add($self->{CompareListBox}->{ListBox},1,wxEXPAND);
	
	$leftsizer->Add($qtextsizer,4,wxEXPAND);
	$leftsizer->Add($add_sizer_h,1,wxCENTER);
	$leftsizer->Add($comparesizer,4,wxEXPAND);
	
	my $paramsizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $choice_text = Wx::StaticBox->new($self->{MainPanel},-1,"Filter Parameters: ");
	my $choice_wrap = Wx::StaticBoxSizer->new($choice_text, wxVERTICAL);
	my $choice_sizer = Wx::FlexGridSizer->new(2,2,20,20);
	
	my $bit_label = Wx::StaticText->new($self->{MainPanel},-1,"Bit Score:");
	$choice_sizer->Add($bit_label,1,wxCENTER);
	$self->{BitTextBox} = Wx::TextCtrl->new($self->{MainPanel},-1,"");
	$self->{BitTextBox}->SetValue("40.0");
	$choice_sizer->Add($self->{BitTextBox},1,wxCENTER);
	
	my $e_label = Wx::StaticText->new($self->{MainPanel},-1,"E-value:");
	$choice_sizer->Add($e_label,1,wxCENTER);
	$self->{EValueTextBox} = Wx::TextCtrl->new($self->{MainPanel},-1,"");
	$self->{EValueTextBox}->SetValue("0.001");
	$choice_sizer->Add($self->{EValueTextBox},1,wxCENTER);
	$choice_wrap->Add($choice_sizer,3,wxCENTER|wxEXPAND);
	
	$paramsizer->Add($choice_wrap,1,wxCENTER);
	
	my $view_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $view_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $view_button = Wx::Button->new($self->{MainPanel},-1,"View");
	$view_sizer_v->Add($view_button,1,wxCENTER);
	$view_sizer_h->Add($view_sizer_v,1,wxCENTER);
	
	$paramsizer->Add($view_sizer_h,1,wxCENTER);
	
	$leftpanelsizer->Add($leftsizer,1,wxEXPAND);
	$leftpanelsizer->Add($paramsizer,1,wxEXPAND);
	
	$self->{MainPanel}->SetSizer($leftpanelsizer);
	$self->{MainPanel}->Layout;
	$self->{Sizer}->Add($self->{MainPanel},1,wxEXPAND);
	EVT_BUTTON($self,$view_button,sub{$self->DisplayTable()});
	EVT_BUTTON($self,$add_button,sub{$self->{CompareListBox}->AddFile($self->{ResultListBox}->GetFile,$self->{ResultListBox}->{ListBox}->GetStringSelection)});
	EVT_LISTBOX_DCLICK($self,$self->{CompareListBox}->{ListBox},sub{$self->DeleteCompareResult()});
}

sub DisplayTable {
	my ($self) = @_;
	
	my $table_names = $self->{CompareListBox}->GetAllFiles;
	my $bit = scalar($self->{BitTextBox}->GetValue);
	my $evalue = scalar($self->{EValueTextBox}->GetValue);
	
	$self->{MainPanel}->Hide;
	$self->{Sizer}->Clear;
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{TableDisplay} = TableDisplay->new($self,$table_names,$bit,$evalue);
	$self->{Sizer}->Add($self->{TableDisplay},1,wxEXPAND);
	$self->Refresh;
	$self->Layout;
	$self->{TableDisplay}->OnSize(0);
	$self->Show;
}

sub DeleteCompareResult {
	my ($self) = @_;
	my $delete_dialog = OkDialog->new($self,"Delete","Remove Result?");
	if ($delete_dialog->ShowModal == wxID_OK) {
		$self->{CompareListBox}->DeleteFile;
	}
	$delete_dialog->Destroy;
}

package ParserPanel;

use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use Wx::Event qw(EVT_MENU);
use Wx::Event qw(EVT_TREE_ITEM_ACTIVATED);
use Wx::Event qw(EVT_TEXT);
use Wx::Event qw(EVT_COMBOBOX);
use Wx::Event qw(EVT_CHECKBOX);
use Wx::Event qw(EVT_LISTBOX);
use Wx::Event qw(EVT_LISTBOX_DCLICK);

use base 'Wx::Panel';

sub new {
	my ($class,$parent) = @_;
	
	my $self = $class->SUPER::new($parent,-1);
	$self->SetBackgroundColour($turq);
	
	$self->{ParserMenu} = undef;

	$self->{ParserNameTextCtrl} = undef;
	$self->{BlastFileTextBox} = undef;
	$self->{FastaFileTextBox} = undef;
	$self->{DirectoryTextBox} = undef;
	$self->{TableCheck} = undef;
	$self->{DirectoryCheckBox} = undef;
	$self->{ClassBox} = undef;
	$self->{FlagBox} = undef;
	$self->{BitTextBox} = undef;
	$self->{EValueTextBox} = undef;
	$self->{HSPRankTextBox} = undef;
	
	$self->{ParserName} = "";
	$self->{BlastFilePath} = "";
	$self->{FastaFilePath} = "";
	$self->{OutputDirectoryPath} = "";
	$self->{ClassLabelToPath} = ();
	$self->{FlagLabelToPath} = ();
	$self->{RootList} = undef;
	$self->{RankList} = undef;
	$self->{SourceCombo} = undef;
	
	bless ($self,$class);
	$self->ParserPanel();
	$self->Layout;
	return $self;
}

sub DirectoryChecked {
	my ($self,$title) = @_;
	my $checkbox_value = $self->{DirectoryCheckBox}->GetValue;
	if ($checkbox_value == 0) {
		$self->{DirectoryTextBox}->SetValue("");
	}
	else {
		my $dialog = 0;
		my $file_label = "";
		$dialog = Wx::DirDialog->new($self,$title);
		if ($dialog->ShowModal==wxID_OK) {
			$file_label = $dialog->GetPath;
		}
		$self->{OutputDirectoryPath} = $dialog->GetPath;
		$self->{DirectoryTextBox}->SetValue($file_label);
	}
}

sub OpenDialogSingle {
	my ($self,$text_entry,$title) = @_;
	my $dialog = 0;
	my $file_label = "";
	$dialog = Wx::FileDialog->new($self,$title);
	if ($dialog->ShowModal==wxID_OK) {
		my @split = split($control->{PathSeparator},$dialog->GetPath);
		$file_label = $split[@split-1];
	}
	$text_entry->SetValue($file_label);
	return $dialog->GetPath;
}

sub OpenDialogMultiple {
	my ($self,$title,$filebox) = @_;
	my $dialog = 0;
	my $file_label = "";
	$dialog = Wx::FileDialog->new($self,$title);
	if ($dialog->ShowModal==wxID_OK) {
		my @split = split($control->{PathSeparator},$dialog->GetPath);
		for (my $i=@split - 1; $i>0; $i--) {
			if ($i==@split - 2) {
				$file_label = $split[$i] . $control->{PathSeparator} . $file_label;
				last;
			}
			$file_label = $split[$i] . $file_label;
		}
	}
	$filebox->AddFile($dialog->GetPath,$file_label);
}

sub CheckProcess {
	my ($self) = @_;
	if ($self->{ParserNameTextCtrl}->GetValue eq "") {
		return 0;
	}
	elsif ($self->{BlastFilePath} eq "") {
		return -1;
	}
	elsif ($self->{FastaFilePath} eq "") {
		return -2;
	}
	elsif ($self->{OutputDirectoryPath} eq "" and $self->{TableCheck}->GetValue==0) {
		return -3;
	}
	else {
		return 1;
	}
}

sub BlastButtonEvent {
	my ($self) = @_;
	$self->{BlastFilePath} = $self->OpenDialogSingle($self->{BlastFileTextBox},'Choose Search File');
}

sub ParserPanel {
	my ($self) = @_;
	
	$self->NewParserMenu();
	
	my $menusizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $button_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $button_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{QueueButton} = Wx::Button->new($self,-1,'Queue');
	$button_sizer_h->Add($self->{QueueButton},1,wxCENTER);
	$button_sizer_v->Add($button_sizer_h,1,wxCENTER);
	
	$menusizer->Add($self->{OptionsNotebook},8,wxEXPAND);
	$menusizer->Add($button_sizer_v,1,wxEXPAND);
	$self->SetSizer($menusizer);
	$self->Layout;
}


sub NewParserMenu {

	my ($self) = @_;
	
	$self->{ParserMenu} = Wx::Panel->new($self,-1);
	$self->{ParserMenu}->SetBackgroundColour($turq);
	
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	$self->{OptionsNotebook} = Wx::Notebook->new($self,-1); #self->{ParserMenu}
	$self->{OptionsNotebook}->SetBackgroundColour($turq);
	
	my $filespanel = $self->InputFilesMenu();
	my $classificationpanel = $self->ClassificationMenu();
	my $taxonomypanel = $self->TaxonomyMenu();
	my $parameterspanel = $self->ParameterMenu();
	my $add_panel = $self->OutputMenu();
	
	$self->{OptionsNotebook}->AddPage($filespanel,"Input Files");
	$self->{OptionsNotebook}->AddPage($classificationpanel,"Classifications");
	$self->{OptionsNotebook}->AddPage($taxonomypanel,"NCBI Taxonomy");
	$self->{OptionsNotebook}->AddPage($parameterspanel,"Parameters");
	$self->{OptionsNotebook}->AddPage($add_panel,"Output");
	
	$self->{OptionsNotebook}->Layout;
	$sizer->Add($self->{OptionsNotebook},1,wxEXPAND);
	$self->{ParserMenu}->SetSizer($sizer);
	$self->{ParserMenu}->Layout;
	
}

sub InputFilesMenu {
	my ($self) = @_;
	
	my $filespanel = Wx::Panel->new($self->{OptionsNotebook},-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$filespanel->SetBackgroundColour($blue);
	my $filessizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $parser_label = Wx::StaticBox->new($filespanel,-1,"Parser Name");
	my $parser_label_sizer = Wx::StaticBoxSizer->new($parser_label,wxHORIZONTAL);
	my $parser_text = Wx::StaticText->new($filespanel,-1,"Choose a parser name: ");
	$self->{ParserNameTextCtrl} = Wx::TextCtrl->new($filespanel,-1,"New Parser");
	$parser_label_sizer->Add($parser_text,1,wxCENTER);
	$parser_label_sizer->Add($self->{ParserNameTextCtrl},1,wxCENTER);
	
	my $blastsizer = Wx::FlexGridSizer->new(1,2,15,15);
	$blastsizer->AddGrowableCol(0,0);
	my $blast_label = Wx::StaticBox->new($filespanel,-1,"BLAST File:");
	my $blast_label_sizer = Wx::StaticBoxSizer->new($blast_label,wxHORIZONTAL);
	$self->{BlastFileTextBox} = Wx::TextCtrl->new($filespanel,-1,"");
	$self->{BlastFileTextBox}->SetEditable(0);
	my $blast_button = Wx::Button->new($filespanel,-1,'Browse');
	$blastsizer->Add($self->{BlastFileTextBox},5,wxCENTER|wxEXPAND);
	$blastsizer->Add($blast_button,1,wxCENTER);
	$blast_label_sizer->Add($blastsizer,1,wxEXPAND);
	EVT_BUTTON($filespanel,$blast_button,sub{$self->BlastButtonEvent()});
	
	my $fastasizer = Wx::FlexGridSizer->new(1,2,15,15);
	$fastasizer->AddGrowableCol(0,1);
	my $fasta_label = Wx::StaticBox->new($filespanel,-1,"FASTA File:");
	my $fasta_label_sizer = Wx::StaticBoxSizer->new($fasta_label,wxHORIZONTAL);
	$self->{FastaFileTextBox} = Wx::TextCtrl->new($filespanel,-1,"");
	$self->{FastaFileTextBox}->SetEditable(0);
	my $fasta_button = Wx::Button->new($filespanel,-1,'Browse');
	$fastasizer->Add($self->{FastaFileTextBox},1,wxCENTER|wxEXPAND);
	$fastasizer->Add($fasta_button,1,wxCENTER);
	$fasta_label_sizer->Add($fastasizer,1,wxEXPAND);
	EVT_BUTTON($filespanel,$fasta_button,sub{$self->{FastaFilePath} = $self->OpenDialogSingle($self->{FastaFileTextBox},'Choose FASTA File')});
	
	my $center_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $center_items = Wx::BoxSizer->new(wxVERTICAL);
	$center_items->Add($parser_label_sizer,1,wxCENTER|wxEXPAND);
	$center_items->Add($blast_label_sizer,1,wxCENTER|wxBOTTOM|wxEXPAND);
	$center_items->Add($fasta_label_sizer,1,wxCENTER|wxEXPAND);
	$center_sizer->Add($center_items,4,wxCENTER);
	$filessizer->Add($center_sizer,3,wxCENTER|wxEXPAND,0);
	$filespanel->SetSizer($filessizer);

	return $filespanel;
}

sub ClassificationMenu {
	my ($self) = @_;
	
	my $classificationpanel = Wx::Panel->new($self->{OptionsNotebook},-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$classificationpanel->SetBackgroundColour($blue);
	my $classificationsizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $itemssizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $class_flag_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	
	my $flag_label = Wx::StaticBox->new($classificationpanel,-1,"Flag Files");
	my $flag_label_sizer = Wx::StaticBoxSizer->new($flag_label,wxVERTICAL);
	my $flag_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $flag_button_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $flag_button = Wx::Button->new($classificationpanel,-1,'Browse');
	$flag_button_sizer->Add($flag_button,1,wxCENTER);
	my $flag_list_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{FlagBox} = FileBox->new($classificationpanel);
	$flag_list_sizer->Add($self->{FlagBox}->{ListBox},1,wxEXPAND);
	$flag_sizer->Add($flag_button_sizer,1,wxBOTTOM|wxCENTER,5);
	$flag_sizer->Add($flag_list_sizer,3,wxCENTER|wxEXPAND);
	EVT_BUTTON($classificationpanel,$flag_button,sub{$self->OpenDialogMultiple('Find Flag File',$self->{FlagBox})});
	$flag_label_sizer->Add($flag_sizer,1,wxEXPAND);
	
	my $class_label = Wx::StaticBox->new($classificationpanel,-1,"Classification Files");
	my $class_label_sizer = Wx::StaticBoxSizer->new($class_label,wxVERTICAL);
	my $class_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $class_button_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $class_button = Wx::Button->new($classificationpanel,-1,'Browse');
	$class_button_sizer->Add($class_button,1,wxCENTER);
	my $class_list_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{ClassBox} = FileBox->new($classificationpanel);
	$class_list_sizer->Add($self->{ClassBox}->{ListBox},1,wxEXPAND);
	$class_sizer->Add($class_button_sizer,1,wxBOTTOM|wxCENTER,5);
	$class_sizer->Add($class_list_sizer,3,wxCENTER|wxEXPAND);
	EVT_BUTTON($classificationpanel,$class_button,sub{$self->OpenDialogMultiple('Find Classification File',$self->{ClassBox})});
	$class_label_sizer->Add($class_sizer,1,wxEXPAND);
	
	$class_flag_sizer->Add($class_label_sizer,1,wxEXPAND);
	$class_flag_sizer->Add($flag_label_sizer,1,wxEXPAND);
	
	$itemssizer->Add($class_flag_sizer,2,wxEXPAND);
	
	$classificationsizer->Add($itemssizer,1,wxEXPAND);
	
	$classificationpanel->SetSizer($classificationsizer);
	
	EVT_LISTBOX_DCLICK($classificationpanel,$self->{FlagBox}->{ListBox},sub{$self->DeleteClassItem($self->{FlagBox})});
	EVT_LISTBOX_DCLICK($classificationpanel,$self->{ClassBox}->{ListBox},sub{$self->DeleteClassItem($self->{ClassBox})});
	return $classificationpanel;
}

sub DeleteClassItem {
	my ($self,$box) = @_;
	my $parent = $self->GetParent();
	while (defined $parent->GetParent) {
		$parent = $parent->GetParent;
	}
	my $delete_dialog = OkDialog->new($parent,"Delete","Delete Flag File?");
	if ($delete_dialog->ShowModal == wxID_OK) {
		$box->DeleteFile();
	}
	$delete_dialog->Destroy;
}

sub TaxonomyMenu {
	my ($self) = @_;
	
	my $tax_panel = Wx::Panel->new($self->{OptionsNotebook},-1);
	$tax_panel->SetBackgroundColour($blue);
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $source_label = Wx::StaticBox->new($tax_panel,-1,"Source");
	my $source_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $source_label_sizer = Wx::StaticBoxSizer->new($source_label,wxHORIZONTAL);
	$self->{SourceCombo} = Wx::ComboBox->new($tax_panel,-1,"",wxDefaultPosition,wxDefaultSize,["Connection","Local Files"]);
	$self->{SourceCombo}->SetValue("");
	$source_label_sizer->Add($self->{SourceCombo},1,wxCENTER);
	$source_sizer->Add($source_label_sizer,3,wxCENTER);
	
	my $root_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $root_label = Wx::StaticBox->new($tax_panel,-1,"Roots (example: \"Viruses\"): ");
	my $root_label_sizer = Wx::StaticBoxSizer->new($root_label,wxHORIZONTAL);
	my $root_text = Wx::TextCtrl->new($tax_panel,-1,"");
	my $root_button_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $root_button = Wx::Button->new($tax_panel,-1,'Add');
	$root_button_sizer->Add($root_button,1,wxCENTER);
	$self->{RootList} = Wx::ListBox->new($tax_panel,-1);
	
	$root_label_sizer->Add($root_text,1,wxEXPAND);
	$root_label_sizer->Add($root_button_sizer,1,wxCENTER);
	$root_label_sizer->Add($self->{RootList},1,wxEXPAND);
	$root_sizer->Add($root_label_sizer,1,wxCENTER);
	
	EVT_BUTTON($tax_panel,$root_button,sub{$self->{RootList}->Insert($root_text->GetValue,0); $root_text->Clear;});

	my $clear_sizer_outer = Wx::BoxSizer->new(wxVERTICAL);
	my $clear_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $clear_button = Wx::Button->new($tax_panel,-1,'Clear');
	$clear_sizer->Add($clear_button,1,wxCENTER);
	$clear_sizer_outer->Add($clear_sizer,1,wxCENTER);
	
	EVT_BUTTON($tax_panel,$clear_button,sub{$self->{RootList}->Clear;$self->{SourceCombo}->SetValue("");});

	$sizer->Add($source_sizer,1,wxEXPAND);
	$sizer->Add($root_sizer,3,wxEXPAND);
	$sizer->Add($clear_sizer_outer,1,wxEXPAND);
	$tax_panel->SetSizer($sizer);

	return $tax_panel;
}

sub ParameterMenu {
	my ($self) = @_;
	
	my $panel = Wx::Panel->new($self->{OptionsNotebook},-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$panel->SetBackgroundColour($blue);
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $choice_wrap = Wx::BoxSizer->new(wxVERTICAL);
	$choice_wrap->Add(Wx::BoxSizer->new(wxVERTICAL),1,wxEXPAND);
	my $choice_sizer = Wx::FlexGridSizer->new(2,2,20,20);
	
	my $bit_label = Wx::StaticText->new($panel,-1,"Bit Score:");
	$choice_sizer->Add($bit_label,1,wxCENTER);
	$self->{BitTextBox} = Wx::TextCtrl->new($panel,-1,'40.0');
	$choice_sizer->Add($self->{BitTextBox},1,wxCENTER);
	
	my $e_label = Wx::StaticText->new($panel,-1,"E-value:");
	$choice_sizer->Add($e_label,1,wxCENTER);
	$self->{EValueTextBox} = Wx::TextCtrl->new($panel,-1,'0.001');
	$choice_sizer->Add($self->{EValueTextBox},1,wxCENTER);
	
	$choice_wrap->Add($choice_sizer,3,wxCENTER);
	$choice_wrap->Add(Wx::BoxSizer->new(wxVERTICAL),1,wxEXPAND);
	
	$sizer->Add($choice_wrap,1,wxEXPAND|wxCENTER);
	$panel->SetSizer($sizer);
	
	return $panel;
}

sub OutputMenu {
	my ($self) = @_;
	
	my $add_panel = Wx::Panel->new($self->{OptionsNotebook},-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$add_panel->SetBackgroundColour($blue);
	my $add_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $add_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	
	my $text_label = Wx::StaticBox->new($add_panel,-1,"Text Files");
	my $text_label_sizer = Wx::StaticBoxSizer->new($text_label,wxHORIZONTAL);
	my $directory_title = Wx::StaticText->new($add_panel,-1,"Output Directory:");
	$self->{DirectoryTextBox} = Wx::TextCtrl->new($add_panel,-1,"");
	$self->{DirectoryTextBox}->SetEditable(0);
	$self->{DirectoryCheckBox} = Wx::CheckBox->new($add_panel,-1,"");
	my $text_sizer = Wx::FlexGridSizer->new(1,3,20,20);
	$text_sizer->AddGrowableCol(2,1);
	$text_sizer->Add($self->{DirectoryCheckBox},1,wxCENTER);
	$text_sizer->Add($directory_title,1,wxCENTER);
	$text_sizer->Add($self->{DirectoryTextBox},1,wxCENTER|wxEXPAND);
	$text_label_sizer->Add($text_sizer,1,wxEXPAND);
	
	my $table_label = Wx::StaticBox->new($add_panel,-1,"Add to Database?");
	my $table_label_sizer = Wx::StaticBoxSizer->new($table_label,wxHORIZONTAL);
	my $check_sizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{TableCheck} = Wx::CheckBox->new($add_panel,-1,"Yes");
	$check_sizer->Add($self->{TableCheck},1,wxCENTER);
	$table_label_sizer->Add($check_sizer,1,wxEXPAND);
	
	EVT_CHECKBOX($add_panel,$self->{DirectoryCheckBox},sub{$self->DirectoryChecked("Choose Directory")});
	
	$add_sizer_v->Add($text_label_sizer,1,wxCENTER|wxEXPAND|wxLEFT|wxRIGHT,50);
	$add_sizer_v->Add($table_label_sizer,1,wxCENTER|wxEXPAND|wxLEFT|wxRIGHT,50);
	$add_sizer_h->Add($add_sizer_v,1,wxCENTER);
	
	$add_panel->SetSizer($add_sizer_h);
	
	return $add_panel;
}

sub CopyData {
	my ($self,$parser_panel) = @_;
	$self->{ParserNameTextCtrl}->SetValue($parser_panel->{ParserNameTextCtrl}->GetValue());
	$self->{BlastFileTextBox}->SetValue($parser_panel->{BlastFileTextBox}->GetValue());
	$self->{FastaFileTextBox}->SetValue($parser_panel->{FastaFileTextBox}->GetValue());
	$self->{DirectoryTextBox}->SetValue($parser_panel->{DirectoryTextBox}->GetValue());
	$self->{TableCheck}->SetValue($parser_panel->{TableCheck}->GetValue());
	my $class_files = $parser_panel->{ClassBox}->GetAllFiles;
	my $flag_files = $parser_panel->{FlagBox}->GetAllFiles;
	if (defined $class_files) {
		for (my $i = 0; $i<@$class_files; $i++) {
			$self->{ClassBox}->AddFile($class_files->[$i],$parser_panel->{ClassBox}->{ListBox}->GetString($i))
		}
	}
	if (defined $flag_files) {
		for (my $i = 0; $i<@$flag_files; $i++) {
			$self->{FlagBox}->AddFile($flag_files->[$i],$parser_panel->{FlagBox}->{ListBox}->GetString($i))
		}	
	}
	$self->{BitTextBox}->SetValue($parser_panel->{BitTextBox}->GetValue());
	$self->{EValueTextBox}->SetValue($parser_panel->{EValueTextBox}->GetValue());
	
	$self->{ParserName} = $parser_panel->{ParserName};
	$self->{BlastFilePath} = $parser_panel->{BlastFilePath};
	$self->{FastaFilePath} = $parser_panel->{FastaFilePath};
	$self->{OutputDirectoryPath} = $parser_panel->{OutputDirectoryPath};
	$self->{DirectoryCheckBox}->SetValue($parser_panel->{DirectoryCheckBox}->GetValue);
	my @roots = ();
	for (my $i=0; $i<$parser_panel->{RootList}->GetCount; $i++) {
		push(@roots,$parser_panel->{RootList}->GetString($i));
	}
	$self->{RootList}->Set(\@roots);
	$self->{SourceCombo}->SetValue($parser_panel->{SourceCombo}->GetValue);
}


package QueuePanel;

use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use Wx::Event qw(EVT_MENU);
use Wx::Event qw(EVT_TREE_ITEM_ACTIVATED);
use Wx::Event qw(EVT_TEXT);
use Wx::Event qw(EVT_COMBOBOX);
use Wx::Event qw(EVT_CHECKBOX);
use Wx::Event qw(EVT_LISTBOX);
use Wx::Event qw(EVT_LISTBOX_DCLICK);

use base 'Wx::Panel';

sub new {
	my ($class,$parent) = @_;
	
	my $self = $class->SUPER::new($parent,-1);
	
	$self->{Parent} = $parent;
	$self->{QueueList} = undef;
	$self->{GenerateList} = undef;
	$self->{Parsers} = ();
	$self->{NewParserPanels} = (); #array
	$self->{QueuedPanels} = (); #array
	$self->{ParserPanel} = undef; # the current parser panel being displayed.
	
	bless ($self,$class);
	$self->SetPanels();
	return $self;
}

sub SetPanels {
	my ($self) = @_;
	
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->SetBackgroundColour($turq);
	
	$sizer->Add($self,1,wxGROW);
	$self->SetSizer($sizer);
	
	$self->{PanelSizer} = Wx::BoxSizer->new(wxHORIZONTAL);
	
	$self->SetGeneratePanel();
	
	$self->{ParserPanel} = Wx::Panel->new($self,-1);
	
	$self->SetQueuePanel();

	$self->{PanelSizer}->Add($self->{GeneratePanel},1,wxEXPAND);
	$self->{PanelSizer}->Add($self->{ParserPanel},2,wxEXPAND);
	$self->{PanelSizer}->Add($self->{QueuePanel},1,wxEXPAND);
	
	$self->SetSizer($self->{PanelSizer});
	$self->NewParser();
}

sub SetGeneratePanel {
	my ($self) = @_;
	
	$self->{GeneratePanel} = Wx::Panel->new($self,-1);
	$self->{GeneratePanel}->SetBackgroundColour($turq);
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $listlabel = Wx::StaticBox->new($self->{GeneratePanel},-1,"Parsers in progress");
	my $listsizer = Wx::StaticBoxSizer->new($listlabel,wxVERTICAL);
	$self->{GenerateList} = Wx::ListBox->new($self->{GeneratePanel},-1,wxDefaultPosition(),wxDefaultSize());
	$listsizer->Add($self->{GenerateList},1,wxEXPAND);
	
	my $button_sizer_h = Wx::BoxSizer->new(wxVERTICAL);
	my $button_sizer_v = Wx::BoxSizer->new(wxHORIZONTAL);
	my $new_button = Wx::Button->new($self->{GeneratePanel},-1,'New');
	$button_sizer_h->Add($new_button,1,wxCENTER);
	$button_sizer_v->Add($button_sizer_h,1,wxCENTER);
	EVT_BUTTON($self->{GeneratePanel},$new_button,sub{$self->NewParser()});
	
	$sizer->Add($listsizer,7,wxEXPAND);
	$sizer->Add($button_sizer_v,1,wxCENTER);
	
	$self->{GeneratePanel}->SetSizer($sizer);
	$self->{GeneratePanel}->Layout;
	
	EVT_LISTBOX($self->{GeneratePanel},$self->{GenerateList},sub{$self->DisplayParserPanel($self->{GenerateList}->GetSelection); });
	EVT_LISTBOX_DCLICK($self->{GeneratePanel},$self->{GenerateList},sub{$self->DeleteParser()});
}

sub DisplayParserPanel {
	my ($self,$selection) = @_;
	$self->{QueueList}->SetSelection(-1);
	$self->{GenerateList}->SetSelection($selection);
	$self->DisplayPanel($self->{ParserPanels},$selection);
}

sub ShowPanel {
	my ($self,$page,$current_array) = @_;
	for my $panel(@{$current_array}) {
		if ($panel eq $page) {
			$page->Show;
			if ($self->{ParserPanel} ne $page) {
				$self->{PanelSizer}->Replace($self->{ParserPanel},$page);
				$self->{ParserPanel}->Hide;
				$self->{ParserPanel} = $page;
			}
		}
		else {
			$panel->Hide;
		}
	}
	$self->{ParserPanel}->Layout;
	$self->Refresh;
	$self->Layout;
}

sub DisplayPanel {
	my ($self,$array,$selection) = @_;
	my $page = $array->[$selection];
	$self->ShowPanel($page,$array);
}

sub NewParser {
	my ($self) = @_;
	
	my $parser_panel = ParserPanel->new($self);
	
	push(@{$self->{ParserPanels}},$parser_panel);
	my $count = $self->{GenerateList}->GetCount;
	$self->{GenerateList}->InsertItems(["New Parser"],$count);
	$self->{GenerateList}->SetSelection($count);
	
	EVT_TEXT($parser_panel,$parser_panel->{ParserNameTextCtrl},
	sub{$self->{GenerateList}->SetString($self->{GenerateList}->GetSelection,$parser_panel->{ParserNameTextCtrl}->GetValue);});
	EVT_BUTTON($parser_panel,$parser_panel->{QueueButton},sub{$self->NewProcessForQueue()});
	
	$self->DisplayParserPanel($self->{GenerateList}->GetCount - 1);
}

sub DeleteParser {
	my ($self) = @_;
	
	my $delete_dialog = OkDialog->new($self->GetParent,"Delete","Delete Parser?");
	if ($delete_dialog->ShowModal == wxID_OK) {
			my $selection = $self->{GenerateList}->GetSelection;
			$self->{GenerateList}->Delete($selection);
			my $delete_panel = splice(@{$self->{ParserPanels}},$selection,1);
			if (@{$self->{ParserPanels}} == 0) {
				$self->NewParser();
			}
			else {
				if ($selection == 0) {
					$self->{GenerateList}->SetSelection($selection);
					$self->DisplayParserPanel($selection);
				}
				else {
					$self->{GenerateList}->SetSelection($selection - 1);
					$self->DisplayParserPanel($selection - 1);
				}
			}
			$delete_panel->Destroy;
			$self->Refresh;
			$self->Layout;
	}
	$delete_dialog->Destroy;
}

sub SetQueuePanel {
	my ($self) = @_;
	
	$self->{QueuePanel} = Wx::Panel->new($self,-1);
	$self->{QueuePanel}->SetBackgroundColour($turq);
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $listlabel = Wx::StaticBox->new($self->{QueuePanel},-1,"Queue");
	my $listsizer = Wx::StaticBoxSizer->new($listlabel,wxVERTICAL);
	$self->{QueueList} = Wx::ListBox->new($self->{QueuePanel},-1,wxDefaultPosition(),wxDefaultSize());
	$listsizer->Add($self->{QueueList},1,wxEXPAND);
	
	my $button_sizer_h = Wx::BoxSizer->new(wxVERTICAL);
	my $button_sizer_v = Wx::BoxSizer->new(wxHORIZONTAL);
	my $run_button = Wx::Button->new($self->{QueuePanel},1,"Run");
	$button_sizer_h->Add($run_button,1,wxCENTER);
	$button_sizer_v->Add($button_sizer_h,1,wxCENTER);
	EVT_BUTTON($self->{QueuePanel},$run_button,sub{$self->Run()});
	
	$sizer->Add($listsizer,7,wxEXPAND);
	$sizer->Add($button_sizer_v,1,wxCENTER);
	
	$self->{QueuePanel}->SetSizer($sizer);
	$self->{QueuePanel}->Layout;
	
	EVT_LISTBOX($self->{QueuePanel},$self->{QueueList},sub{$self->DisplayQueueParser($self->{QueueList}->GetSelection);});
	EVT_LISTBOX_DCLICK($self->{QueuePanel},$self->{QueueList},sub{$self->DeleteFromQueue()});
}

sub DisplayQueueParser {
	my ($self,$selection) = @_;
	$self->{GenerateList}->SetSelection(-1);
	$self->{QueueList}->SetSelection($selection);
	$self->DisplayPanel($self->{QueuedPanels},$selection);
}

sub DeleteFromQueue {
	my ($self) = @_;
	my $delete_dialog = OkDialog->new($self->GetParent(),"Delete","Delete Queued Parser?");
	if ($delete_dialog->ShowModal == wxID_OK) {
		my $selection = $self->{QueueList}->GetSelection;
		$self->{QueueList}->Delete($selection);
		my $queue_panel = splice(@{$self->{QueuedPanels}},$selection,1);
		if (@{$self->{QueuedPanels}} == 0) {
			$self->DisplayParserPanel(0);
		}
		else {
			if ($selection == 0) {
					$self->DisplayQueueParser($selection);
				}
				else {
					$self->DisplayQueueParser($selection - 1);
				}
		}
		$queue_panel->Destroy;
		$self->Refresh;
		$self->Layout;
	}
	$delete_dialog->Destroy;
}

sub NewProcessForQueue {
	my ($self) = @_;
	
	my $page = $self->{ParserPanel};
	
	if ($page->CheckProcess() == 0) {
		$self->GetParent()->SetStatusText("Please Choose a Parsing Name");
		return 0;	
	}
	elsif ($page->CheckProcess() == -1) {
		$self->GetParent()->SetStatusText("Please Choose a BLAST Output File");
		return 0;	
	}
	elsif ($page->CheckProcess() == -2) {
		$self->GetParent()->SetStatusText("Please Choose a FASTA File");
		return 0;	
	}
	elsif ($page->CheckProcess() == -3) {
		$self->AddProcessQueue();
	}
	elsif ($page->CheckProcess() == 1) {
		$self->AddProcessQueue();
	}
	else {
		return 0;
	}
}

sub AddProcessQueue {
	my ($self) = @_;
	my $count = $self->{QueueList}->GetCount;
	my $label = $self->{GenerateList}->GetStringSelection;
	$self->{QueueList}->InsertItems([$label],$count);
	my $queue_panel = ParserPanel->new($self);
	$queue_panel->CopyData($self->{ParserPanel});
	push(@{$self->{QueuedPanels}},$queue_panel);
	EVT_TEXT($queue_panel,$queue_panel->{ParserNameTextCtrl},sub{$self->{QueueList}->SetString($self->{QueueList}->GetSelection,$queue_panel->{ParserNameTextCtrl}->GetValue);});
}

sub GenerateParser {
	my ($self,$page) = @_;
	
	my $parser = BlastParser->new($page->{ParserNameTextCtrl}->GetValue);
	
	$parser->SetBlastFile($page->{BlastFilePath});
	$parser->SetSequenceFile($page->{FastaFilePath});
	
	$parser->SetParameters($page->{BitTextBox}->GetValue,$page->{EValueTextBox}->GetValue);
	
	my @classes = ();
	my @flags = ();
	my $class_files = $page->{ClassBox}->GetAllFiles;
	my $flag_files = $page->{FlagBox}->GetAllFiles;
	for my $class_file(@$class_files) {
		my $class = Classification->new($class_file,$control);
		push(@classes,$class);
	}
	for my $flag_file (@$flag_files) {
		my $flag = FlagItems->new($page->{OutputDirectoryPath},$flag_file,$control);
		push(@flags,$flag);
	}
	
	my $taxonomy;
	if ($page->{SourceCombo}->GetValue ne "") {
		my @ranks = ();
		my @roots = $page->{RootList}->GetStrings;
		if ($page->{SourceCombo}->GetValue eq "Connection") {
			$taxonomy = ConnectionTaxonomy->new(\@ranks,\@roots,$control);
		}
		else {
			$taxonomy = FlatFileTaxonomy->new($control->{NodesFile},$control->{NamesFile},\@ranks,\@roots,$control);
		}
	}
	
	if ($page->{TableCheck}->GetValue==1) {
		my $table = SendTable->new($control);
		$parser->AddProcess($table);
	}
	if ($page->{OutputDirectoryPath} ne "") { # should be directory checked instead
		my $text;
		if (defined $taxonomy) {
			$text = TaxonomyTextPrinter->new($page->{OutputDirectoryPath},$taxonomy,$control);
		}
		else {
			$text = TextPrinter->new($page->{OutputDirectoryPath},$control);
		}
		for my $class(@classes) {
			$text->AddProcess($class);
		}
		for my $flag(@flags) {
			$text->AddProcess($flag);
		}
		$parser->AddProcess($text);
	}
	else {
		for my $class(@classes) {
			$parser->AddProcess($class);
		}
		for my $flag(@flags) {
			$parser->AddProcess($flag);
		}
		if (defined $taxonomy) {
			$parser->AddProcess($taxonomy);
		}
	}
	push(@{$self->{Parsers}},$parser);
}

sub RunParsers {
	my ($self) = @_;
	
	my $progress_dialog = Wx::ProgressDialog->new("","",100,$self,wxSTAY_ON_TOP|wxPD_APP_MODAL);
	for my $parser(@{$self->{Parsers}}) {
		my $key = $control->AddParserName($parser->{Label});
		my $dir = $control->CreateResultFolder($key);
		$parser->prepare($key,$dir);
		my @label_strings = split(/\//,$parser->{BlastFile});
		my $label = $label_strings[@label_strings - 1];
		$progress_dialog->Update(-1,"Parsing " . $label . " ...");
		$progress_dialog->Fit();
		$parser->Parse($progress_dialog);
	}
	$progress_dialog->Destroy;
	$self->GetParent()->SetStatusText("Done Parsing");
}

sub Run {
	my ($self) = @_;
	my $count = $self->{QueueList}->GetCount;
	if ($count > 0) {
		my $count_string = "parser";
		if ($count > 1) {
			$count_string = "parsers";
		}
		my $run_dialog = OkDialog->new($self->GetParent(),"Run Parsers","$count " . $count_string . " to run. Continue?");
		if ($run_dialog->ShowModal == wxID_OK) {
			$run_dialog->Destroy;
			for my $queue_panel(@{$self->{QueuedPanels}}) {
				$self->GenerateParser($queue_panel);
			}
			$self->RunParsers();
		}
		else {
			$run_dialog->Destroy;
		}
	}
	else {
		$self->GetParent()->SetStatusText("No Files to Parse");
	}
}

package ResultsManager;
use Wx qw /:everything/;
use Wx::Event qw(EVT_LIST_ITEM_SELECTED);
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED);
use Wx::Event qw(EVT_LIST_COL_CLICK);
use Wx::Event qw(EVT_SIZE);
use base 'Wx::Panel';

sub new {
	my ($class,$parent) = @_;
	
	my $self = $class->SUPER::new($parent,-1);
	$self->SetBackgroundColour($turq);
	$self->{Parent} = $parent;
	$self->{Keys} = ();
	$self->{Sizer} = Wx::BoxSizer->new(wxVERTICAL);
	$self->ShowResults();
	
	bless ($self,$class);
	return $self;
}

sub UpdateItems {
	my ($self) = @_;
	$self->{ResultsCtrl}->ClearAll;
	$self->SetupListCtrl();
	$self->Fill();
}

sub ShowResults {
	my ($self) = @_;
	
	$self->{ResultsCtrl} = Wx::ListCtrl->new($self,-1,wxDefaultPosition,wxDefaultSize,wxLC_REPORT|wxLC_SINGLE_SEL);
	$self->SetupListCtrl();
	$self->Fill();
	
	$self->{Sizer}->Add($self->{ResultsCtrl},1,wxEXPAND|wxTOP|wxBOTTOM|wxRIGHT|wxLEFT,5);
	$self->SetSizer($self->{Sizer});
	
	EVT_SIZE($self,\&OnSize);
	EVT_LIST_ITEM_ACTIVATED($self,$self->{ResultsCtrl},sub{$self->DeleteDialog($_[1]->GetIndex());});
}

sub SetupListCtrl {
	my ($self) = @_;
	$self->{ResultsCtrl}->InsertColumn(0,"Result Name");
	$self->{ResultsCtrl}->InsertColumn(1,"Date Created");
	$self->{ResultsCtrl}->InsertColumn(2,"Size");
	
	my $size = $self->{Parent}->GetClientSize();
	my $width = $size->GetWidth();
	
	$self->{ResultsCtrl}->SetColumnWidth(0,$width/2);
	$self->{ResultsCtrl}->SetColumnWidth(1,$width/4);
	$self->{ResultsCtrl}->SetColumnWidth(2,$width/4);
}

sub OnSize {
	my ($self,$event) = @_;;
	my $size = $self->{Parent}->GetClientSize();
	my $width = $size->GetWidth();
	
	$self->{ResultsCtrl}->SetColumnWidth(0,$width/2);
	$self->{ResultsCtrl}->SetColumnWidth(1,$width/4);
	$self->{ResultsCtrl}->SetColumnWidth(2,$width/4);
	
	$self->Refresh;
	$self->Layout;
}

sub Fill {
	my ($self) = @_;
	my $parser_names = $control->GetParserNames();
	my $i = 0;
	for my $key(keys(%{$parser_names})) {
		push(@{$self->{Keys}},$key);
		my $item = $self->{ResultsCtrl}->InsertStringItem($i,"");
		$self->{ResultsCtrl}->SetItemData($item,$i);
		$self->{ResultsCtrl}->SetItem($i,0,$parser_names->{$key});
		$self->{ResultsCtrl}->SetItem($i,1,$self->GetDate($key));
		$self->{ResultsCtrl}->SetItem($i,2,$control->GetDirSize($key));
		$i++;
	}
}

sub GetDate {
	my ($self,$key) = @_;
	# to be removed from program release
	if ($key =~ /187111/) {
		return "August 18, 2011";
	}
	my %months = (0=>"January",1=>"February",2=>"March",3=>"April",4=>"May",5=>"June",6=>"July",7=>"August",8=>"September",9=>"October",10=>"November",11=>"December");
	my $day = $1 if ($key =~ /d(\d{1,2})/);
	my $month_key = $1 if ($key =~ /m(\d{1,2})/);
	my $year_numb = $1 if ($key =~ /y(\d{3})/);
	my $month = $months{$month_key};
	my $year = 1900 + $year_numb;
	return "$month $day, $year";
}

sub DeleteDialog {
	my ($self,$index) = @_;
	my $delete_dialog = OkDialog->new($self->{Parent},"Delete Result","Delete " . $self->{ResultsCtrl}->GetItemText($index) . "?");
	if ($delete_dialog->ShowModal == wxID_OK) {
		$self->{ResultsCtrl}->DeleteItem($index);
		my $key = $self->{Keys}->[$index];
		splice(@{$self->{Keys}},$index,1);
		$control->DeleteResult($key);
	}
	$delete_dialog->Destroy;
}

package Display;
use Cwd;
use base 'Wx::Frame';
use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use Wx::Event qw(EVT_MENU);
use Wx::Event qw(EVT_TREE_ITEM_ACTIVATED);
use Wx::Event qw(EVT_TEXT);
use Wx::Event qw(EVT_COMBOBOX);
use Wx::Event qw(EVT_CHECKBOX);
use Wx::Event qw(EVT_LISTBOX);
use Wx::Event qw(EVT_LISTBOX_DCLICK);

sub new {
	my ($class) = shift;

	my $self = $class->SUPER::new(undef,-1,'PACT',[-1,-1],[1200,600],);
	
	$self->{Sizer} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{QueuePanel} = undef;
	$self->{TaxPiePanel} = undef;
	$self->{ClassPiePanel} = undef;
	$self->{TablePanel} = undef;
	$self->{TreePanel} = undef;
	$self->{TreeViewPanel} = undef;
	$self->{ResultsPanel} = undef;
	$self->{PanelArray} = ();
	
	$self->SetSizer($self->{Sizer});

	$self->Centre();
	$self->OnProcessClicked(0);
	return $self;
}

## Shows the selected panel and hides all others
sub DisplayPanel {
	my ($self,$show_panel) = @_;
	for my $panel(@{$self->{PanelArray}}) {
		if ($panel eq $show_panel) {
			if (defined $show_panel) {
				$self->Refresh;
				$show_panel->Show;
			}
		}
		else {
			if (defined $panel) {
				$panel->Hide;
			}
		}
	}
	$self->{Sizer}->Clear;
	$self->{Sizer}->Add($show_panel,1,wxEXPAND);
	$self->Layout;
} 

sub OnProcessClicked {
	my ($self,$event) = @_;
	if (not defined $self->{QueuePanel}) {
		$self->{QueuePanel} = QueuePanel->new($self);
		push(@{$self->{PanelArray}},$self->{QueuePanel});	
	}
	$self->DisplayPanel($self->{QueuePanel});
}

sub InitializeTaxPieMenu {
	my($self,$event) = @_;
	if (not defined $self->{TaxPiePanel}) {
		$self->{TaxPiePanel} = TaxonomyPiePanel->new($self,"Taxonomy Results","Pie Charts");
		push(@{$self->{PanelArray}},$self->{TaxPiePanel});	
	}
	$self->DisplayPanel($self->{TaxPiePanel});
}

sub InitializeClassPieMenu {
	my($self,$event) = @_;
	if (not defined $self->{ClassPiePanel}) {
		$self->{ClassPiePanel} = ClassificationPiePanel->new($self,"Classification Results","Pie Charts");
		push(@{$self->{PanelArray}},$self->{ClassPiePanel});	
	}
	$self->DisplayPanel($self->{ClassPiePanel});
}

sub InitializeTreeSaveMenu {
	my($self,$event) = @_;
	if (not defined $self->{TreePanel}) {
		$self->{TreePanel} = TreeMenu->new($self);
		push(@{$self->{PanelArray}},$self->{TreePanel});	
	}
	$self->DisplayPanel($self->{TreePanel});
}

sub InitializeTreeViewMenu {
	my ($self,$event) = @_;
	if (not defined $self->{TreeViewPanel}) {
		$self->{TreeViewPanel} = TreeViewPanel->new($self);
		push(@{$self->{PanelArray}},$self->{TreeViewPanel});
	}
	$self->DisplayPanel($self->{TreeViewPanel});

}

sub InitializeTableViewer {
	my($self,$event) = @_;
	if (not defined $self->{TablePanel}) {
		$self->{TablePanel} = TableMenu->new($self);
		push(@{$self->{PanelArray}},$self->{TablePanel});	
	}
	else {
		$self->{TablePanel}->UpdateItems();
	}
	$self->DisplayPanel($self->{TablePanel});
	
}

sub InitializeResultManager {
	my ($self,$event) = @_;
	if (not defined $self->{ResultsPanel}) {
		$self->{ResultsPanel} = ResultsManager->new($self);
		push(@{$self->{PanelArray}},$self->{ResultsPanel});	
	}
	else {
		$self->{ResultsPanel}->UpdateItems();
	}
	$self->DisplayPanel($self->{ResultsPanel});
}

sub TaxonomyFileUpdater {
	my ($self,$event) = @_;
	my $update_dialog = OkDialog->new($self,"Update NCBI Taxonomy Files","New files will be downloaded from: ftp://ftp.ncbi.nih.gov/pub/taxonomy/\nProceed?");
	if ($update_dialog->ShowModal == wxID_OK) {
		$control->DownloadNCBITaxonomies();
	}
	$update_dialog->Destroy;
}

sub ShowContents {
	my ($self,$event) = @_;
	my $contents_frame = Wx::Frame->new(undef,-1,"PACT Contents",[-1,-1],[-1,-1]);
	my $size = $contents_frame->GetClientSize();
	my $width = $size->GetWidth();
	my $height = $size->GetHeight();
	my $window = Wx::HtmlWindow->new($contents_frame,-1);
	$window->SetSize($width,$height);
	$window->LoadPage($control->{CurrentDirectory} . $control->{PathSeparator} . "contents.html");
	$contents_frame->Show();
}

sub TopMenu {
	my ($self) = @_;

	$self->{FileMenu} = Wx::Menu->new();
	my $newblast = $self->{FileMenu}->Append(101,"Parser Menu");
	my $manage = $self->{FileMenu}->Append(102,"Manage Results");
	$self->{FileMenu}->AppendSeparator();
	my $updater = $self->{FileMenu}->Append(103,"Update NCBI Taxonomy Files");
	$self->{FileMenu}->AppendSeparator();
	my $save_trees = $self->{FileMenu}->Append(104,"Save Trees");
	$self->{FileMenu}->AppendSeparator();
	my $close = $self->{FileMenu}->Append(105,"Quit");
	EVT_MENU($self,101,\&OnProcessClicked);
	EVT_MENU($self,102,\&InitializeResultManager);
	EVT_MENU($self,103,\&TaxonomyFileUpdater);
	EVT_MENU($self,104,\&InitializeTreeSaveMenu);
	EVT_MENU($self,105,sub{$self->Close(1)});

	my $viewmenu = Wx::Menu->new();
	my $table = $viewmenu->Append(201,"Table");
	my $pie = Wx::Menu->new();
	$viewmenu->AppendSubMenu($pie,"Pie Charts");
	$pie->Append(202,"Taxonomy");
	$pie->Append(203,"Classification");
	my $tax = $viewmenu->Append(204,"Tree");
	EVT_MENU($self,201,\&InitializeTableViewer);
	EVT_MENU($self,202,\&InitializeTaxPieMenu);
	EVT_MENU($self,203,\&InitializeClassPieMenu);
	EVT_MENU($self,204,\&InitializeTreeViewMenu);
	
	my $helpmenu = Wx::Menu->new();
	my $manual = $helpmenu->Append(301,"Contents");
	EVT_MENU($self,301,\&ShowContents);

	my $menubar = Wx::MenuBar->new();
	$menubar->Append($self->{FileMenu},"File");
	$menubar->Append($viewmenu,"View");
	$menubar->Append($helpmenu,"Help");
	$self->SetMenuBar($menubar);

	my $status_bar = Wx::StatusBar->new($self,-1);
	$self->SetStatusBar($status_bar);
	$self->SetStatusText('Pyrosequence Annotation and Categorization Tool');
	
	$self->SetMinSize(Wx::Size->new(700,450));
}

package Application;
use base 'Wx::App';

sub OnInit {
	my $self = shift;
	Wx::InitAllImageHandlers();
	my $display = Display->new();
	$display->TopMenu();
	$display->Show();
	return 1;
}

package main;
my $app = Application->new;
$app->MainLoop;
