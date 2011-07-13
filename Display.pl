#!/usr/bin/perl
use strict;
use Wx;
use Parser;
use PieViewer;
use IO::File;
use Cwd;

# Global colors
my $turq = Wx::Colour->new("TURQUOISE");
my $blue = Wx::Colour->new(130,195,250);
my $brown = Wx::Colour->new(244,164,96);

package ProgramControl;
use Cwd;

sub new {
	my $class = shift;
	my $self = {
		CurrentDirectory => getcwd,
		PathSeparator => undef
	};
	bless ($self,$class);
	$self->GetPathSeparator();
	$self->MakeResultsFolder();
	$self->MakeColorPrefsFolder();
	$self->SetTaxDump();
	return $self;
}

sub MakeResultsFolder {
	my $self = shift;
	$self->{Results} = $self->{CurrentDirectory} . $self->{PathSeparator} . "Results";
	mkdir $self->{Results};
}

sub MakeColorPrefsFolder {
	my $self = shift;
	$self->{ColorPrefs} = $self->{CurrentDirectory} . $self->{PathSeparator} . "ColorPrefs";
	mkdir $self->{ColorPrefs};
}

sub SetTaxDump {
	my ($self) = @_;
	$self->{TaxDump} = $self->{CurrentDirectory} . $self->{PathSeparator} . "taxdump";
	$self->{NodesFile} = $self->{TaxDump} . $self->{PathSeparator} . "nodes.dmp";
	$self->{NamesFile} = $self->{TaxDump} . $self->{PathSeparator} . "names.dmp";
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

my $control = ProgramControl->new();

package OkDialog;
use base 'Wx::Frame';
use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);

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
	my $self = $class->SUPER::new($parent,-1,$title,[$tx,$ty],[$twidth,$theight],);
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
	$self->{Ok} = Wx::Button->new($self->{Panel},-1,"Ok");
	$self->{Cancel} = Wx::Button->new($self->{Panel},-1,"Cancel");
	$button_sizer->Add($self->{Ok},1,wxCENTER|wxRIGHT,10);
	$button_sizer->Add($self->{Cancel},1,wxCENTER|wxLEFT,10);
	
	$sizer->Add($text_sizer,1,wxCENTER);
	$sizer->Add($button_sizer,2,wxCENTER);
	$self->{Panel}->SetSizer($sizer);
	$self->Show;
}

package FunctionDialog;
use Wx::Event qw(EVT_BUTTON);
use base ("OkDialog");

sub new {
	my ($class,$parent,$title,$dialog,$function,$parameters) = @_;
	my $self = $class->SUPER::new($parent,$title,$dialog);
	bless ($self,$class);
	$self->ConnectEvents($function,$parameters);
	return $self;
}

sub ConnectEvents {
	my ($self,$function,$parameters) = @_;
	EVT_BUTTON($self->{Panel},$self->{Ok},sub{$self->OkPressed($function,$parameters)});
	EVT_BUTTON($self->{Panel},$self->{Cancel},sub{$self->Close(1)});
}

sub OkPressed {
	my ($self,$function,$parameters) = @_;
	my $object = shift(@$parameters);
	if ($object == 0) {
		$function->($parameters);
	}
	else {
		$function->($object,$parameters);
	}
	$self->Close(1);
}

package DoubleDialog;
use Wx::Event qw(EVT_BUTTON);
use base ("OkDialog");

sub new {
	my ($class,$parent,$title_1,$dialog_1,,$title_2,$dialog_2,$function,$parameters) = @_;
	my $self = $class->SUPER::new($parent,$title_1,$dialog_1);
	bless ($self,$class);
	$self->ConnectEvents($parent,$title_2,$dialog_2,$function,$parameters);
	return $self;
}

sub ConnectEvents {
	my ($self,$parent,$title_2,$dialog_2,$function,$parameters) = @_;
	EVT_BUTTON($self->{Panel},$self->{Ok},sub{$self->OkPressed($parent,$title_2,$dialog_2,$function,$parameters)});
	EVT_BUTTON($self->{Panel},$self->{Cancel},sub{$self->Close(1)});
}

sub OkPressed {
	my ($self,$parent,$title_2,$dialog_2,$function,$parameters) = @_;
	FunctionDialog->new($parent,$title_2,$dialog_2,$function,$parameters);
	$self->Close(1);
}

package DeleteDialog;
use Wx::Event qw(EVT_BUTTON);
use base ("OkDialog");

# array is optional.
sub new {
	my ($class,$parent,$title,$dialog,$textbox,$array) = @_;
	my $self = $class->SUPER::new($parent,$title,$dialog);
	bless ($self,$class);
	$self->ConnectEvents($textbox,$array);
	return $self;
}

sub ConnectEvents {
	my ($self,$textbox,$array) = @_;
	EVT_BUTTON($self->{Panel},$self->{Ok},sub{$self->OkPressed($textbox,$array)});
	EVT_BUTTON($self->{Panel},$self->{Cancel},sub{$self->Close(1)});
}

sub OkPressed {
	my ($self,$textbox,$array) = @_;
	if (defined $array) {
		splice(@$array,$textbox->GetSelection,1);
	}
	$textbox->Delete($textbox->GetSelection);
	$self->Close(1);
}

package TaxonomyPiePanel;

use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
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
	$self->{ParentNotebook} = $parent;
	$self->{TypePanel} = undef;
	$self->{Sizer} = undef; 
	$self->{TypeSizer} = undef;
	$self->{ChartData} = (); #Title, Level, NodeSelection, IsFill
	$self->{FileHash} = ();
	
	bless ($self,$class);
	$self->MainDisplay();
	$self->Layout;
	return $self;
}

sub InitializeChartData {
	my ($self,$file) = @_;
	my $data_hash = {"FileString"=>$file, "Title"=>"","Rank"=>"","","Root"=>0,"NodeSelection"=>-1,"NodeString"=>"","IsFill"=>0};
	push(@{$self->{ChartData}},$data_hash);
}

sub AddTaxonomy {
	my ($self,$tax_string) = @_;
	my $file = $self->{FileHash}{$tax_string};
	$self->InitializeChartData($file);
	my $count = $self->{TaxonomyBox}->GetCount;
	$self->{TaxonomyBox}->Insert($tax_string,$count);
}

sub MainDisplay {

	my ($self) = @_;

	$self->{Sizer} = Wx::BoxSizer->new(wxVERTICAL);
	my $center_display = Wx::BoxSizer->new(wxHORIZONTAL);

	my $file_panel = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$file_panel->SetBackgroundColour($blue);
	my $file_sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $file_button_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $file_button_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $file_button = Wx::Button->new($file_panel,-1,"Add");
	$file_button_sizer_h->Add($file_button,1,wxCENTER);
	$file_button_sizer_v->Add($file_button_sizer_h,1,wxCENTER);
	$self->{TaxonomyBox} = Wx::ListBox->new($file_panel,-1);
	
	$file_sizer->Add($file_button_sizer_v,1,wxCENTER,100);
	$file_sizer->Add($self->{TaxonomyBox},5,wxCENTER|wxEXPAND|wxBOTTOM|wxLEFT|wxRIGHT,20);
	$file_panel->Layout;
	$file_panel->SetSizer($file_sizer);
	
	$self->{TypePanel} = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$self->{TypePanel}->SetBackgroundColour($blue);
	$self->{TypeSizer} = Wx::BoxSizer->new(wxVERTICAL);
	
	$center_display->Add($file_panel,1,wxLEFT|wxCENTER|wxEXPAND|wxRIGHT,10);
	$center_display->Add($self->{TypePanel},1,wxRIGHT|wxCENTER|wxEXPAND,10);
	
	$self->{Sizer}->Add($center_display,1,wxCENTER|wxEXPAND);

	$self->SetSizer($self->{Sizer});
	$self->Layout;
	
	my $parent = $self->{ParentNotebook}->GetParent();
	while (defined $parent->GetParent) {
		$parent = $parent->GetParent;
	}
	
	EVT_LISTBOX($self,$self->{TaxonomyBox},sub{$self->TypePanel()});
	EVT_BUTTON($self,$file_button,sub{$self->TaxonomyBox()});
	EVT_LISTBOX_DCLICK($self,$self->{TaxonomyBox},sub{DeleteDialog->new($parent,"Delete","Remove Taxonomy Pie Chart?",$self->{TaxonomyBox},$self->{ChartData});
	});
}

sub GenerateCharts {
	my ($self) = @_;
	
	if ($self->{TaxonomyBox}->GetCount == 0) {
		return 0;
	}
	
	my @titles = ();
	my @piedata = ();
	my @labels = ();
	for (my $i=0; $i<@{$self->{ChartData}}; $i++) {
		my $data_item = $self->{ChartData}->[$i];
		my $xml = TaxonomyXML->new($data_item->{FileString});
		
		if ($data_item->{Rank} eq "" and $data_item->{NodeString} eq "") {
			next;
		}
		elsif ($data_item->{NodeString} eq "") {
			$data_item->{NodeString} = $xml->{TaxonomyHash}->{"name"};
		} else {}
		
		if ($data_item->{Title} ne "") {
			push(@titles,$data_item->{Title});
		}
		elsif ($data_item->{NodeString} ne "") {
			push(@titles,$data_item->{NodeString});
		}
		else {
			push(@titles,$self->{TaxonomyBox}->GetString($i));
		}
		
		my $input_node = $data_item->{NodeString};
		$input_node =~ s/^\s+//;
		
		if ($xml->PieDataNode($input_node,$data_item->{Rank})->{Total} > 0) {
			push(@piedata,$xml->PieDataNode($input_node,$data_item->{Rank}));
		}
		
		push(@labels,$self->{TaxonomyBox}->GetString($i));
	}
	if (@piedata > 0 and @titles > 0) {
		my $pie_data = PieViewer->new(\@piedata,\@titles,\@labels,-1,-1,$control);
	}
}

sub TaxonomyBox {
	my ($self) = @_;
	my $frame = Wx::Frame->new(undef,-1,"Available Taxonomies",wxDefaultPosition,wxDefaultSize);
	my $panel = Wx::Panel->new($frame,-1);
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	$panel->SetBackgroundColour($turq);
	my $tax_list = Wx::ListBox->new($panel,-1);
	$self->FillTaxonomies($tax_list);
	my $add_button_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $add_button_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $add_button = Wx::Button->new($panel,-1,"Add");
	$add_button_sizer_v->Add($add_button,1,wxCENTER);
	$add_button_sizer_h->Add($add_button_sizer_v,1,wxCENTER);
	
	$sizer->Add($tax_list,2,wxEXPAND);
	$sizer->Add($add_button_sizer_h,1,wxEXPAND);
	$panel->SetSizer($sizer);
	$panel->Layout;
	$frame->Show;
	
	EVT_BUTTON($frame,$add_button,sub{$self->AddTaxonomy($tax_list->GetStringSelection)});
}

sub FillTaxonomies {
	my ($self,$listbox) = @_;
	
	my $dir = $control->{Results};
	opendir(DIR, $dir) or die $!;

    while (my $file = readdir(DIR)) {
    	next if ($file =~ m/^\./);
		next unless (-d "$dir/$file");
		opendir(TAXDIR, "$dir/$file") or die $!;
		while (my $xmlfile = readdir(TAXDIR)) {
        	next if ($xmlfile =~ m/^\./ or not $xmlfile =~ m/\.pact\.taxonomy/);
        	my @splitnames = split(/\./,$xmlfile);
        	my $label = $file . ": " . $splitnames[0];
			$listbox->Insert($label,0);
			$self->{FileHash}{$label} = "$dir/$file/$xmlfile"; 
   		}
   		close TAXDIR;
    }
    close DIR;
}

sub TypePanel {
	my ($self) = @_;
	my $selection = $self->{TaxonomyBox}->GetSelection;
	my $tax_string = $self->{TaxonomyBox}->GetStringSelection;

	$self->{TypePanel}->DestroyChildren;
	$self->{TypeSizer}->Clear;
	$self->{TypePanel}->Refresh;

	my $level_sizer = Wx::BoxSizer->new(wxHORIZONTAL);	
	my $tax_label = Wx::StaticText->new($self->{TypePanel},-1,"Choose Level: ");
	my $levels = ["kingdom","phylum","order","family","genus","species"];
	my $rank_box = Wx::ComboBox->new($self->{TypePanel},-1,"",wxDefaultPosition(),wxDefaultSize(),$levels,wxCB_DROPDOWN);
	$level_sizer->Add($tax_label,1,wxCENTER|wxLEFT,20);
	$level_sizer->Add($rank_box,1,wxCENTER|wxRIGHT,20);
	
	my $or_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $or = Wx::StaticText->new($self->{TypePanel},-1,"OR");
	$or_sizer->Add($or,1,wxCENTER);
	
	my $fill_sizer = Wx::BoxSizer->new(wxVERTICAL);	
	my $tax_fillbutton = Wx::Button->new($self->{TypePanel},-1,"Fill");
	my $tax_listbox = Wx::ListBox->new($self->{TypePanel},-1,wxDefaultPosition(),wxDefaultSize(),[]);

	if ($self->{ChartData}[$selection]->{IsFill}!=0) {
		$self->FillNodes($tax_listbox,$self->{FileHash}{$self->{TaxonomyBox}->GetStringSelection},$selection);
	}
	else {
		$rank_box->SetValue($self->{ChartData}[$selection]->{Rank});
	}

	$fill_sizer->Add($tax_fillbutton,1,wxCENTER,10);
	$fill_sizer->Add($tax_listbox,5,wxCENTER|wxEXPAND|wxTOP|wxLEFT|wxRIGHT,10);
	
	my $title_sizer = Wx::FlexGridSizer->new(1,2,10,10);
	$title_sizer->AddGrowableCol(1,2);
	my $title_label = Wx::StaticText->new($self->{TypePanel},-1,"Chart Title: ");
	my $title_box = Wx::TextCtrl->new($self->{TypePanel},-1,"");
	$title_box->SetValue($self->{ChartData}[$selection]->{Title});
	$title_sizer->Add($title_label,1,wxLEFT|wxCENTER,20);
	$title_sizer->Add($title_box,1,wxEXPAND|wxCENTER|wxRIGHT,20);

	$self->{TypeSizer}->Add($title_sizer,1,wxEXPAND|wxTOP,10);
	$self->{TypeSizer}->Add($fill_sizer,3,wxCENTER|wxEXPAND,5);
	$self->{TypeSizer}->Add($or_sizer,1,wxCENTER,5);
	$self->{TypeSizer}->Add($level_sizer,1,wxCENTER|wxEXPAND,5);
	
	$self->{TypePanel}->SetSizer($self->{TypeSizer});
	$self->{TypePanel}->Layout;

	EVT_COMBOBOX($self->{TypePanel},$rank_box,sub{$self->{ChartData}[$selection]->{Rank} = $rank_box->GetValue;});
	EVT_TEXT($self->{TypePanel},$title_box,sub{$self->{ChartData}[$selection]->{Title} = $title_box->GetValue;});
	EVT_BUTTON($self->{TypePanel},$tax_fillbutton,sub{$self->FillNodes($tax_listbox,$self->{FileHash}{$tax_string},$selection);});
	EVT_LISTBOX($self->{TypePanel},$tax_listbox,sub{$self->{ChartData}[$selection]->{NodeString} = $tax_listbox->GetStringSelection;
		$self->{ChartData}[$selection]->{NodeSelection} = $tax_listbox->GetSelection;
	});
}

sub FillNodes {
	my ($self,$listbox,$file,$selection) = @_;
	
	$listbox->Clear;
	
	my $xml = TaxonomyXML->new($file);
	my $nodes = $xml->GetNodes();
	my $count = 0;
	for my $node (@$nodes) {
		$listbox->Insert($node,$count);
		$count++;
	}
	
	if ($self->{ChartData}[$selection]->{NodeSelection}!=0) {
		$listbox->SetSelection($self->{ChartData}[$selection]->{NodeSelection});
	}
	
	$self->{ChartData}[$selection]->{IsFill} = 1;
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

sub new {
	my ($class,$parent) = @_;
	
	my $self = $class->SUPER::new($parent,-1);
	$self->SetBackgroundColour($turq);
	$self->{ParentNotebook} = $parent;
	$self->{TypePanel} = undef;
	$self->{Sizer} = undef; 
	$self->{TypeSizer} = undef;
	$self->{ChartData} = (); #Title, Level, NodeSelection, IsFill
	$self->{FileHash} = ();
	
	bless ($self,$class);
	$self->MainDisplay();
	$self->Layout;
	return $self;
}

sub MainDisplay {

	my ($self) = @_;

	$self->{Sizer} = Wx::BoxSizer->new(wxVERTICAL);
	my $center_display = Wx::BoxSizer->new(wxHORIZONTAL);

	my $file_panel = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$file_panel->SetBackgroundColour($blue);
	my $file_sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $file_button_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $file_button_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $file_button = Wx::Button->new($file_panel,-1,"Add");
	$file_button_sizer_h->Add($file_button,1,wxCENTER);
	$file_button_sizer_v->Add($file_button_sizer_h,1,wxCENTER);
	$self->{ObjectBox} = Wx::ListBox->new($file_panel,-1);
	
	$file_sizer->Add($file_button_sizer_v,1,wxCENTER,100);
	$file_sizer->Add($self->{ObjectBox},5,wxCENTER|wxEXPAND|wxBOTTOM|wxLEFT|wxRIGHT,20);
	$file_panel->Layout;
	$file_panel->SetSizer($file_sizer);
	
	$self->{TypePanel} = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$self->{TypePanel}->SetBackgroundColour($blue);
	$self->{TypeSizer} = Wx::BoxSizer->new(wxVERTICAL);
	
	$center_display->Add($file_panel,1,wxLEFT|wxCENTER|wxEXPAND|wxRIGHT,10);
	$center_display->Add($self->{TypePanel},1,wxRIGHT|wxCENTER|wxEXPAND,10);
	
	$self->{Sizer}->Add($center_display,1,wxCENTER|wxEXPAND);

	$self->SetSizer($self->{Sizer});
	$self->Layout;
	
	my $parent = $self->{ParentNotebook}->GetParent();
	while (defined $parent->GetParent) {
		$parent = $parent->GetParent;
	}
	
	EVT_LISTBOX($self,$self->{ObjectBox},sub{$self->TypePanel()});
	EVT_BUTTON($self,$file_button,sub{$self->FileBox()});
	EVT_LISTBOX_DCLICK($self,$self->{ObjectBox},sub{DeleteDialog->new($parent,"Delete","Remove Classification Pie Chart?",$self->{ObjectBox},$self->{ChartData});
	});
}

sub InitializeChartData {
	my ($self,$file) = @_;
	my $data_hash = {"FileString"=>$file, "Title"=>"","Top"=>-1,"Classifier"=>"","ClassSelection"=>0};
	push(@{$self->{ChartData}},$data_hash);
}

# should take directory.
sub FillObjects {
	my ($self,$listbox) = @_;
	
	my $dir = $control->{Results};
	opendir(DIR, $dir) or die $!;

    while (my $file = readdir(DIR)) {
    	next if ($file =~ m/^\./);
		next unless (-d "$dir/$file");
		opendir(CLASSDIR, "$dir/$file") or die $!;
		while (my $xmlfile = readdir(CLASSDIR)) {
        	next if ($xmlfile =~ m/^\./ or not $xmlfile =~ m/\.classification\./);
        	my @splitnames = split(/\./,$xmlfile);
        	my $label = $file . ": " . $splitnames[0];
			$listbox->Insert($label,0);
			$self->{FileHash}{$label} = "$dir/$file/$xmlfile";
   		}
   		close CLASSDIR;
    }
    close DIR;
}

sub GenerateCharts {
	my ($self) = @_;
	
	if ($self->{ObjectBox}->GetCount == 0) {
		return 0;
	}
	
	my @titles = ();
	my @piedata = ();
	my @labels = ();
	for (my $i=0; $i<@{$self->{ChartData}}; $i++) {
		my $data_item = $self->{ChartData}->[$i];
		my $xml = ClassificationXML->new($data_item->{FileString});
		
		if ($data_item->{"Top"} == -1 and $data_item->{"Classifier"} eq "") {
			next;
		}
		
		if ($data_item->{Title} ne "") {
			push(@titles,$data_item->{Title});
		}
		elsif ($data_item->{Classifier} ne "" and $data_item->{"Top"}==-1) {
			push(@titles,$data_item->{Classifier});
		}
		else {
			push(@titles,$self->{ObjectBox}->GetString($i));
		}
		
		if ($data_item->{"Top"}==1) {
			if ($xml->PieAllClassifiersData()->{Total} > 0) {
				push(@piedata,$xml->PieAllClassifiersData());
			}
		}
		else {
			if ($xml->PieClassifierData($data_item->{Classifier})->{Total} > 0) {
				push(@piedata,$xml->PieClassifierData($data_item->{Classifier}));
			}
		}
		
		push(@labels,$self->{ObjectBox}->GetString($i));
	}
	if (@piedata > 0 and @titles > 0) {
		my $pie_data = PieViewer->new(\@piedata,\@titles,\@labels,-1,-1,$control);
	}
}


## To be added to base class instead.

sub AddObject {
	my ($self,$tax_string) = @_;
	my $file = $self->{FileHash}{$tax_string};
	$self->InitializeChartData($file);
	my $count = $self->{ObjectBox}->GetCount;
	$self->{ObjectBox}->Insert($tax_string,$count);
}

sub FileBox {
	my ($self) = @_;
	my $frame = Wx::Frame->new(undef,-1,"Available Classications",wxDefaultPosition,wxDefaultSize);
	my $panel = Wx::Panel->new($frame,-1);
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	$panel->SetBackgroundColour($turq);
	my $file_list = Wx::ListBox->new($panel,-1);
	$self->FillObjects($file_list);
	my $add_button_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $add_button_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $add_button = Wx::Button->new($panel,-1,"Add");
	$add_button_sizer_v->Add($add_button,1,wxCENTER);
	$add_button_sizer_h->Add($add_button_sizer_v,1,wxCENTER);
	
	$sizer->Add($file_list,2,wxEXPAND);
	$sizer->Add($add_button_sizer_h,1,wxEXPAND);
	$panel->SetSizer($sizer);
	$panel->Layout;
	$frame->Show;
	
	EVT_BUTTON($frame,$add_button,sub{$self->AddObject($file_list->GetStringSelection)});
}

sub FillClassifiers {
	my ($self,$listbox,$file,$selection) = @_;
	
	$listbox->Clear;
	
	my $xml = ClassificationXML->new($file);
	my $classifiers = $xml->GetClassifiers();
	my $count = 0;
	for my $classifier (@$classifiers) {
		$listbox->Insert($classifier,$count);
		$count++;
	}
	
	if ($self->{ChartData}[$selection]->{ClassSelection}!=0) {
		$listbox->SetSelection($self->{ChartData}[$selection]->{ClassSelection});
	}
}

sub TypePanel {
	my ($self) = @_;
	my $selection = $self->{ObjectBox}->GetSelection;
	my $class_string = $self->{ObjectBox}->GetStringSelection;

	$self->{TypePanel}->DestroyChildren;
	$self->{TypeSizer}->Clear;
	$self->{TypePanel}->Refresh;
	
	my $title_sizer = Wx::FlexGridSizer->new(1,2,10,10);
	$title_sizer->AddGrowableCol(1,2);
	my $title_label = Wx::StaticText->new($self->{TypePanel},-1,"Chart Title: ");
	my $title_box = Wx::TextCtrl->new($self->{TypePanel},-1,"");
	$title_box->SetValue($self->{ChartData}[$selection]->{Title});
	$title_sizer->Add($title_label,1,wxLEFT|wxCENTER,20);
	$title_sizer->Add($title_box,1,wxEXPAND|wxCENTER|wxRIGHT,20);
	
	my $fill_sizer = Wx::BoxSizer->new(wxVERTICAL);	
	my $class_fillbutton = Wx::Button->new($self->{TypePanel},-1,"Choose Classifier");
	my $class_listbox = Wx::ListBox->new($self->{TypePanel},-1,wxDefaultPosition(),wxDefaultSize(),[]);
	$fill_sizer->Add($class_fillbutton,1,wxCENTER,10);
	$fill_sizer->Add($class_listbox,5,wxCENTER|wxEXPAND|wxTOP|wxLEFT|wxRIGHT,10);
	
	my $or_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $or = Wx::StaticText->new($self->{TypePanel},-1,"OR");
	$or_sizer->Add($or,1,wxCENTER);
	
	my $check_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $check_box = Wx::CheckBox->new($self->{TypePanel},-1,"All Classifiers");
	$check_sizer->Add($check_box,1,wxCENTER);

	$self->{TypeSizer}->Add($title_sizer,1,wxEXPAND|wxTOP,10);
	$self->{TypeSizer}->Add($fill_sizer,3,wxCENTER|wxEXPAND,5);
	$self->{TypeSizer}->Add($or_sizer,1,wxCENTER,5);
	$self->{TypeSizer}->Add($check_sizer,1,wxCENTER|wxEXPAND,5);
	
	$self->{TypePanel}->SetSizer($self->{TypeSizer});
	$self->{TypePanel}->Layout;
	
	EVT_TEXT($self->{TypePanel},$title_box,sub{$self->{ChartData}[$selection]->{Title} = $title_box->GetValue;});
	EVT_BUTTON($self->{TypePanel},$class_fillbutton,sub{$self->FillClassifiers($class_listbox,$self->{FileHash}{$class_string},$selection);});
	EVT_LISTBOX($self->{TypePanel},$class_listbox,sub{$self->{ChartData}[$selection]->{Classifier} = $class_listbox->GetStringSelection;
		$self->{ChartData}[$selection]->{ClassSelection} = $class_listbox->GetSelection;
	});
	EVT_CHECKBOX($self->{TypePanel},$check_box,sub{$self->{ChartData}[$selection]->{Top} *=-1;});
	
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
	
	$self->{TaxPanel} = TaxonomyPiePanel->new($self->{PieNotebook});
	$self->{ClassPanel} = ClassificationPiePanel->new($self->{PieNotebook});
	
	$self->{PieNotebook}->AddPage($self->{TaxPanel},"Taxonomy");
	$self->{PieNotebook}->AddPage($self->{ClassPanel},"Other Classification");
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

package TaxonomyPanel;

use base 'Wx::Frame';
use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);

sub new {
	my $class = $_[0];
	my $parent = $_[1];
	my $px = $parent->GetPosition()->x;
	my $py = $parent->GetPosition()->y;
	my $pwidth = $parent->GetSize()->width;
	my $pheight = $parent->GetSize()->height;
	my $twidth = $pwidth/2;
	my $theight = $pheight/2;
	my $size = Wx::Size->new($twidth,$theight);
	my $tx = $px + $pwidth/2 - $twidth/2; 
	my $ty = $py + $pheight/2 - $theight/2;
	my $self = $class->SUPER::new(undef,-1,"NCBI Taxonomy",[$tx,$ty],[$twidth,$theight]);
	$self->{Panel} = Wx::Panel->new($self,-1);
	$self->{Panel}->SetBackgroundColour($blue);
	$self->{SourceCombo} = undef;
	$self->{RankList} = undef;
	$self->{RootList} = undef;
	bless $self,$class;
	$self->PanelItems($_[2]);
	$self->Show;
	return $self;
}

sub PanelItems {
	my $self = $_[0];
	my $parser_panel = $_[1];
	$self->{Sizer} = Wx::BoxSizer->new(wxVERTICAL);

	my $source_panel = Wx::Panel->new($self->{Panel},-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	my $source_sizer_outer = Wx::BoxSizer->new(wxVERTICAL);
	my $source_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $combo_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $source_label_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $source_label = Wx::StaticText->new($source_panel,-1,"Source: ");
	$source_label_sizer->Add($source_label,1,wxCENTER);
	$self->{SourceCombo} = Wx::ComboBox->new($source_panel,-1,"",wxDefaultPosition,wxDefaultSize,["Connection","Local Files"]);
	$combo_sizer->Add($self->{SourceCombo},1,wxCENTER);
	$source_sizer->Add($source_label_sizer,1,wxCENTER);
	$source_sizer->Add($combo_sizer,3,wxCENTER);
	$source_sizer_outer->Add($source_sizer,1,wxCENTER);
	$source_panel->SetSizer($source_sizer_outer);
	
	my $rank_panel = Wx::Panel->new($self->{Panel},-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	my $rank_sizer_outer = Wx::BoxSizer->new(wxVERTICAL);
	my $rank_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $rank_label_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $rank_label = Wx::StaticText->new($rank_panel,-1,"Ranks: ");
	$rank_label_sizer->Add($rank_label,1,wxCENTER);
	my $rank_list = Wx::ListBox->new($rank_panel,-1,wxDefaultPosition,wxDefaultSize,["Order","Family","Genus","Species"]);
	my $rank_button_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $rank_button = Wx::Button->new($rank_panel,-1,'Add');
	$rank_button_sizer->Add($rank_button,1,wxCENTER);
	
	if (defined $parser_panel->{Taxonomy}) {
		my @ranks = keys(%{$parser_panel->{Taxonomy}->{Ranks}});
		$self->{RankList} = Wx::ListBox->new($rank_panel,-1,wxDefaultPosition,wxDefaultSize,\@ranks);
	}
	else {
		$self->{RankList} = Wx::ListBox->new($rank_panel,-1);
	}
	$rank_sizer->Add($rank_label_sizer,1,wxCENTER);
	$rank_sizer->Add($rank_list,1,wxEXPAND);
	$rank_sizer->Add($rank_button_sizer,1,wxCENTER);
	$rank_sizer->Add($self->{RankList},1,wxEXPAND);
	$rank_sizer_outer->Add($rank_sizer,1,wxCENTER);
	$rank_panel->SetSizer($rank_sizer_outer);
	
	EVT_BUTTON($self->{Panel},$rank_button,sub{$self->{RankList}->Insert($rank_list->GetStringSelection,0)});
	
	my $root_panel = Wx::Panel->new($self->{Panel},-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	my $root_sizer_outer = Wx::BoxSizer->new(wxVERTICAL);
	my $root_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $root_label_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $root_label = Wx::StaticText->new($root_panel,-1,"Roots: ");
	$root_label_sizer->Add($root_label,1,wxCENTER);
	my $root_text = Wx::TextCtrl->new($root_panel,-1,"");
	my $root_button_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $root_button = Wx::Button->new($root_panel,-1,'Add');
	$root_button_sizer->Add($root_button,1,wxCENTER);
	if (defined $parser_panel->{Taxonomy}) {
		my @roots = keys(%{$parser_panel->{Taxonomy}->{Roots}});
		$self->{RootList} = Wx::ListBox->new($root_panel,-1,wxDefaultPosition,wxDefaultSize,\@roots);
	}
	else {
		$self->{RootList} = Wx::ListBox->new($root_panel,-1);
	}
	$root_sizer->Add($root_label_sizer,1,wxCENTER);
	$root_sizer->Add($root_text,1,wxCENTER);
	$root_sizer->Add($root_button_sizer,1,wxCENTER);
	$root_sizer->Add($self->{RootList},1,wxEXPAND);
	$root_sizer_outer->Add($root_sizer,1,wxCENTER);
	$root_panel->SetSizer($root_sizer_outer);
	
	EVT_BUTTON($self->{Panel},$root_button,sub{$self->{RootList}->Insert($root_text->GetValue,0)});

	my $save_panel = Wx::Panel->new($self->{Panel},-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	my $save_sizer_outer = Wx::BoxSizer->new(wxVERTICAL);
	my $save_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $save_button = Wx::Button->new($save_panel,-1,'Save');
	$save_sizer->Add($save_button,1,wxCENTER);
	$save_sizer_outer->Add($save_sizer,1,wxCENTER);
	$save_panel->SetSizer($save_sizer_outer);
	
	EVT_BUTTON($self->{Panel},$save_button,sub{$self->InitializeTaxonomy($parser_panel)});

	$self->{Sizer}->Add($source_panel,1,wxEXPAND);
	$self->{Sizer}->Add($rank_panel,2,wxEXPAND);
	$self->{Sizer}->Add($root_panel,2,wxEXPAND);
	$self->{Sizer}->Add($save_panel,1,wxEXPAND);
	$self->{Panel}->SetSizer($self->{Sizer});
	
	$self->{Panel}->Layout;
	$self->Layout;
}

sub InitializeTaxonomy {
	
	my $self = $_[0];

	$_[1]->{Taxonomy} = undef;
	
	my @ranks = $self->{RankList}->GetStrings;
	my @roots = $self->{RootList}->GetStrings;
	
	if ($self->{SourceCombo}->GetValue eq "Connection") {
		$_[1]->{Taxonomy} = ConnectionTaxonomy->new(\@ranks,\@roots,$control);
	}
	else {
		$_[1]->{Taxonomy} = FlatFileTaxonomy->new($control->{NodesFile},$control->{NamesFile},\@ranks,\@roots,$control);
	}
	$self->Destroy;
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
	$self->{ParentNotebook} = $parent;

	$self->{BlastFileTextBox} = undef;
	$self->{FastaFileTextBox} = undef;
	$self->{DirectoryTextBox} = undef;
	$self->{TableTextBox} = undef;
	$self->{ClassificationListBox} = undef;
	$self->{FlagListBox} = undef;
	$self->{BitTextBox} = undef;
	$self->{EValueTextBox} = undef;
	
	$self->{BlastFilePath} = "";
	$self->{FastaFilePath} = "";
	$self->{OutputDirectoryPath} = "";
	$self->{OutputTableName} = "";
	$self->{ClassLabelToPath} = ();
	$self->{FlagLabelToPath} = ();
	$self->{Taxonomy} = undef;
	
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

sub TableChecked {
	my ($self,$checkbox) = @_;
	my $value = $checkbox->GetValue;
	my $name = "";
	if ($value == 1) {
		$name = $control->ReadyForDB($self->{BlastFileTextBox}->GetValue());
	}
	$self->{OutputTableName} = $name;
	$self->{TableTextBox}->ChangeValue($name);
}

sub TableEntered {
	my ($self,$checkbox) = @_;
	$checkbox->SetValue(1);
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
	if ($self->{BlastFilePath} eq "") {
		return -1;
	}
	elsif ($self->{FastaFilePath} eq "") {
		return -2;
	}
	elsif ($self->{OutputDirectoryPath} eq "" and $self->{OutputTableName} eq "") {
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
	
	my $pagesizer_horiz = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->SetBackgroundColour($blue);
	
	my $pagesizer_vert = Wx::BoxSizer->new(wxVERTICAL);
	
	my $filespanel = $self->InputFilesMenu();
	my $classificationpanel = $self->ClassificationMenu();
	my $parameterspanel = $self->ParameterMenu();
	my $add_panel = $self->OutputMenu();
	
	$pagesizer_vert->Add($filespanel,1,wxEXPAND);
	
	$pagesizer_horiz->Add($classificationpanel,1,wxEXPAND);
	$pagesizer_horiz->Add($parameterspanel,1,wxEXPAND);
	
	$pagesizer_vert->Add($pagesizer_horiz,2,wxEXPAND);
	$pagesizer_vert->Add($add_panel,1,wxEXPAND);
	
	$self->SetSizer($pagesizer_vert);
	
}

sub InputFilesMenu {
	my ($self) = @_;
	
	my $filespanel = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	my $filessizer = Wx::BoxSizer->new(wxVERTICAL);
	my $singlessizer = Wx::FlexGridSizer->new(3,3,15,15);
	$singlessizer->AddGrowableCol(1,2);
	
	my $blast_label = Wx::StaticText->new($filespanel,-1,'BLAST File:');
	$self->{BlastFileTextBox} = Wx::TextCtrl->new($filespanel,-1,'',wxDefaultPosition,wxDefaultSize);
	$self->{BlastFileTextBox}->SetEditable(0);
	my $blast_button = Wx::Button->new($filespanel,-1,'Find');
	$singlessizer->Add($blast_label,1,wxCENTER,0);
	$singlessizer->Add($self->{BlastFileTextBox},1,wxCENTER|wxEXPAND,0);
	$singlessizer->Add($blast_button,1,wxCENTER,0);
	EVT_BUTTON($filespanel,$blast_button,sub{$self->BlastButtonEvent()});
	
	my $fasta_label = Wx::StaticText->new($filespanel,-1,'FASTA File:');
	$self->{FastaFileTextBox} = Wx::TextCtrl->new($filespanel,-1,'',wxDefaultPosition,wxDefaultSize);
	$self->{FastaFileTextBox}->SetEditable(0);
	my $fasta_button = Wx::Button->new($filespanel,-1,'Find');
	$singlessizer->Add($fasta_label,1,wxCENTER,0);
	$singlessizer->Add($self->{FastaFileTextBox},1,wxCENTER|wxEXPAND,0);
	$singlessizer->Add($fasta_button,1,wxCENTER,0);
	EVT_BUTTON($filespanel,$fasta_button,sub{$self->{FastaFilePath} = $self->OpenDialogSingle($self->{FastaFileTextBox},'Choose FASTA File')});
	
	my $center_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	$center_sizer->Add(Wx::BoxSizer->new(wxVERTICAL),1,wxLEFT,0);
	$center_sizer->Add($singlessizer,4,wxCENTER,0);
	$center_sizer->Add(Wx::BoxSizer->new(wxVERTICAL),1,wxRIGHT,0);
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
	
	my $classificationpanel = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	my $classificationsizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $title = Wx::StaticText->new($classificationpanel,-1,'Classifications');
	my $title_sizer = Wx::BoxSizer->new(wxVERTICAL);
	$title_sizer->Add($title,1,wxCENTER);
	
	my $itemssizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $tax_sizer_1 = Wx::BoxSizer->new(wxVERTICAL);
	my $tax_sizer_2 = Wx::BoxSizer->new(wxHORIZONTAL);
	my $tax_label_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $tax_label = Wx::StaticText->new($classificationpanel,-1,'NCBI Taxonomy: ');
	$tax_label_sizer->Add($tax_label,1,wxCENTER);
	my $tax_add_button_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $tax_remove_button_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $tax_add_button = Wx::Button->new($classificationpanel,-1,'Add');
	my $tax_remove_button = Wx::Button->new($classificationpanel,-1,'Remove');
	$tax_add_button_sizer->Add($tax_add_button,1,wxCENTER);
	$tax_remove_button_sizer->Add($tax_remove_button,1,wxCENTER);
	$tax_sizer_2->Add($tax_label,1,wxCENTER);
	$tax_sizer_2->Add($tax_add_button_sizer,1,wxCENTER);
	$tax_sizer_2->Add($tax_remove_button_sizer,1,wxCENTER);
	$tax_sizer_1->Add($tax_sizer_2,1,wxCENTER);
	
	
	EVT_BUTTON($classificationpanel,$tax_add_button,sub{TaxonomyPanel->new($parent,$self)});
	EVT_BUTTON($classificationpanel,$tax_remove_button,sub{$self->{Taxonomy} = undef;});
	
	my $class_flag_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	
	my $flag_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $flag_label = Wx::StaticText->new($classificationpanel,-1,'Hits to Flag: ');
	my $flag_label_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	$flag_label_sizer->Add($flag_label,1,wxCENTER);
	
	my $flag_text_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $flag_button_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $flag_button = Wx::Button->new($classificationpanel,-1,'Add');
	$flag_button_sizer->Add($flag_button,1,wxCENTER);
	my $flag_list_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{FlagListBox} = Wx::ListBox->new($classificationpanel,-1,wxDefaultPosition,wxDefaultSize);
	$flag_list_sizer->Add($self->{FlagListBox},1,wxEXPAND);
	$flag_text_sizer->Add($flag_button_sizer,1,wxBOTTOM|wxCENTER,5);
	$flag_text_sizer->Add($flag_list_sizer,3,wxCENTER|wxEXPAND);
	EVT_BUTTON($classificationpanel,$flag_button,sub{$self->OpenDialogMultiple($self->{FlagListBox},'Find Flag File',\%{$self->{FlagLabelToPath}});});
	
	$flag_sizer->Add($flag_label_sizer,1,wxEXPAND);
	$flag_sizer->Add($flag_text_sizer,1,wxEXPAND);
	
	my $class_sizer =  Wx::BoxSizer->new(wxHORIZONTAL);
	my $class_label = Wx::StaticText->new($classificationpanel,-1,'Other Classification: ');
	my $class_label_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	$class_label_sizer->Add($class_label,1,wxCENTER);
	
	my $class_text_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $class_button_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $class_button = Wx::Button->new($classificationpanel,-1,'Add');
	$class_button_sizer->Add($class_button,1,wxCENTER);
	my $class_list_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{ClassificationListBox} = Wx::ListBox->new($classificationpanel,-1,wxDefaultPosition,wxDefaultSize);
	$class_list_sizer->Add($self->{ClassificationListBox},1,wxEXPAND);
	$class_text_sizer->Add($class_button_sizer,1,wxBOTTOM|wxCENTER,5);
	$class_text_sizer->Add($class_list_sizer,3,wxCENTER|wxEXPAND);
	EVT_BUTTON($classificationpanel,$class_button,sub{$self->OpenDialogMultiple($self->{ClassificationListBox},'Find Classification File',\%{$self->{ClassLabelToPath}});});
	
	$class_sizer->Add($class_label_sizer,1,wxEXPAND);
	$class_sizer->Add($class_text_sizer,1,wxEXPAND);
	
	$class_flag_sizer->Add($class_sizer,1,wxEXPAND);
	$class_flag_sizer->Add($flag_sizer,1,wxEXPAND);
	
	$itemssizer->Add($tax_sizer_1,1,wxEXPAND|wxBOTTOM,15);
	$itemssizer->Add($class_flag_sizer,2,wxEXPAND);
	
	$classificationsizer->Add($title_sizer,1,wxCENTER);
	$classificationsizer->Add($itemssizer,4,wxEXPAND);
	
	$classificationpanel->SetSizer($classificationsizer);
	
	EVT_LISTBOX_DCLICK($classificationpanel,$self->{FlagListBox},sub{DeleteDialog->new($parent,"Delete","Delete Flag File?",$self->{FlagListBox})});
	EVT_LISTBOX_DCLICK($classificationpanel,$self->{ClassificationListBox},sub{DeleteDialog->new($parent,"Delete","Delete Classification File?",$self->{ClassificationListBox})});
	
	return $classificationpanel;
}

sub ParameterMenu {
	my ($self) = @_;
	
	my $panel = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $title_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $title = Wx::StaticText->new($panel,-1,"Parameters");
	$title_sizer->Add($title,1,wxCENTER);
	
	my $choice_wrap = Wx::BoxSizer->new(wxVERTICAL);
	$choice_wrap->Add(Wx::BoxSizer->new(wxVERTICAL),1,wxEXPAND);
	my $choice_sizer = Wx::FlexGridSizer->new(1,2,20,20);
	
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
	
	$sizer->Add($title_sizer,1,wxEXPAND|wxCENTER);
	$sizer->Add($choice_wrap,5,wxEXPAND|wxCENTER);
	$panel->SetSizer($sizer);
	
	return $panel;
}

sub OutputMenu {
	my ($self) = @_;
	
	my $add_panel = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	my $add_sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $send_title = Wx::StaticText->new($add_panel,-1,"Send Results To:");
	
	my $table_check = Wx::CheckBox->new($add_panel,-1,"Database Table");
	my $text_check = Wx::CheckBox->new($add_panel,-1,"Text Files");
	my $directory_title = Wx::StaticText->new($add_panel,-1,"Output Directory:");
	$self->{DirectoryTextBox} = Wx::TextCtrl->new($add_panel,-1,"");
	my $table_title = Wx::StaticText->new($add_panel,-1,"Table Name:");
	$self->{TableTextBox} = Wx::TextCtrl->new($add_panel,-1,"");
	$self->{DirectoryTextBox}->SetEditable(0);
	
	my $check_sizer = Wx::FlexGridSizer->new(2,3,20,20);
	$check_sizer->AddGrowableCol(2,1);
	$check_sizer->Add($text_check,1,wxCENTER);
	$check_sizer->Add($directory_title,1,wxCENTER);
	$check_sizer->Add($self->{DirectoryTextBox},1,wxCENTER|wxEXPAND);
	$check_sizer->Add($table_check,1,wxCENTER);
	$check_sizer->Add($table_title,1,wxCENTER);
	$check_sizer->Add($self->{TableTextBox},1,wxCENTER|wxEXPAND);
	EVT_CHECKBOX($add_panel,$text_check,sub{$self->DirectoryChecked($text_check,"Choose Directory")});
	EVT_CHECKBOX($add_panel,$table_check,sub{$self->TableChecked($table_check)});
	EVT_TEXT($add_panel,$self->{TableTextBox},sub{$self->TableEntered($table_check)});
	
	$add_sizer->Add($send_title,1,wxCENTER);
	$add_sizer->Add($check_sizer,3,wxCENTER|wxEXPAND|wxLEFT|wxRIGHT,50);
	
	$add_panel->SetSizer($add_sizer);
	
	return $add_panel;
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
	$self->{Parsers} = ();
	$self->{CurrentPage} = undef;
	
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
	
	$self->{WidgetToProcess} = (); # when a widget is updated, its associated process should be as well.
	
	my $sizer = Wx::BoxSizer->new(wxHORIZONTAL);
		
	my $splitter = Wx::SplitterWindow->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSP_3D);

	$self->{LeftPanel} = Wx::Panel->new($splitter,-1);
	$self->{LeftPanel}->SetBackgroundColour($turq);
	my $leftsizer = Wx::BoxSizer->new(wxVERTICAL);
	my $qtextsizer = Wx::BoxSizer->new(wxVERTICAL);
	my $queuetext = Wx::StaticText->new($self->{LeftPanel},-1,"Queue");
	$qtextsizer->Add($queuetext,1,wxCENTER);
	
	my $listsizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{QueueList} = Wx::ListBox->new($self->{LeftPanel},-1,wxDefaultPosition(),wxDefaultSize());

	$listsizer->Add($self->{QueueList},1,wxEXPAND);
	
	$leftsizer->Add($qtextsizer,1,wxCENTER,wxEXPAND);
	$leftsizer->Add($listsizer,15,wxEXPAND);
	
	$self->{LeftPanel}->SetSizer($leftsizer);
	$self->{LeftPanel}->Layout;
	
	my $parent = $self->GetParent();
	while (defined $parent->GetParent) {
		$parent = $parent->GetParent;
	}
	
	EVT_LISTBOX($self->{LeftPanel},$self->{QueueList},sub{$self->DisplayParserMenu($self->{QueueList}->GetSelection)});
	EVT_LISTBOX_DCLICK($self->{LeftPanel},$self->{QueueList},sub{FunctionDialog->new($parent,"Delete","Delete Parser?",\&QueuePanel::DeleteParser,[$self])});
	
	$self->{ParserNotebook} = undef;
	$self->{RightPanel} = Wx::Panel->new($splitter,-1);
	$self->{RightPanel}->SetBackgroundColour($turq);
	my $menusizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{ParserNotebook} = Wx::Notebook->new($self->{RightPanel},-1);
	$self->{ParserNotebook}->SetBackgroundColour($turq);
	$self->{CurrentPage} = ParserMenu->new($self->{ParserNotebook});
	$self->{ParserNotebook}->AddPage($self->{CurrentPage},"");
	$self->{RightPanel}->Layout;
	
	my $button_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $button_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $add_button = Wx::Button->new($self->{RightPanel},-1,'Queue');
	$button_sizer_v->Add($add_button,1,wxCENTER);
	$button_sizer_h->Add($button_sizer_v,1,wxCENTER);
	
	EVT_BUTTON($self->{RightPanel},$add_button,sub{$self->NewProcessForQueue()});
	
	$self->{ParserNotebook}->Layout;
	$menusizer->Add($self->{ParserNotebook},8,wxEXPAND);
	$menusizer->Add($button_sizer_h,1,wxEXPAND);
	$self->{RightPanel}->SetSizer($menusizer);
	
	my $splitsize = ($self->{Parent}->GetSize()->width)/4;
	$splitter->SplitVertically($self->{LeftPanel},$self->{RightPanel},$splitsize);

	$sizer->Add($splitter,1,wxEXPAND);
	$self->SetSizer($sizer);
	$self->Layout;
	
}

sub DisplayParserMenu {
	my ($self,$selection) = @_;
	$self->{ParserNotebook}->SetSelection($selection);
}

sub DeleteParser {
	my ($self) = @_;
	my $selection = $self->{QueueList}->GetSelection;
	$self->{QueueList}->Delete($selection);
	$self->{ParserNotebook}->RemovePage($selection);
	$self->Refresh;
}

sub NewProcessForQueue {
	my ($self) = @_;
	
	if ($self->{CurrentPage}->CheckProcess() == -1) {
		$self->{Parent}->SetStatusText("Please Choose a BLAST Output File");
		return 0;	
	}
	elsif ($self->{CurrentPage}->CheckProcess() == -2) {
		$self->{Parent}->SetStatusText("Please Choose a FASTA File");
		return 0;	
	}
	elsif ($self->{CurrentPage}->CheckProcess() == -3) {
		$self->{Parent}->SetStatusText("Please Choose a Data Output Type");	
		return 0;
	}
	elsif ($self->{CurrentPage}->CheckProcess() == 1) {
		$self->AddProcessQueue();
		$self->NewPage();
	}
	else {
		return 0;
	}
}

sub NewPage {
	my ($self) = @_;
	$self->{CurrentPage} = ParserMenu->new($self->{ParserNotebook});
	my $NumSelections = $self->{ParserNotebook}->GetPageCount;
	$self->{ParserNotebook}->AddPage($self->{CurrentPage},"");
	$self->{ParserNotebook}->SetSelection($NumSelections);
}

sub AddProcessQueue {
	my ($self) = @_;
	my $count = $self->{ParserNotebook}->GetPageCount;
	$self->{QueueList}->InsertItems([$self->{ParserNotebook}->GetPageText($self->{ParserNotebook}->GetSelection)],$count-1);
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
	$self->{ResultsPanel} = undef;
	$self->{TablePanel} = undef;
	
	$self->{Sizer}->Add($self->{Panel},1,wxGROW);
	$self->SetSizer($self->{Sizer});
	
	$self->Centre();
	return $self;
}

sub RunParsers {
	my ($self) = @_;
	my $count = $self->{QueuePanel}->{ParserNotebook}->GetPageCount;
	for (my $i=0; $i<$count; $i++) {
		my $page = $self->{QueuePanel}->{ParserNotebook}->GetPage($i);
		if ($page->{BlastFilePath} eq "") {
			last;
		}
		my $parser = BlastParser->new($self->{QueuePanel}->{ParserNotebook}->GetPageText($i),$control);
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
		
		if ($page->{OutputTableName} ne "") {
			my $table = SendTable->new($page->{OutputTableName},$parser->{InternalDirectory},$control);
			$parser->AddProcess($table);
		}
		if ($page->{OutputDirectoryPath} ne "") {
			my $text;
			if (defined $page->{Taxonomy}) {
				$text = TaxonomyTextPrinter->new($page->{OutputDirectoryPath},$page->{Taxonomy},$control);
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
			if (defined $page->{Taxonomy}) {
				$parser->AddProcess($page->{Taxonomy});
			}
		}
		
		push(@{$self->{QueuePanel}->{Parsers}},$parser);
	}
	
	for my $parser(@{$self->{QueuePanel}->{Parsers}}) {
		$parser->Parse();
	}
	
	$self->SetStatusText("Done Processing");
}

sub RunProcessCheck {
	my ($self,$event)  = @_;
	my $parsercheck = $self->{QueuePanel}->{CurrentPage}->CheckProcess();
	my $count = $self->{QueuePanel}->{ParserNotebook}->GetPageCount;
	
	my $count_string = "process";
	
	if ($parsercheck == 1) {
		if ($count > 1) {
			$count_string = "processes";
		}
		$self->{QueuePanel}->{QueueList}->InsertItems([$self->{QueuePanel}->{ParserNotebook}->GetPageText($self->{QueuePanel}->{ParserNotebook}->GetSelection)],$count-1);
		FunctionDialog->new($self,"Run Parsers","$count " . $count_string . " to run. Continue?",\&Display::RunParsers,[$self]);
	}
	elsif ($parsercheck!=1 and $count>1) {
		if ($count > 2) {
			$count_string = "processes";
		}
		$count = $count - 1;
		DoubleDialog->new($self,"Incomplete Process","There is an incomplete process. Continue?",
		"Run Parsers","$count " . $count_string . " to run. Continue?",\&Display::RunParsers,[$self]);
	}
	else {
	}
}

sub OnProcessClicked {
	my ($self,$event) = @_;
	$self->{Panel}->Hide;
	if (defined $self->{PiePanel}) {
		$self->{PiePanel}->Hide;
	}
	if (defined $self->{ResultsPanel}) {
		$self->{ResultsPanel}->Hide;
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
	$self->{FileMenu}->Enable(103,1);
}

sub ResultMenu {
	my($self,$outputDir) = @_;
	
	$self->{ResultsPanel} = Wx::Panel->new($self,-1);
	
	$self->{Panel}->Hide;
	if (defined $self->{PiePanel}) {
		$self->{PiePanel}->Hide;
	}
	if (defined $self->{QueuePanel}) {
		$self->{QueuePanel}->Hide;
	}
	$self->Refresh;
	
	my $sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $dir_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $list_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $dir = Wx::GenericDirCtrl->new($self->{ResultsPanel},-1,$outputDir,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER,"*.pact.*");
	
	my $tree = $dir->GetTreeCtrl();
	$dir_sizer->Add($dir,1,wxEXPAND);
	my $list = Wx::TextCtrl->new($self->{ResultsPanel},-1,"",wxDefaultPosition,wxDefaultSize,wxTE_MULTILINE);
	$list_sizer->Add($list,1,wxEXPAND);
	$sizer->Add($dir_sizer,1,wxEXPAND);
	$sizer->Add($list_sizer,1,wxEXPAND);
	
	EVT_TREE_ITEM_ACTIVATED($self->{ResultsPanel},$tree->GetId(),sub{$self->List_File($dir->GetPath,$list)});
	$self->{ResultsPanel}->SetSizer($sizer);
	$self->{ResultsPanel}->Layout;
	$self->{Sizer}->Clear;
	$self->{Sizer}->Add($self->{ResultsPanel},1,wxEXPAND);
	$self->Layout;
}

sub InitializePieMenu {
	my($self,$event) = @_;
	$self->{Panel}->Hide;
	if (defined $self->{QueuePanel}) {
		$self->{QueuePanel}->Hide;
	}
	if (defined $self->{ResultsPanel}) {
		$self->{ResultsPanel}->Hide;
	}
	$self->Refresh;
	if (defined $self->{PiePanel}) {
		$self->Refresh;
		$self->{PiePanel}->Show;
	}
	else {
		my $piemenu = PieMenu->new($self);
		$self->{PiePanel} = $piemenu->{Panel};
	}
	$self->{Sizer}->Clear;
	$self->{Sizer}->Add($self->{PiePanel},1,wxEXPAND);
	$self->Layout;
	$self->{FileMenu}->Enable(103,0);
}

sub InitializeTableViewer {
	my($self,$event) = @_;
	$self->SetStatusText("Coming Soon");
}

sub TopMenu {
	my ($self) = @_;
	
	$self->{FileMenu} = Wx::Menu->new();
	my $newblast = $self->{FileMenu}->Append(101,"New Parser");
	$self->{FileMenu}->AppendSeparator();
	my $run = $self->{FileMenu}->Append(102,"Run Parsers");
	my $close = $self->{FileMenu}->Append(103,"Quit");
	EVT_MENU($self,101,\&OnProcessClicked);
	EVT_MENU($self,102,\&RunProcessCheck);
	EVT_MENU($self,103,sub{$self->Close(1)});

	my $viewmenu = Wx::Menu->new();
	my $result = $viewmenu->Append(201,"Results");
	my $table = $viewmenu->Append(202,"Table");
	my $pie = $viewmenu->Append(203,"Pie Charts");
	my $tax = $viewmenu->Append(204,"Tree");
	EVT_MENU($self,201,sub{$self->ResultMenu("")});
	EVT_MENU($self,202,\&InitializeTableViewer);
	EVT_MENU($self,203,\&InitializePieMenu);
	#EVT_MENU($self,204,);

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
