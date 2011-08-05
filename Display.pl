use Wx::Perl::Packager;
use strict;
use Wx;
use Parser;
use PieViewer;
use TaxonomyViewer;
use IO::File;
use Cwd;

# Global colors
my $turq = Wx::Colour->new("TURQUOISE");
my $blue = Wx::Colour->new(130,195,250);

package ProgramControl;
use Cwd;
use LWP::Simple;
use Archive::Tar;
use Fcntl;
use DB_File;
use File::Basename;

sub new {
	my $class = shift;
	my $self = {
		CurrentDirectory => getcwd,
	};
	bless ($self,$class);
	$self->GetPathSeparator();
	$self->MakeResultsFolder();
	$self->ParserNames();
	$self->CreateDatabase();
	$self->MakeColorPrefsFolder();
	$self->SetTaxDump();
	return $self;
}

sub SetTaxDump {
	my ($self) = @_;
	$self->{TaxDump} = $self->{CurrentDirectory} . $self->{PathSeparator} . "taxdump";
	mkdir($self->{TaxDump});
	chdir($self->{TaxDump});
	#getstore("ftp://ftp.ncbi.nih.gov/pub/taxonomy","taxdump.tar.gz");
	#my $tar = Archive::Tar->new;
	#$tar->read("ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz");
	#$tar->extract();
	$self->{NodesFile} = $self->{TaxDump} . $self->{PathSeparator} . "nodes.dmp";
	$self->{NamesFile} = $self->{TaxDump} . $self->{PathSeparator} . "names.dmp";
}

sub DownloadNCBITaxonomies {
	my $self = shift;
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

sub ParserNames {
	my ($self) = @_;
	chdir($self->{CurrentDirectory});
	tie(my %PARSERNAMES,'DB_File',"PARSERNAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
}

sub AddParserName {
	my ($self,$parser_name) = @_;
	chdir($self->{CurrentDirectory});
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
	chdir($self->{CurrentDirectory});
	tie(my %PARSERNAMES,'DB_File',"PARSERNAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
	$PARSERNAMES{$key};
}

sub GetParserNames {
	my ($self) = @_;
	chdir($self->{CurrentDirectory});
	tie(my %PARSERNAMES,'DB_File',"PARSERNAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open $!";
	return \%PARSERNAMES;
}

sub AddTableName {
	my ($self,$label,$key) = @_;
	chdir($self->{CurrentDirectory});
	tie(my %TABLENAMES,'DB_File',"TABLENAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open TableNames: $!";
	$TABLENAMES{$key} = $label;
}

sub GetTableNames {
	my ($self) = @_;
	chdir($self->{CurrentDirectory});
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
	$name_key = $name_key . $timeData[3] . $timeData[4] . $timeData[5];
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
		next unless (-d "$dir/$key");
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
	chdir($self->{CurrentDirectory});
	$self->{Connection} = DBI->connect("dbi:SQLite:Results.db","","") or die("Could not open database");
	tie(my %TABLENAMES,'DB_File',"TABLENAMES.db",O_CREAT|O_RDWR,0644) or die "Cannot open TableNames: $!";
}

sub GetPathSeparator {
	my ($self) = @_;
	my $os = $^O;
	if (($os eq "darwin") or ($os eq "MacOS") or ($os eq "linux")) {
		$self->{PathSeparator} = "/";
	}
	elsif ($os eq "MSWin32") {
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
	$self->Display($parent,$title,$dialog);
	return $self;
}

sub Display {
	my ($self,$parent,$title,$dialog) = @_;
	$self->{Panel} = Wx::Panel->new($self,-1);
	$self->{Panel}->SetBackgroundColour($turq);
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $text_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $text = Wx::StaticText->new($self->{Panel},-1,$dialog);
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
	bless ($self,$class);
	$self->TreeBox();
	$self->FillTrees();
	$self->Layout;
	return $self;
}

sub TreeBox {
	my ($self) = @_;
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);

	my $tax_view_panel = Wx::Panel->new($self);
	$tax_view_panel->SetBackgroundColour($blue);
	my $tax_view_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $tax_file_label = Wx::StaticBox->new($tax_view_panel,-1,"Choose Taxonomy Results");
	my $tax_file_label_sizer = Wx::StaticBoxSizer->new($tax_file_label,wxHORIZONTAL);
	$self->{TreeFileListBox} = FileBox->new($tax_view_panel);
	$tax_file_label_sizer->Add($self->{TreeFileListBox}->{ListBox},1,wxCENTER|wxEXPAND);
	my $file_button_sizer_outer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $file_button_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $add_button = Wx::Button->new($tax_view_panel,-1,"Add");
	$file_button_sizer->Add($add_button,1,wxCENTER|wxBOTTOM,10);
	$file_button_sizer_outer->Add($file_button_sizer,1,wxCENTER);
	my $tax_view_label = Wx::StaticBox->new($tax_view_panel,-1,"Taxonomy Results To View");
	my $tax_view_label_sizer = Wx::StaticBoxSizer->new($tax_view_label,wxHORIZONTAL);
	$self->{TreeViewListBox} = FileBox->new($tax_view_panel);
	$tax_view_label_sizer->Add($self->{TreeViewListBox}->{ListBox},1,wxCENTER|wxEXPAND);
	$tax_view_sizer->Add($tax_file_label_sizer,3,wxEXPAND);
	$tax_view_sizer->Add($file_button_sizer_outer,1,wxEXPAND);
	$tax_view_sizer->Add($tax_view_label_sizer,3,wxEXPAND);
	$tax_view_panel->SetSizer($tax_view_sizer);

	my $title_sizer = Wx::BoxSizer->new(wxHORIZONTAL);	
	my $title_label = Wx::StaticBox->new($self,-1,"Title");
	my $title_label_sizer = Wx::StaticBoxSizer->new($title_label,wxHORIZONTAL);
	my $title_ctrl = Wx::TextCtrl->new($self,-1,"");
	$title_label_sizer->Add($title_ctrl,1,wxCENTER);
	$title_sizer->Add(Wx::BoxSizer->new(wxHORIZONTAL),1,wxLEFT);
	$title_sizer->Add($title_label_sizer,3,wxCENTER|wxEXPAND);
	$title_sizer->Add(Wx::BoxSizer->new(wxHORIZONTAL),1,wxRIGHT);
	
	my $g_button_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $g_button_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $g_button = Wx::Button->new($self,-1,"Generate");	
	$g_button_sizer_v->Add($g_button,1,wxCENTER);
	$g_button_sizer_h->Add($g_button_sizer_v,1,wxCENTER);

	$sizer->Add($tax_view_panel,7,wxEXPAND|wxLEFT|wxRIGHT,10);
	$sizer->Add($title_sizer,2,wxCENTER|wxEXPAND);
	$sizer->Add($g_button_sizer_h,1,wxEXPAND);
	$self->SetSizer($sizer);
	
	EVT_BUTTON($self,$add_button,sub{$self->{TreeViewListBox}->AddFile($self->{TreeFileListBox}->GetFile(),$self->{TreeFileListBox}->{ListBox}->GetStringSelection)});
	EVT_LISTBOX_DCLICK($self,$self->{TreeViewListBox}->{ListBox},sub{$self->DeleteTree()});
	EVT_BUTTON($self,$g_button,sub{$self->Generate($self->{TreeViewListBox}->GetAllFiles(),$title_ctrl->GetValue)});
}

sub FillTrees {
	my ($self) = @_;
	$control->GetTaxonomyFiles($self->{TreeFileListBox});
}

sub DeleteTree {
	my ($self) = @_;
	my $delete_dialog = OkDialog->new($self,"Delete","Remove Tree?");
	if ($delete_dialog->ShowModal == wxID_OK) {
		$self->{TreeViewListBox}->DeleteFile();
	}
	$delete_dialog->Destroy;
}

sub Generate {
	my ($self,$files,$title) = @_;
	my @trees = ();
	
	for my $file(@$files) {
		my $names = $control->GetTaxonomyNodeNames($file);
		my $treeio = new Bio::TreeIO(-format => 'newick', -file => $file);
		my $tree = $treeio->next_tree;
		for my $node($tree->get_nodes) {
			$node->id($names->{$node->id});
		}
		push(@trees,$tree);
	}
	if (@trees > 0) {
		my $frame = TaxonomyViewer->new(\@trees,$title);
	}
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
	my ($class,$parent,$label) = @_;
	
	my $self = $class->SUPER::new($parent,-1);
	$self->SetBackgroundColour($turq);
	$self->{ParentNotebook} = $parent;
	$self->{PieNotebook} = undef;
	$self->{TypePanel} = undef;
	$self->{Sizer} = undef; 
	$self->{TypeSizer} = undef;
	$self->{ObjectDataReaders} = [];
	$self->{FileHash} = ();
	
	bless ($self,$class);
	$self->MainDisplay($label);
	$self->Layout;
	return $self;
}

sub MainDisplay {

	my ($self,$label) = @_;

	$self->{Sizer} = Wx::BoxSizer->new(wxVERTICAL);
	my $center_display = Wx::BoxSizer->new(wxHORIZONTAL);

	my $file_panel = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$file_panel->SetBackgroundColour($blue);
	my $file_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	
	my $file_list_label = Wx::StaticBox->new($file_panel,-1,$label);
	my $file_list_label_sizer = Wx::StaticBoxSizer->new($file_list_label,wxVERTICAL);
	$self->{FileBox} = FileBox->new($file_panel);
	$self->FillObjects();
	$file_list_label_sizer->Add($self->{FileBox}->{ListBox},1,wxEXPAND);
	
	$file_sizer->Add($file_list_label_sizer,3,wxCENTER|wxEXPAND);
	$file_panel->Layout;
	$file_panel->SetSizer($file_sizer);
	
	my $file_button_sizer_outer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $file_button_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $add_button = Wx::Button->new($self,-1,"Add");
	my $remove_button = Wx::Button->new($self,-1,"Remove");
	$file_button_sizer->Add($add_button,1,wxCENTER|wxBOTTOM,10);
	$file_button_sizer->Add($remove_button,1,wxCENTER|wxTOP,10);
	$file_button_sizer_outer->Add($file_button_sizer,1,wxCENTER);
	
	$self->{TypePanel} = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$self->{TypePanel}->SetBackgroundColour($blue);
	$self->{TypeSizer} = Wx::BoxSizer->new(wxVERTICAL);
	
	$self->{PieNotebook} = Wx::Notebook->new($self->{TypePanel},-1);
	$self->{PieNotebook}->SetBackgroundColour($blue);
	$self->{TypeSizer}->Add($self->{PieNotebook},1,wxEXPAND);
	$self->{TypePanel}->SetSizer($self->{TypeSizer});
	$self->{TypePanel}->Layout;
	
	$center_display->Add($file_panel,3,wxTOP|wxCENTER|wxEXPAND|wxBOTTOM,10);
	$center_display->Add($file_button_sizer_outer,1,wxCENTER|wxEXPAND,10);
	$center_display->Add($self->{TypePanel},5,wxBOTTOM|wxCENTER|wxEXPAND,10);
	
	$self->{Sizer}->Add($center_display,1,wxCENTER|wxEXPAND);
	$self->SetSizer($self->{Sizer});
	$self->Layout;
	
	
	my $parent = $self->{ParentNotebook}->GetParent();
	while (defined $parent->GetParent) {
		$parent = $parent->GetParent;
	}
	
	EVT_BUTTON($self,$add_button,sub{$self->NewPieChart();});
	EVT_BUTTON($self,$remove_button,sub{$self->DeleteChart($parent);});
}

sub DeleteChart {
	my ($self,$parent) = @_;
	my $delete_dialog = OkDialog->new($parent,"Delete","Remove Pie Chart?");
	if ($delete_dialog->ShowModal == wxID_OK) {
		my $selection = $self->{PieNotebook}->GetSelection();
		splice(@{$self->{ObjectDataReaders}},$selection,1);
		$self->{PieNotebook}->DeletePage($selection);
	}
	$delete_dialog->Destroy;
}

sub NewPieChart {
	my ($self) = @_;
	my $data_reader = ClassificationXML->new($self->{FileBox}->GetFile());
	my $new_page = $self->TypePanel($data_reader);
	push(@{$self->{ObjectDataReaders}},$data_reader);
	$self->{PieNotebook}->AddPage($new_page,$self->{FileBox}->{ListBox}->GetStringSelection);
	$self->{PieNotebook}->Layout;
}

sub FillObjects {
	my ($self) = @_;
	$control->GetClassificationFiles($self->{FileBox});
}

sub GenerateCharts {
	my ($self) = @_;
	
	if ($self->{PieNotebook}->GetPageCount == 0) {
		return 0;
	}
	
	my @titles = ();
	my @piedata = ();
	my @labels = ();
	for (my $i=0; $i<$self->{PieNotebook}->GetPageCount; $i++) {
		my $xml = $self->{ObjectDataReaders}->[$i];
		my $page = $self->{PieNotebook}->GetPage($i);
		my $title = $page->{TitleBox}->GetValue;
		my $classifier = $page->{ClassifierBox}->GetStringSelection;
	
		if ($classifier eq "") {
			$classifier = "All";
		}
		
		if ($title ne "") {
			push(@titles,$title);
		}
		elsif ($classifier ne "" and $classifier ne "All") {
			push(@titles,$classifier);
		}
		else {
			push(@titles,$self->{PieNotebook}->GetPageText($i));
		}
		
		if ($classifier eq "All") {
			if ($xml->PieAllClassifiersData()->{Total} > 0) {
				push(@piedata,$xml->PieAllClassifiersData());
			}
		}
		else {
			if ($xml->PieClassifierData($classifier)->{Total} > 0) {
				push(@piedata,$xml->PieClassifierData($classifier));
			}
		}
		
		push(@labels,$self->{PieNotebook}->GetPageText($i));
	}
	if (@piedata > 0 and @titles > 0) {
		my $pie_data = PieViewer->new(\@piedata,\@titles,\@labels,-1,-1,$control);
	}
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
}

sub TypePanel {
	my ($self,$data_reader) = @_;
	
	my $new_type_panel = Wx::Panel->new($self->{PieNotebook},-1);
	$new_type_panel->SetBackgroundColour($blue);
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $title_label = Wx::StaticBox->new($new_type_panel,-1,"Chart Title");
	my $title_label_sizer = Wx::StaticBoxSizer->new($title_label,wxHORIZONTAL);
	my $title_sizer = Wx::BoxSizer->new(wxVERTICAL);
	$new_type_panel->{TitleBox} = Wx::TextCtrl->new($new_type_panel,-1,"");
	$title_sizer->Add($new_type_panel->{TitleBox},1,wxEXPAND|wxCENTER);
	$title_label_sizer->Add($title_sizer,1,wxEXPAND);
	
	my $fill_label = Wx::StaticBox->new($new_type_panel,-1,"Choose Classifier");
	my $fill_label_sizer = Wx::StaticBoxSizer->new($fill_label,wxVERTICAL);
	$new_type_panel->{ClassifierBox} = Wx::ListBox->new($new_type_panel,-1,wxDefaultPosition(),wxDefaultSize(),[]);
	$self->FillClassifiers($new_type_panel->{ClassifierBox},$data_reader);
	$fill_label_sizer->Add($new_type_panel->{ClassifierBox},5,wxCENTER|wxEXPAND);

	$sizer->Add($title_label_sizer,1,wxEXPAND|wxTOP,10);
	$sizer->Add($fill_label_sizer,3,wxCENTER|wxEXPAND,5);
	
	$new_type_panel->SetSizer($sizer);
	$new_type_panel->Layout;
	
	return $new_type_panel;
	
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

sub GenerateCharts {
	my ($self) = @_;
	
	if ($self->{PieNotebook}->GetPageCount == 0) {
		return 0;
	}
	
	my @titles = ();
	my @piedata = ();
	my @labels = ();
	for (my $i=0; $i<$self->{PieNotebook}->GetPageCount; $i++) {
		my $page = $self->{PieNotebook}->GetPage($i);
		my $tax_data = $self->{ObjectDataReaders}->[$i];
		my $title = $page->{TitleBox}->GetValue;
		my $node_name = $page->{NodeBox}->GetStringSelection;
		my $rank = $page->{RankBox}->GetValue;
		
		if ($rank eq ""){
			$rank = "species";
		}
		if ($node_name eq "") {
			$node_name = $tax_data->{RootName};
		} 
		
		if ($title ne "") {
			push(@titles,$title);
		}
		elsif ($node_name ne "") {
			push(@titles,$node_name);
		}
		else {
			push(@titles,$self->{PieNotebook}->GetPageText($i));
		}
		
		my $input_node = $node_name;
		$input_node =~ s/^\s+//;
		
		my $results = $tax_data->PieDataNode($input_node,$rank);
		if ($results->{Total} > 0) {
			push(@piedata,$results);
		}
		
		push(@labels,$self->{PieNotebook}->GetPageText($i));
	}
	if (@piedata > 0 and @titles > 0) {
		my $pie_data = PieViewer->new(\@piedata,\@titles,\@labels,-1,-1,$control);
	}
}

sub NewPieChart {
	my ($self) = @_;
	my $names = $control->GetTaxonomyNodeNames($self->{FileBox}->GetFile());
	my $ranks = $control->GetTaxonomyNodeRanks($self->{FileBox}->GetFile());
	my $seqids = $control->GetTaxonomyNodeIds($self->{FileBox}->GetFile());
	my $values = $control->GetTaxonomyNodeValues($self->{FileBox}->GetFile());
	my $data_reader = TaxonomyData->new($self->{FileBox}->GetFile(),$names,$ranks,$seqids,$values);
	my $new_page = $self->TypePanel($data_reader);
	push(@{$self->{ObjectDataReaders}},$data_reader);
	$self->{PieNotebook}->AddPage($new_page,$self->{FileBox}->{ListBox}->GetStringSelection);
	$self->{PieNotebook}->Layout;
}

sub TypePanel {
	my ($self,$data_reader) = @_;

	my $new_type_panel = Wx::Panel->new($self->{PieNotebook},-1);
	$new_type_panel->SetBackgroundColour($blue);
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $title_label = Wx::StaticBox->new($new_type_panel,-1,"Chart Title");
	my $title_label_sizer = Wx::StaticBoxSizer->new($title_label,wxHORIZONTAL);
	my $title_sizer = Wx::BoxSizer->new(wxVERTICAL);
	$new_type_panel->{TitleBox} = Wx::TextCtrl->new($new_type_panel,-1,"");
	$title_sizer->Add($new_type_panel->{TitleBox},1,wxEXPAND|wxCENTER);
	$title_label_sizer->Add($title_sizer,1,wxEXPAND);
	
	my $level_sizer = Wx::BoxSizer->new(wxHORIZONTAL);	
	my $tax_label = Wx::StaticBox->new($new_type_panel,-1,"Select Level: ");
	my $tax_label_sizer = Wx::StaticBoxSizer->new($tax_label,wxHORIZONTAL);
	my $levels = ["kingdom","phylum","order","family","genus","species"];
	$new_type_panel->{RankBox} = Wx::ComboBox->new($new_type_panel,-1,"",wxDefaultPosition(),wxDefaultSize(),$levels,wxCB_DROPDOWN);
	$tax_label_sizer->Add($new_type_panel->{RankBox},1,wxCENTER);
	
	my $fill_label = Wx::StaticBox->new($new_type_panel,-1,"Select Node");
	my $fill_label_sizer = Wx::StaticBoxSizer->new($fill_label,wxVERTICAL);
	$new_type_panel->{NodeBox} = Wx::ListBox->new($new_type_panel,-1,wxDefaultPosition(),wxDefaultSize(),[]);
	$fill_label_sizer->Add($new_type_panel->{NodeBox},1,wxCENTER|wxEXPAND|wxTOP|wxLEFT|wxRIGHT,10);
	$self->FillNodes($new_type_panel->{NodeBox},$data_reader);


	$sizer->Add($title_label_sizer,1,wxEXPAND,10);
	$sizer->Add($fill_label_sizer,3,wxCENTER|wxEXPAND,5);
	$sizer->Add($tax_label_sizer,1,wxCENTER|wxEXPAND,5);

	
	$new_type_panel->SetSizer($sizer);
	$new_type_panel->Layout;
	return $new_type_panel;
}

sub FillNodes {
	my ($self,$listbox,$data_reader) = @_;
	
	my $nodes = $data_reader->GetNodesAlphabetically();
	my $count = 0;
	for my $node (@$nodes) {
		$listbox->Insert($node,$count);
		$count++;
	}
}

package PieMenu;
use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);

sub new {
	my ($class,$parent) = @_;

	my $self = {
		TaxPanel => undef,
		ClassPanel => undef,
		GeneratePanel => undef,
		PieNotebook => undef
	};
	$self->{Panel} = Wx::Panel->new($parent,-1);
	$self->{Panel}->SetBackgroundColour($turq);
	bless($self,$class);
	$self->Display();
	return $self;
}

sub Display {
	my ($self) = @_;

	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{PieNotebook} = Wx::Notebook->new($self->{Panel},-1);
	$self->{PieNotebook}->SetBackgroundColour($turq);
	
	$self->{TaxPanel} = TaxonomyPiePanel->new($self->{PieNotebook},"Available Taxonomies");
	$self->{ClassPanel} = ClassificationPiePanel->new($self->{PieNotebook},"Available Classifications");
	
	$self->{PieNotebook}->AddPage($self->{TaxPanel},"Taxonomy");
	$self->{PieNotebook}->AddPage($self->{ClassPanel},"Classification");
	$self->{PieNotebook}->Layout;
	
	$self->{GeneratePanel} = Wx::Panel->new($self->{Panel},-1);
	$self->{GeneratePanel}->SetBackgroundColour($turq);
	
	my $gbutton_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $gbutton_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $generate_button = Wx::Button->new($self->{GeneratePanel},-1,"Generate");
	$gbutton_sizer_v->Add($generate_button,1,wxCENTER);
	$gbutton_sizer_h->Add($gbutton_sizer_v,1,wxCENTER);
	$self->{GeneratePanel}->SetSizer($gbutton_sizer_h);
	
	$sizer->Add($self->{PieNotebook},7,wxEXPAND);
	$sizer->Add($self->{GeneratePanel},1,wxEXPAND);
	
	$self->{Panel}->SetSizer($sizer);

	$self->{Panel}->Layout;
	
	EVT_BUTTON($self->{GeneratePanel},$generate_button,sub{$self->GenerateCharts()});
}

sub GenerateCharts {
	my ($self) = @_;
	my $selection = $self->{PieNotebook}->GetSelection;
	if ($selection == 0) {
		$self->{TaxPanel}->GenerateCharts();
	}
	else {
		$self->{ClassPanel}->GenerateCharts();
	}
}

package ParserMenu;

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
	$self->SetBackgroundColour($blue);
	$self->{ParentNotebook} = $parent;

	$self->{BlastFileTextBox} = undef;
	$self->{FastaFileTextBox} = undef;
	$self->{DirectoryTextBox} = undef;
	$self->{TableCheck} = undef;
	$self->{ClassificationListBox} = undef;
	$self->{FlagListBox} = undef;
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
	$self->NewParserMenu();
	$self->Layout;
	return $self;
}

sub DirectoryChecked {
	my ($self,$checkbox,$title) = @_;
	my $checkbox_value = $checkbox->GetValue;
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
	my ($self,$text_entry,$title,$data) = @_;
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
	my $selection = $text_entry->GetCount;
	$text_entry->InsertItems([$file_label],$selection);
	$data->{$file_label} = $dialog->GetPath;
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
	$self->{ParentNotebook}->SetPageText($self->{ParentNotebook}->GetSelection,$self->{BlastFileTextBox}->GetValue);
}

sub NewParserMenu {

	my ($self) = @_;
	
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	$self->{OptionsNotebook} = Wx::Notebook->new($self,-1);
	
	$self->{OptionsNotebook}->SetBackgroundColour($blue);
	
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
	$self->SetSizer($sizer);
	
}

sub InputFilesMenu {
	my ($self) = @_;
	
	my $filespanel = Wx::Panel->new($self->{OptionsNotebook},-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$filespanel->SetBackgroundColour($blue);
	my $filessizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $parser_label = Wx::StaticBox->new($filespanel,-1,"Parser Name");
	my $parser_label_sizer = Wx::StaticBoxSizer->new($parser_label,wxHORIZONTAL);
	my $parser_text = Wx::StaticText->new($filespanel,-1,"Choose a name for this parsing job");
	$self->{ParserNameTextCtrl} = Wx::TextCtrl->new($filespanel,-1,"");
	$parser_label_sizer->Add($parser_text,1,wxCENTER);
	$parser_label_sizer->Add($self->{ParserNameTextCtrl},1,wxCENTER);
	EVT_TEXT($filespanel,$self->{ParserNameTextCtrl},sub{
		$self->{ParentNotebook}->SetPageText($self->{ParentNotebook}->GetSelection,$self->{ParserNameTextCtrl}->GetValue);
	});
	
	my $blastsizer = Wx::FlexGridSizer->new(1,2,15,15);
	$blastsizer->AddGrowableCol(0,1);
	my $blast_label = Wx::StaticBox->new($filespanel,-1,"BLAST File:");
	my $blast_label_sizer = Wx::StaticBoxSizer->new($blast_label,wxHORIZONTAL);
	$self->{BlastFileTextBox} = Wx::TextCtrl->new($filespanel,-1,'',wxDefaultPosition,wxDefaultSize);
	$self->{BlastFileTextBox}->SetEditable(0);
	my $blast_button = Wx::Button->new($filespanel,-1,'Browse');
	$blastsizer->Add($self->{BlastFileTextBox},1,wxCENTER|wxEXPAND,0);
	$blastsizer->Add($blast_button,1,wxCENTER,0);
	$blast_label_sizer->Add($blastsizer,1,wxEXPAND);
	EVT_BUTTON($filespanel,$blast_button,sub{$self->BlastButtonEvent()});
	
	my $fastasizer = Wx::FlexGridSizer->new(1,2,15,15);
	$fastasizer->AddGrowableCol(0,1);
	my $fasta_label = Wx::StaticBox->new($filespanel,-1,"FASTA File:");
	my $fasta_label_sizer = Wx::StaticBoxSizer->new($fasta_label,wxHORIZONTAL);
	$self->{FastaFileTextBox} = Wx::TextCtrl->new($filespanel,-1,'',wxDefaultPosition,wxDefaultSize);
	$self->{FastaFileTextBox}->SetEditable(0);
	my $fasta_button = Wx::Button->new($filespanel,-1,'Browse');
	$fastasizer->Add($self->{FastaFileTextBox},1,wxCENTER|wxEXPAND);
	$fastasizer->Add($fasta_button,1,wxCENTER);
	$fasta_label_sizer->Add($fastasizer,1,wxEXPAND);
	EVT_BUTTON($filespanel,$fasta_button,sub{$self->{FastaFilePath} = $self->OpenDialogSingle($self->{FastaFileTextBox},'Choose FASTA File')});
	
	my $center_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	$center_sizer->Add(Wx::BoxSizer->new(wxVERTICAL),1,wxLEFT);
	my $center_items = Wx::BoxSizer->new(wxVERTICAL);
	$center_items->Add($parser_label_sizer,1,wxCENTER|wxEXPAND);
	$center_items->Add($blast_label_sizer,1,wxCENTER|wxBOTTOM|wxEXPAND,15);
	$center_items->Add($fasta_label_sizer,1,wxCENTER|wxEXPAND);
	$center_sizer->Add($center_items,4,wxCENTER);
	$center_sizer->Add(Wx::BoxSizer->new(wxVERTICAL),1,wxRIGHT);
	$filessizer->Add($center_sizer,3,wxCENTER|wxEXPAND,0);
	$filespanel->SetSizer($filessizer);

	return $filespanel;
}

sub ClassificationMenu {
	my ($self) = @_;
	
	my $parent = $self->{ParentNotebook}->GetParent();
	while (defined $parent->GetParent) {
		$parent = $parent->GetParent;
	}
	
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
	$self->{FlagListBox} = Wx::ListBox->new($classificationpanel,-1,wxDefaultPosition,wxDefaultSize);
	$flag_list_sizer->Add($self->{FlagListBox},1,wxEXPAND);
	$flag_sizer->Add($flag_button_sizer,1,wxBOTTOM|wxCENTER,5);
	$flag_sizer->Add($flag_list_sizer,3,wxCENTER|wxEXPAND);
	EVT_BUTTON($classificationpanel,$flag_button,sub{$self->OpenDialogMultiple($self->{FlagListBox},'Find Flag File',\%{$self->{FlagLabelToPath}});});
	$flag_label_sizer->Add($flag_sizer,1,wxEXPAND);
	
	my $class_label = Wx::StaticBox->new($classificationpanel,-1,"Classification Files");
	my $class_label_sizer = Wx::StaticBoxSizer->new($class_label,wxVERTICAL);
	my $class_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $class_button_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $class_button = Wx::Button->new($classificationpanel,-1,'Browse');
	$class_button_sizer->Add($class_button,1,wxCENTER);
	my $class_list_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{ClassificationListBox} = Wx::ListBox->new($classificationpanel,-1,wxDefaultPosition,wxDefaultSize);
	$class_list_sizer->Add($self->{ClassificationListBox},1,wxEXPAND);
	$class_sizer->Add($class_button_sizer,1,wxBOTTOM|wxCENTER,5);
	$class_sizer->Add($class_list_sizer,3,wxCENTER|wxEXPAND);
	EVT_BUTTON($classificationpanel,$class_button,sub{$self->OpenDialogMultiple($self->{ClassificationListBox},'Find Classification File',\%{$self->{ClassLabelToPath}});});
	$class_label_sizer->Add($class_sizer,1,wxEXPAND);
	
	$class_flag_sizer->Add($class_label_sizer,1,wxEXPAND);
	$class_flag_sizer->Add($flag_label_sizer,1,wxEXPAND);
	
	$itemssizer->Add($class_flag_sizer,2,wxEXPAND);
	
	$classificationsizer->Add($itemssizer,1,wxEXPAND);
	
	$classificationpanel->SetSizer($classificationsizer);
	
	EVT_LISTBOX_DCLICK($classificationpanel,$self->{FlagListBox},sub{
		my $delete_dialog = OkDialog->new($parent,"Delete","Delete Flag File?");
		if ($delete_dialog->ShowModal == wxID_OK) {
			$delete_dialog->Destroy;
			delete $self->{FlagLabelToPath}{$self->{FlagListBox}->{GetStringSelection}};
			$self->{FlagListBox}->Delete($self->{FlagListBox}->GetSelection);
		}
		else {
			$delete_dialog->Destroy;
		}
	});
	EVT_LISTBOX_DCLICK($classificationpanel,$self->{ClassificationListBox},sub{
		my $delete_dialog = OkDialog->new($parent,"Delete","Delete Flag File?");
		if ($delete_dialog->ShowModal == wxID_OK) {
			$delete_dialog->Destroy;
			delete $self->{ClassLabelToPath}{$self->{ClassificationListBox}->{GetStringSelection}};
			$self->{ClassificationListBox}->Delete($self->{ClassificationListBox}->GetSelection);
		}
		else {
			$delete_dialog->Destroy;
		}
	});
	return $classificationpanel;
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
	$source_label_sizer->Add($self->{SourceCombo},1,wxCENTER);
	$source_sizer->Add($source_label_sizer,3,wxCENTER);
	
	my $rank_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $rank_label = Wx::StaticBox->new($tax_panel,-1,"Ranks: ");
	my $rank_label_sizer = Wx::StaticBoxSizer->new($rank_label,wxHORIZONTAL);
	my $rank_list = Wx::ListBox->new($tax_panel,-1,wxDefaultPosition,wxDefaultSize,["superkingdom","kingdom","phylum","class","subclass","infraclass","superorder","order",
	"infraorder","suborder","superfamily","family","subfamily","tribe","subtribe","genus","subgenus","species","species group","species subgroup"]);
	my $rank_button_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $rank_button = Wx::Button->new($tax_panel,-1,'Add');
	$rank_button_sizer->Add($rank_button,1,wxCENTER);
	$self->{RankList} = Wx::ListBox->new($tax_panel,-1);

	$rank_label_sizer->Add($rank_list,1,wxEXPAND);
	$rank_label_sizer->Add($rank_button_sizer,1,wxCENTER);
	$rank_label_sizer->Add($self->{RankList},1,wxEXPAND);
	$rank_sizer->Add($rank_label_sizer,1,wxCENTER);
	
	EVT_BUTTON($self,$rank_button,sub{$self->{RankList}->Insert($rank_list->GetStringSelection,0)});
	
	my $root_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $root_label = Wx::StaticBox->new($tax_panel,-1,"Roots: ");
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
	
	EVT_BUTTON($tax_panel,$clear_button,sub{$self->{RootList}->Clear;$self->{RankList}->Clear;$self->{SourceCombo}->SetValue("");});

	$sizer->Add($source_sizer,1,wxEXPAND);
	$sizer->Add($rank_sizer,2,wxEXPAND);
	$sizer->Add($root_sizer,2,wxEXPAND);
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
	my $text_check = Wx::CheckBox->new($add_panel,-1,"");
	my $text_sizer = Wx::FlexGridSizer->new(1,3,20,20);
	$text_sizer->AddGrowableCol(2,1);
	$text_sizer->Add($text_check,1,wxCENTER);
	$text_sizer->Add($directory_title,1,wxCENTER);
	$text_sizer->Add($self->{DirectoryTextBox},1,wxCENTER|wxEXPAND);
	$text_label_sizer->Add($text_sizer,1,wxEXPAND);
	
	my $table_label = Wx::StaticBox->new($add_panel,-1,"Database Table?");
	my $table_label_sizer = Wx::StaticBoxSizer->new($table_label,wxHORIZONTAL);
	my $check_sizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{TableCheck} = Wx::CheckBox->new($add_panel,-1,"Yes/No");
	$check_sizer->Add($self->{TableCheck},1,wxCENTER);
	$table_label_sizer->Add($check_sizer,1,wxEXPAND);
	
	EVT_CHECKBOX($add_panel,$text_check,sub{$self->DirectoryChecked($text_check,"Choose Directory")});
	
	$add_sizer_v->Add($text_label_sizer,1,wxCENTER|wxEXPAND|wxLEFT|wxRIGHT,50);
	$add_sizer_v->Add($table_label_sizer,1,wxCENTER|wxEXPAND|wxLEFT|wxRIGHT,50);
	$add_sizer_h->Add($add_sizer_v,1,wxCENTER);
	
	$add_panel->SetSizer($add_sizer_h);
	
	return $add_panel;
}

package TableMenu;

use Wx qw /:everything/;
use Wx::Event qw(EVT_LIST_ITEM_SELECTED);
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED);
use Wx::Event qw(EVT_LISTBOX);
use Wx::Event qw(EVT_LIST_COL_CLICK);
use base 'Wx::Panel';

sub new {
	my ($class,$parent) = @_;
	
	my $self = $class->SUPER::new($parent,-1);
	$self->SetBackgroundColour($turq);
	$self->{ResultListBox} = undef;
	$self->{ResultHitListCtrl} = undef;
	$self->{ResultQueryListCtrl} = undef;
	$self->{QueryColumnHash} = ();
	bless ($self,$class);
	$self->MainDisplay();
	$self->Layout;
	return $self;
}

sub MainDisplay {
	my ($self) = @_;
	$self->SetBackgroundColour($turq);
	
	my $sizer = Wx::BoxSizer->new(wxHORIZONTAL);
		
	my $splitter = Wx::SplitterWindow->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSP_3D);

	$self->{LeftPanel} = Wx::Panel->new($splitter,-1);
	$self->{LeftPanel}->SetBackgroundColour($turq);
	my $leftsizer = Wx::BoxSizer->new(wxVERTICAL);
	my $qtextsizer = Wx::BoxSizer->new(wxVERTICAL);
	my $queuetext = Wx::StaticText->new($self->{LeftPanel},-1,"Choose Result");
	$qtextsizer->Add($queuetext,1,wxCENTER);
	
	my $listsizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{ResultListBox} = FileBox->new($self->{LeftPanel});
	$listsizer->Add($self->{ResultListBox}->{ListBox},1,wxEXPAND);
	$self->FillResultMenu();
	
	$leftsizer->Add($qtextsizer,1,wxCENTER,wxEXPAND);
	$leftsizer->Add($listsizer,15,wxEXPAND);
	
	$self->{LeftPanel}->SetSizer($leftsizer);
	$self->{LeftPanel}->Layout;

	$self->{RightPanel} = Wx::Panel->new($splitter,-1);
	$self->{RightPanel}->SetBackgroundColour($turq);
	my $view_sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	$self->{ResultHitListCtrl} = Wx::ListCtrl->new($self->{RightPanel},-1,wxDefaultPosition,wxDefaultSize,wxLC_REPORT);
	$self->{ResultHitListCtrl}->InsertColumn(0,"Hit Name");
	$self->{ResultHitListCtrl}->InsertColumn(1,"Count");
	$self->{ResultHitListCtrl}->InsertColumn(2,"Hit Description");
	
	$self->{ResultQueryListCtrl} = Wx::ListCtrl->new($self->{RightPanel},-1,wxDefaultPosition,wxDefaultSize,wxLC_REPORT);
	$self->{ResultQueryListCtrl}->InsertColumn(0,"Query");
	$self->{ResultQueryListCtrl}->InsertColumn(1,"Rank");
	$self->{ResultQueryListCtrl}->InsertColumn(2,"Query Length");
	$self->{QueryColumnHash}{2} = "qlength"; 
	$self->{ResultQueryListCtrl}->InsertColumn(3,"Percent Id");
	$self->{ResultQueryListCtrl}->InsertColumn(4,"Bit Score");
	$self->{ResultQueryListCtrl}->InsertColumn(5,"E-Value");
	$self->{ResultQueryListCtrl}->InsertColumn(6,"Hit Start");
	$self->{ResultQueryListCtrl}->InsertColumn(7,"Hit End");
	$self->{ResultQueryListCtrl}->InsertColumn(8,"Query Start");
	$self->{ResultQueryListCtrl}->InsertColumn(9,"Query End");
	
	$view_sizer->Add($self->{ResultHitListCtrl},1,wxEXPAND);
	$view_sizer->Add($self->{ResultQueryListCtrl},1,wxEXPAND);
	$self->{RightPanel}->SetSizer($view_sizer);
	$self->{RightPanel}->Layout;
	
	my $parent = $self->GetParent();
	while (defined $parent->GetParent) {
		$parent = $parent->GetParent;
	}
	
	my $splitsize = ($parent->GetSize()->width)/4;
	$splitter->SplitVertically($self->{LeftPanel},$self->{RightPanel},$splitsize);

	$sizer->Add($splitter,1,wxEXPAND);
	$self->SetSizer($sizer);
	$self->Layout;
}

sub FillResultMenu {
	my ($self) = @_;
	chdir($control->{CurrentDirectory});
	dbmopen(my %TABLENAMES,"TABLENAMES.db",0644) or die "Cannot open ParserNames: $!";
	while ( my ($key, $value) = each(%TABLENAMES) ) {
		$self->{ResultListBox}->AddFile($key,$value);
	}
	EVT_LISTBOX($self->{LeftPanel},$self->{ResultListBox}->{ListBox},sub{$self->DisplayHits($self->{ResultListBox}->GetFile)});
}

my %hmap = ();
my $hcol = 0;
my %hcolstate = (0=>-1,1=>-1,2=>-1);

sub DisplayHits {
	my ($self,$table_name) = @_;
	$self->{CurrentTableName} = $table_name;
	$self->{ResultHitListCtrl}->DeleteAllItems;
	my $hits = $control->{Connection}->selectall_arrayref("SELECT DISTINCT hitname FROM " . $self->{CurrentTableName} . "_HitInfo");
	for (my $i=0; $i<@$hits; $i++) {
		my $hitname = $hits->[$i]->[0];
		my $item = $self->{ResultHitListCtrl}->InsertStringItem($i,"");
		$self->{ResultHitListCtrl}->SetItemData($item,$i);
		my $count = $control->{Connection}->selectrow_arrayref("SELECT COUNT(hitname) FROM " . $self->{CurrentTableName} . "_AllHits WHERE hitname=?",undef,$hitname);
		$self->{ResultHitListCtrl}->SetItem($i,0,$hitname);
		$hmap{0}{$i} = $hitname;
		$self->{ResultHitListCtrl}->SetItem($i,1,$count->[0]);
		$hmap{1}{$i} = $count->[0];
		my $descr = $control->{Connection}->selectrow_arrayref("SELECT description FROM " . $self->{CurrentTableName} . "_HitInfo WHERE hitname=?",undef,$hitname);
		$self->{ResultHitListCtrl}->SetItem($i,2,$descr->[0]);
		$hmap{2}{$i} = $descr->[0];
	}
	$self->{ResultHitListCtrl}->SetColumnWidth(2,-1);
	EVT_LIST_ITEM_ACTIVATED($self,$self->{ResultHitListCtrl},\&Save);
	EVT_LIST_ITEM_SELECTED($self,$self->{ResultHitListCtrl},\&DisplayQueries);
	EVT_LIST_COL_CLICK($self,$self->{ResultHitListCtrl},\&OnSortHit);
} 

my %qmap = ();
my $qcol = 0;
my %qcolstate = (0=>-1,1=>-1,2=>-1,3=>-1,4=>-1,5=>-1,6=>-1,7=>-1,8=>-1,9=>-1);

sub DisplayQueries {
	my ($self,$event) = @_;
	$self->{ResultQueryListCtrl}->DeleteAllItems;
	my $hitname = $event->GetText;
	my $queries = $control->{Connection}->selectall_arrayref("SELECT * FROM " . $self->{CurrentTableName} . "_AllHits WHERE hitname=?",undef,$hitname);
	for (my $i=0; $i<@$queries; $i++) {
		my $query_row = $queries->[$i];
		my $item = $self->{ResultQueryListCtrl}->InsertStringItem($i,"Hello");
		$self->{ResultQueryListCtrl}->SetItemData($item,$i);
		$self->{ResultQueryListCtrl}->SetItem($i,0,$query_row->[0]);
		$qmap{0}{$i} = $query_row->[0];
		$self->{ResultQueryListCtrl}->SetItem($i,1,$query_row->[1]);
		$qmap{1}{$i} = $query_row->[1];
		my $qlength = $control->{Connection}->selectrow_arrayref("SELECT qlength FROM " . $self->{CurrentTableName} . "_QueryInfo WHERE query=?",undef,$query_row->[0]);
		$self->{ResultQueryListCtrl}->SetItem($i,2,$qlength->[0]);
		$qmap{2}{$i} = $qlength->[0];
		my $hit_row = $control->{Connection}->selectrow_arrayref("SELECT * FROM " . $self->{CurrentTableName} . "_AllHits
		WHERE query=? AND rank=?",undef,$query_row->[0],$query_row->[1]);
		$self->{ResultQueryListCtrl}->SetItem($i,3,$hit_row->[3]);
		$qmap{3}{$i} = $hit_row->[3];
		$self->{ResultQueryListCtrl}->SetItem($i,4,$hit_row->[4]);
		$qmap{4}{$i} = $hit_row->[4];
		$self->{ResultQueryListCtrl}->SetItem($i,5,$hit_row->[5]);
		$qmap{5}{$i} = $hit_row->[5];
		$self->{ResultQueryListCtrl}->SetItem($i,6,$hit_row->[6]);
		$qmap{6}{$i} = $hit_row->[6];
		$self->{ResultQueryListCtrl}->SetItem($i,7,$hit_row->[7]);
		$qmap{7}{$i} = $hit_row->[7];
		$self->{ResultQueryListCtrl}->SetItem($i,8,$hit_row->[8]);
		$qmap{8}{$i} = $hit_row->[8];
		$self->{ResultQueryListCtrl}->SetItem($i,9,$hit_row->[9]);
		$qmap{9}{$i} = $hit_row->[9];
	}
	EVT_LIST_COL_CLICK($self,$self->{ResultQueryListCtrl},\&OnSortQuery);
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
		my $queries = $control->{Connection}->selectall_arrayref("SELECT query FROM " . $self->{CurrentTableName} . "_AllHits
		WHERE hitname=?",undef,$hitname);
		open(FASTA, '>>' . $dialog->GetPath . ".fasta");
		for my $query(@$queries) {
			my $sequence = $control->{Connection}->selectrow_arrayref("SELECT sequence FROM " . $self->{CurrentTableName} . "_QueryInfo
			WHERE query=?",undef,$query->[0]);
			print FASTA ">" . $query->[0] . "\n";
		  	print FASTA $sequence->[0] . "\n";
		  	print FASTA "\n";
		}
	  	close FASTA;
	}
	$dialog->Destroy;
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
	$self->{Parsers} = ();
	
	bless ($self,$class);
	$self->SetPanels();
	return $self;
}

sub SetPanels {
	my ($self) = @_;
	
	$self->{Sizer} = Wx::BoxSizer->new(wxVERTICAL);
	$self->SetBackgroundColour($turq);
	
	$self->{Sizer}->Add($self,1,wxGROW);
	$self->SetSizer($self->{Sizer});
	
	my $sizer = Wx::BoxSizer->new(wxHORIZONTAL);
		
	my $splitter = Wx::SplitterWindow->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSP_3D);

	$self->{LeftPanel} = Wx::Panel->new($splitter,-1);
	$self->{LeftPanel}->SetBackgroundColour($turq);
	my $leftsizer = Wx::BoxSizer->new(wxVERTICAL);
	my $qtextsizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $qtextsizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $queuetext = Wx::StaticText->new($self->{LeftPanel},-1,"Queue");
	$qtextsizer_h->Add($queuetext,1,wxCENTER);
	$qtextsizer_v->Add($qtextsizer_h,1,wxCENTER);
	
	my $listsizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{QueueList} = Wx::ListBox->new($self->{LeftPanel},-1,wxDefaultPosition(),wxDefaultSize());
	$listsizer->Add($self->{QueueList},1,wxEXPAND);
	
	my $button_sizer_h = Wx::BoxSizer->new(wxVERTICAL);
	my $button_sizer_v = Wx::BoxSizer->new(wxHORIZONTAL);
	my $run_button = Wx::Button->new($self->{LeftPanel},1,"Run");
	$button_sizer_h->Add($run_button,1,wxCENTER);
	$button_sizer_v->Add($button_sizer_h,1,wxCENTER);
	EVT_BUTTON($self->{LeftPanel},$run_button,sub{$self->Run()});
	
	$leftsizer->Add($qtextsizer_v,1,wxCENTER|wxEXPAND);
	$leftsizer->Add($listsizer,7,wxEXPAND);
	$leftsizer->Add($button_sizer_v,1,wxCENTER);
	
	$self->{LeftPanel}->SetSizer($leftsizer);
	$self->{LeftPanel}->Layout;
	
	my $parent = $self->GetParent();
	while (defined $parent->GetParent) {
		$parent = $parent->GetParent;
	}
	
	EVT_LISTBOX($self->{LeftPanel},$self->{QueueList},sub{$self->DisplayParserMenu($self->{QueueList}->GetSelection)});
	EVT_LISTBOX_DCLICK($self->{LeftPanel},$self->{QueueList},sub{
		my $delete_dialog = OkDialog->new($parent,"Delete","Delete Parser?");
		if ($delete_dialog->ShowModal == wxID_OK) {
			$delete_dialog->Destroy;
			$self->DeleteParser();
		}
		else {
			$delete_dialog->Destroy;
		}
		});
	
	$self->{ParserNotebook} = undef;
	$self->{RightPanel} = Wx::Panel->new($splitter,-1);
	$self->{RightPanel}->SetBackgroundColour($turq);
	my $menusizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{ParserNotebook} = Wx::Notebook->new($self->{RightPanel},-1);
	$self->{ParserNotebook}->SetBackgroundColour($turq);
	my $new_page = ParserMenu->new($self->{ParserNotebook});
	$self->{ParserNotebook}->AddPage($new_page,"New Parser");
	$self->{RightPanel}->Layout;
	
	my $button_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $button_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $queue_button = Wx::Button->new($self->{RightPanel},-1,'Queue');
	my $new_button = Wx::Button->new($self->{RightPanel},-1,'New');
	$button_sizer_h->Add($queue_button,1,wxCENTER);
	$button_sizer_h->Add($new_button,1,wxCENTER);
	$button_sizer_v->Add($button_sizer_h,1,wxCENTER);
	
	EVT_BUTTON($self->{RightPanel},$queue_button,sub{$self->NewProcessForQueue()});
	EVT_BUTTON($self->{RightPanel},$new_button,sub{$self->NewPage()});
	
	$self->{ParserNotebook}->Layout;
	$menusizer->Add($self->{ParserNotebook},8,wxEXPAND);
	$menusizer->Add($button_sizer_v,1,wxEXPAND);
	$self->{RightPanel}->SetSizer($menusizer);
	
	my $splitsize = ($self->{Parent}->GetSize()->width)/4;
	$splitter->SplitVertically($self->{LeftPanel},$self->{RightPanel},$splitsize);

	$sizer->Add($splitter,1,wxEXPAND);
	$self->SetSizer($sizer);
	$self->Layout;
}

sub DisplayParserMenu {
	my ($self,$queue_selection) = @_;
	my $selection = $self->{QueueList}->GetSelection;
	$self->{ParserNotebook}->SetSelection($selection);
}

sub DeleteParser {
	my ($self) = @_;
	my $selection = $self->{QueueList}->GetSelection;
	$self->{QueueList}->Delete($selection);
	$self->{ParserNotebook}->RemovePage($selection);
	$self->{ParserNotebook}->Refresh;
	if ($self->{ParserNotebook}->GetPageCount == 0) {
		my $new_page = ParserMenu->new($self->{ParserNotebook});
		$self->{ParserNotebook}->AddPage($new_page,"");
	}
	$self->Refresh;
}

sub NewProcessForQueue {
	my ($self) = @_;
	
	my $page = $self->{ParserNotebook}->GetPage($self->{ParserNotebook}->GetSelection);
	
	if ($page->CheckProcess() == 0) {
		$self->{Parent}->SetStatusText("Please Choose a Name for the Parsing Job");
		return 0;	
	}
	elsif ($page->CheckProcess() == -1) {
		$self->{Parent}->SetStatusText("Please Choose a BLAST Output File");
		return 0;	
	}
	elsif ($page->CheckProcess() == -2) {
		$self->{Parent}->SetStatusText("Please Choose a FASTA File");
		return 0;	
	}
	elsif ($page->CheckProcess() == -3) {
		$self->{Parent}->SetStatusText("Please Choose a Data Output Type");
		return 0;
	}
	elsif ($page->CheckProcess() == 1) {
		$self->AddProcessQueue();
	}
	else {
		return 0;
	}
}

sub NewPage {
	my ($self) = @_;
	my $new_page = ParserMenu->new($self->{ParserNotebook});
	my $NumSelections = $self->{ParserNotebook}->GetPageCount;
	$self->{ParserNotebook}->AddPage($new_page,"");
	$self->{ParserNotebook}->SetSelection($NumSelections);
}

sub AddProcessQueue {
	my ($self) = @_;
	my $count = $self->{QueueList}->GetCount;
	my $label = $self->{ParserNotebook}->GetPageText($self->{ParserNotebook}->GetSelection);
	$self->{QueueList}->InsertItems([$label],$count);
}

sub GenerateParsers {
	my ($self) = @_;
	my $count = $self->{QueueList}->GetCount;
	for (my $i=0; $i<$count; $i++) {
		my $page = $self->{ParserNotebook}->GetPage($i);
		my $label = $page->{ParserNameTextCtrl}->GetValue;
		$self->GenerateParser($label,$page);
	}
}

## This routine needs some work.
sub GenerateParser {
	my ($self,$label,$page) = @_;
	
	my $key = $control->AddParserName($label);
	my $dir = $control->CreateResultFolder($key);
	my $parser = BlastParser->new($key,$dir);
	
	$parser->SetBlastFile($page->{BlastFilePath});
	$parser->SetFastaFile($page->{FastaFilePath});
	
	$parser->SetParameters($page->{BitTextBox}->GetValue,$page->{EValueTextBox}->GetValue);
	
	my @classes = ();
	my @flags = ();
	for my $class_label (keys(%{$page->{ClassLabelToPath}})) {
		my $class = Classification->new($page->{ClassLabelToPath}->{$class_label},$control);
		push(@classes,$class);
	}
	for my $flag_label (keys(%{$page->{FlagLabelToPath}})) {
		my $flag = FlagItems->new($page->{OutputDirectoryPath},$page->{FlagLabelToPath}{$flag_label},$control);
		push(@flags,$flag);
	}
	
	my $taxonomy;
	if ($page->{SourceCombo}->GetValue ne "") {
		my @ranks = $page->{RankList}->GetStrings;
		my @roots = $page->{RootList}->GetStrings;
		if ($page->{SourceCombo}->GetValue eq "Connection") {
			$taxonomy = ConnectionTaxonomy->new(\@ranks,\@roots,$control);
		}
		else {
			$taxonomy = FlatFileTaxonomy->new($control->{NodesFile},$control->{NamesFile},\@ranks,\@roots,$control);
		}
	}
	
	if ($page->{TableCheck}->GetValue==1) {
		my $table = SendTable->new($key,$control);
		$control->AddTableName($label,$key);
		$parser->AddProcess($table);
	}
	if ($page->{OutputDirectoryPath} ne "") {
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
	
	for my $parser(@{$self->{Parsers}}) {
		my $progress_dialog = Wx::ProgressDialog->new("","Parsing File ...",100);
		$progress_dialog->SetBackgroundColour($blue);
		$parser->Parse($progress_dialog);
		$progress_dialog->Destroy;
	}
	
	$self->{Parent}->SetStatusText("Done Processing");
}

sub Run {
	my ($self) = @_;
	my $count = $self->{QueueList}->GetCount;
	if ($count > 0) {
		my $count_string = "process";
		if ($count > 1) {
			$count_string = "processes";
		}
		my $run_dialog = OkDialog->new($self->{Parent},"Run Parsers","$count " . $count_string . " to run. Continue?");
		if ($run_dialog->ShowModal == wxID_OK) {
			$run_dialog->Destroy;
			$self->GenerateParsers();
			$self->RunParsers();
		}
		else {
			$run_dialog->Destroy;
		}
	}
	else {
		$self->{Parent}->SetStatusText("No Files to Parse");
	}
}

package Display;
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
	$self->{Panel} = Wx::Panel->new($self,-1);
	$self->{Panel}->SetBackgroundColour($turq);
	$self->{QueuePanel} = undef;
	$self->{PiePanel} = undef;
	$self->{TablePanel} = undef;
	$self->{TreePanel} = undef;
	
	$self->{Sizer}->Add($self->{Panel},1,wxGROW);
	$self->SetSizer($self->{Sizer});

	$self->Centre();
	$self->OnProcessClicked(0);
	return $self;
}

sub OnProcessClicked {
	my ($self,$event) = @_;
	$self->{Panel}->Hide;
	if (defined $self->{TablePanel}) {
		$self->{TablePanel}->Hide;
	}
	if (defined $self->{PiePanel}) {
		$self->{PiePanel}->Hide;
	}
	if (defined $self->{TreePanel}) {
		$self->{TreePanel}->Hide;
	}
	$self->Refresh;
	if (defined $self->{QueuePanel}) {
		$self->{QueuePanel}->Show;
	}
	else {
		$self->{QueuePanel} = QueuePanel->new($self);
	}
	$self->{Sizer}->Clear;
	$self->{Sizer}->Add($self->{QueuePanel},1,wxEXPAND);
	$self->Layout;
}

sub InitializePieMenu {
	my($self,$event) = @_;
	$self->{Panel}->Hide;
	if (defined $self->{TablePanel}) {
		$self->{TablePanel}->Hide;
	}
	if (defined $self->{QueuePanel}) {
		$self->{QueuePanel}->Hide;
	}
	if (defined $self->{TreePanel}) {
		$self->{TreePanel}->Hide;
	}
	$self->Refresh;
	if (defined $self->{PiePanel}) {
		$self->{PiePanel}->Show;
	}
	else {
		my $piemenu = PieMenu->new($self);
		$self->{PiePanel} = $piemenu->{Panel};
	}
	$self->{Sizer}->Clear;
	$self->{Sizer}->Add($self->{PiePanel},1,wxEXPAND);
	$self->Layout;
}

sub InitializeTreeMenu {
	my($self,$event) = @_;
	$self->{Panel}->Hide;
	if (defined $self->{TablePanel}) {
		$self->{TablePanel}->Hide;
	}
	if (defined $self->{QueuePanel}) {
		$self->{QueuePanel}->Hide;
	}
	if (defined $self->{PiePanel}) {
		$self->{PiePanel}->Hide;
	}
	$self->Refresh;
	if (defined $self->{TreePanel}) {
		$self->{TreePanel}->Show;
	}
	else {
		$self->{TreePanel} = TreeMenu->new($self);
	}
	$self->{Sizer}->Clear;
	$self->{Sizer}->Add($self->{TreePanel},1,wxEXPAND);
	$self->Layout;
}

sub InitializeTableViewer {
	my($self,$event) = @_;
	$self->{Panel}->Hide;
	if (defined $self->{QueuePanel}) {
		$self->{QueuePanel}->Hide;
	}
	if (defined $self->{PiePanel}) {
		$self->{PiePanel}->Hide;
	}
	if (defined $self->{TreePanel}) {
		$self->{TreePanel}->Hide;
	}
	$self->Refresh;
	if (defined $self->{TablePanel}) {
		$self->{TablePanel}->Show;
	}
	else {
		$self->{TablePanel} = TableMenu->new($self);
	}
	$self->{Sizer}->Clear;
	$self->{Sizer}->Add($self->{TablePanel},1,wxEXPAND);
	$self->Layout;
}

sub TopMenu {
	my ($self) = @_;
	
	$self->{FileMenu} = Wx::Menu->new();
	my $newblast = $self->{FileMenu}->Append(101,"New Parser");
	$self->{FileMenu}->AppendSeparator();
	my $close = $self->{FileMenu}->Append(102,"Quit");
	EVT_MENU($self,101,\&OnProcessClicked);
	EVT_MENU($self,102,sub{$self->Close(1)});

	my $viewmenu = Wx::Menu->new();
	my $table = $viewmenu->Append(201,"Table");
	my $pie = $viewmenu->Append(202,"Pie Charts");
	my $tax = $viewmenu->Append(203,"Tree");
	EVT_MENU($self,201,\&InitializeTableViewer);
	EVT_MENU($self,202,\&InitializePieMenu);
	EVT_MENU($self,203,\&InitializeTreeMenu);

	my $menubar = Wx::MenuBar->new();
	$menubar->Append($self->{FileMenu},"File");
	$menubar->Append($viewmenu,"View");
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
	my $display = Display->new();
	$display->TopMenu();
	$display->Show();
	return 1;
}

package main;
my $app = Application->new;
$app->MainLoop;
