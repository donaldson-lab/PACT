#!/usr/bin/perl
use strict;
use threads;
use threads::shared;
use Wx;
#use ProcessDB;
use PieViewer;
use IO::File;
use IOManager;
use Cwd;

# Global colors
my $turq = Wx::Colour->new("TURQUOISE");
my $blue = Wx::Colour->new(130,195,250);
my $brown = Wx::Colour->new(244,164,96);

my $os_manager = IOManager->new();

package OkDialog;
use base 'Wx::Frame';
use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);

# Takes a parent (frame base class), the function and its parameters, and a title. 
sub new {
	my ($class,$parent,$title,$dialog,$function,$parameters) = @_;
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
	my $panel = Wx::Panel->new($self,-1);
	$panel->SetBackgroundColour($turq);
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $text_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $text = Wx::StaticText->new($panel,-1,$dialog);
	$text_sizer->Add($text,1,wxCENTER);
	
	my $button_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $ok = Wx::Button->new($panel,-1,"Ok");
	my $cancel = Wx::Button->new($panel,-1,"Cancel");
	$button_sizer->Add($ok,1,wxCENTER|wxRIGHT,10);
	$button_sizer->Add($cancel,1,wxCENTER|wxLEFT,10);
	
	$sizer->Add($text_sizer,1,wxCENTER);
	$sizer->Add($button_sizer,2,wxCENTER);
	$panel->SetSizer($sizer);
	$self->Show;
	
	EVT_BUTTON($panel,$ok,sub{$self->OkPressed($parent,$function,$parameters)});
	EVT_BUTTON($panel,$cancel,sub{$self->Close(1)});
}

# Ensures the dialog is destroyed when the ok or yes button is pressed.
sub OkPressed {
	my ($self,$parent,$function,$parameters) = @_;
	$function->($parent,$parameters);
	$self->Close(1);
}

# To be deprecated?

# For individual Pie Charts.
package PieData;

sub new {
	my ($class) = shift;
	my $self = {
		File => "",
		Return => undef,
		Title => "",
		Level => "",
		Is_Level => 0,
		Is_Fill => 0,
		Fill_Selection => 0,
		Selection_String => ""
	};
	
	bless $self,$class;
	return $self;
}

package PieMenu;
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
	my ($class,$parent) = @_;

	my $self = {
	
		Tax_Panel => undef,
		Tax_Sizer => undef,
		Tax_Type_Panel => undef,
		Tax_Type_Sizer => undef,
		Class_Panel => undef,
		Class_Sizer => undef,
		Class_Type_Panel => undef,
		Class_Type_Sizer => undef,
		PieNotebook => undef,
		Sync_Tax => undef, # array of taxonomy objects to be processed into pie charts.
		Sync_Class => undef # array of classification objects to be processed into pie charts.
	};
	$self->{Panel} = Wx::Panel->new($parent,-1);
	$self->{Panel}->SetBackgroundColour($turq);
	bless($self,$class);
	$self->TopMenu();
	return $self;
}

sub TopMenu {
	my ($self) = @_;

	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{PieNotebook} = Wx::Notebook->new($self->{Panel},-1);
	$self->{PieNotebook}->SetBackgroundColour($turq);
	
	$self->{Tax_Panel} = Wx::Panel->new($self->{PieNotebook},-1);
	$self->{Tax_Panel}->SetBackgroundColour($turq);
	$self->Taxonomy_Menu();

	$self->{Class_Panel} = Wx::Panel->new($self->{PieNotebook},-1);
	$self->{Class_Panel}->SetBackgroundColour($turq);
	$self->Classification_Menu();
	
	$self->{PieNotebook}->AddPage($self->{Tax_Panel},"Taxonomy");
	$self->{PieNotebook}->AddPage($self->{Class_Panel},"Other Classification");
	$self->{PieNotebook}->Layout;
	$sizer->Add($self->{PieNotebook},1,wxEXPAND);
	$self->{Panel}->SetSizer($sizer);

	$self->{Panel}->Layout;
}

# This should be split. Too many inputs
sub Open_For_Pie_Dialog {
	my ($self,$text_entry,$title,$panel,$wx_dialog,$text_type,$piearray,$function) = @_;
	my $dialog = 0;
	if ($wx_dialog==0) {
		$dialog = Wx::FileDialog->new($panel,$title);
	}
	elsif ($wx_dialog == 1) {
		$dialog = Wx::DirDialog->new($panel,$title);
	}
	if ($dialog->ShowModal==wxID_OK){
		if ($text_type == 0) {
			$text_entry->SetValue($dialog->GetPath);
		}
		else {
			my $piedata = PieData->new();
			$piedata->{File} = $dialog->GetPath;
			my $selection = $text_entry->GetCount;
			push(@{$piearray},$piedata);
			my @split = split($os_manager->{path_separator},$dialog->GetPath);
			my $file_label = $split[@split-2] . $os_manager->{path_separator} . $split[@split - 1];
			$text_entry->InsertItems([$file_label],$selection);
			$text_entry->SetSelection($selection);
			$function->($self,$text_entry);
		} 
	}
}

## Probably could be more efficient.
sub Taxonomy_Prepare {

	my ($self,$sync_check) = @_;

	my @data = ();
	my @titles = ();
	for my $piedata (@{$self->{Sync_Tax}}) {
		my $taxpie = Taxonomy->from_file();
		$taxpie->Read_Taxonomy($piedata->{File});
		if ($piedata->{Is_Fill}){
			$taxpie->Get_Subtax($piedata->{Selection_String});
		}
		elsif ($piedata->{Is_Level} == 1) {
			my %level_hash = ("Order" => 1,"Family"=> 2, "Genus" => 3, "Species" => 4);
			$taxpie->Get_Level_Values($level_hash{$piedata->{Level}});
		}
		else {
			$self->SetStatusText('Please Choose Filter');
			return 0;
		}
		push(@data,$taxpie);
		push(@titles,$piedata->{Title});
	}
	if ($sync_check) {
		my $xpos = $self->GetPosition()->x;
		my $ypos = $self->GetPosition()->y;
		for (my $i = 0; $i<@data; $i++) {
			my $dataitem = [$data[$i]];
			my $title = [$titles[$i]];
			my $pie_display = PieViewer->new($dataitem,$title,$xpos + 20*$i,$ypos + 20*$i,1);
		}
	}
	else {
		my $pie_display = PieViewer->new(\@data,\@titles,-1,-1,0);
	}
}

sub Classification_Prepare {

	my ($self,$sync_check) = @_;

	my @data = ();
	my @titles = ();
	for my $piedata (@{$self->{Sync_Class}}) {
		my $classpie = OutputReader->new();
		if ($piedata->{Is_Fill}){
			$classpie->Get_Results_Selection($piedata->{File},$piedata->{Selection_String});
		}
		elsif ($piedata->{Is_Level} == 1) {
			$classpie->Get_Results_Top($piedata->{File});
		}
		else {
			$self->SetStatusText('Please Choose Filter');
			return 0;
		}
		push(@data,$classpie);
		push(@titles,$piedata->{Title});
	}
	if ($sync_check) {
		my $xpos = $self->GetPosition()->x;
		my $ypos = $self->GetPosition()->y;
		for (my $i = 0; $i<@data; $i++) {
			my $dataitem = [$data[$i]];
			my $title = [$titles[$i]];
			my $pie_display = PieViewer->new($dataitem,$title,$xpos + 20*$i,$ypos + 20*$i,1);
		}
	}
	else {
		my $pie_display = PieViewer->new(\@data,\@titles,-1,-1,0);
	}

}

sub Fill_From_File {
	my ($self,$file_box,$listbox,$other_box,$piearray) = @_;
	
	my $selection = $file_box->GetSelection;
	$piearray->[$selection]->{Is_Fill} = 1;
	$piearray->[$selection]->{Level} = "";
	
	if ($other_box) {
		$other_box->SetValue("");
	}
	$listbox->Clear;
	my $file_name = $piearray->[$selection]->{File};
	open(FILE,$file_name) or die("File Not Found");
	my @items = ();
	while(<FILE>){
		chomp;
		my $line = $_;
		my @data = split(/:/,$line);
		push(@items,$data[0]);
	}
	close FILE;
	$listbox->InsertItems(\@items,0);
	$listbox->SetSelection($piearray->[$selection]->{Fill_Selection});
}

sub Class_Level_Box {
	my ($self,$selection,$level_box,$listbox,$piearray) = @_;
	if ($level_box->GetValue == 0) {
		$piearray->[$selection]->{Is_Level} = 0;
		$piearray->[$selection]->{Level} = "";
	}
	else {
		$piearray->[$selection]->{Is_Fill} = 0;
		$listbox->Clear;
		$piearray->[$selection]->{Is_Level} = 1;
	}
}

sub Tax_Level_Box {
	my ($self,$selection,$level_box,$listbox,$piearray) = @_;
	$piearray->[$selection]->{Is_Fill} = 0;
	$listbox->Clear;
	$piearray->[$selection]->{Is_Level} = 1;
	$piearray->[$selection]->{Level} = $level_box->GetValue;
}

sub Fill_Title {
	my ($self,$selection,$title_box,$piearray) = @_;
	$piearray->[$selection]->{Title} = $title_box->GetValue;
}

## prints the contents of a taxonomy or classification output file into a listbox.
sub List_File {
	my ($self,$file_name,$listbox) = @_;
	$listbox->Clear;
	open(TEXT,$file_name) or die("File Not Found");
	my @items = ();
	while(<TEXT>){
		chomp;
		$listbox->WriteText($_ . "\n");
	}
}

sub Delete_List_Item {
	my ($self,$text,$piearray,$panel,$function) = @_;
	my $selection = $text->GetSelection;
	splice(@$piearray,$selection,1);
	$text->Delete($selection);
	my $count = $text->GetCount;
	if ($count == 0) {
		$panel->DestroyChildren;
		$panel->Refresh;
	}
	elsif ($selection == $count) {
		$text->SetSelection($selection - 1);
		$function->($self,$text);
	}
	else {
		$text->SetSelection($selection);
		$function->($self,$text);
	}
}

sub Set_Fill_Selection {
	my ($self,$selection,$listbox,$piearray) = @_;
	$piearray->[$selection]->{Fill_Selection} = $listbox->GetSelection;
	$piearray->[$selection]->{Selection_String} = $listbox->GetString($listbox->GetSelection);
}

sub Taxonomy_Menu {

	my ($self) = @_;

	$self->{Tax_Sizer} = Wx::BoxSizer->new(wxVERTICAL);
	my $tax_center_display = Wx::BoxSizer->new(wxHORIZONTAL);

	my $file_panel = Wx::Panel->new($self->{Tax_Panel},-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$file_panel->SetBackgroundColour($blue);
	my $file_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $file_title = Wx::StaticText->new($file_panel,-1,"Choose Taxonomy Output File: ");
	my $file_box = Wx::ListBox->new($file_panel,-1);
	my $fbutton_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $file_button = Wx::Button->new($file_panel,-1,"Add");
	$fbutton_sizer->Add($file_button,1,wxCENTER);
	
	$file_sizer->Add($file_title,1,wxCENTER,100);
	$file_sizer->Add($fbutton_sizer,1,wxCENTER,100);
	$file_sizer->Add($file_box,5,wxCENTER|wxEXPAND|wxBOTTOM|wxLEFT|wxRIGHT,20);
	$file_panel->Layout;
	$file_panel->SetSizer($file_sizer);
	
	$self->{Tax_Type_Panel} = Wx::Panel->new($self->{Tax_Panel},-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$self->{Tax_Type_Panel}->SetBackgroundColour($blue);
	$self->{Tax_Type_Sizer} = Wx::BoxSizer->new(wxVERTICAL);
	
	my $enter_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $check_sync = Wx::CheckBox->new($self->{Tax_Panel},-1,"View Charts Separately");
	my $gbutton_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $generate_button = Wx::Button->new($self->{Tax_Panel},-1,"Generate");
	$gbutton_sizer->Add($generate_button,1,wxCENTER,0);
	$enter_sizer->Add($check_sync,1,wxCENTER,0);
	$enter_sizer->Add($gbutton_sizer,1,wxCENTER,0);
	
	$tax_center_display->Add($file_panel,1,wxLEFT|wxCENTER|wxEXPAND|wxRIGHT,10);
	$tax_center_display->Add($self->{Tax_Type_Panel},1,wxRIGHT|wxCENTER|wxEXPAND,10);
	
	$self->{Tax_Sizer}->Add($tax_center_display,5,wxCENTER|wxEXPAND,5);
	$self->{Tax_Sizer}->Add($enter_sizer,1,wxCENTER);

	$self->{Tax_Panel}->SetSizer($self->{Tax_Sizer});
	$self->{Tax_Panel}->Layout;

	EVT_LISTBOX($self->{Tax_Panel},$file_box,sub{$self->Taxonomy_Data_Menu($file_box)});
	EVT_BUTTON($self->{Tax_Panel},$file_button,sub{$self->Open_For_Pie_Dialog($file_box,"",$self->{Tax_Type_Panel},0,1,\@{$self->{Sync_Tax}},\&PieMenu::Taxonomy_Data_Menu);});	
	EVT_BUTTON($self->{Tax_Panel},$generate_button,sub{$self->Taxonomy_Prepare($check_sync->GetValue);});
	EVT_LISTBOX_DCLICK($self->{Tax_Panel},$file_box,sub{$self->Delete_List_Item($file_box,\@{$self->{Sync_Tax}},$self->{Tax_Type_Panel},\&Display::Taxonomy_Data_Menu)});
}

sub Taxonomy_Data_Menu {
	my ($self,$file_box) = @_;
	my $selection = $file_box->GetSelection;
	$self->{Tax_Type_Sizer}->Clear;
	$self->{Tax_Type_Panel}->DestroyChildren;
	$self->{Tax_Type_Panel}->Refresh;
	$self->{Tax_Type_Panel}->SetBackgroundColour($blue);

	my $level_sizer = Wx::BoxSizer->new(wxHORIZONTAL);	
	my $tax_label = Wx::StaticText->new($self->{Tax_Type_Panel},-1,"Choose Level: ");
	my $levels = ["Order","Family","Genus","Species"];
	my $tax_box = Wx::ComboBox->new($self->{Tax_Type_Panel},-1,$self->{Sync_Tax}[$selection]->{Level},wxDefaultPosition(),wxDefaultSize(),$levels,wxCB_DROPDOWN);
	$level_sizer->Add($tax_label,1,wxCENTER|wxLEFT,20);
	$level_sizer->Add($tax_box,1,wxCENTER|wxRIGHT,20);
	
	my $or_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $or = Wx::StaticText->new($self->{Tax_Type_Panel},-1,"OR");
	$or_sizer->Add($or,1,wxCENTER);
	
	my $fill_sizer = Wx::BoxSizer->new(wxVERTICAL);	
	my $tax_fillbutton = Wx::Button->new($self->{Tax_Type_Panel},-1,"Fill");
	my $tax_listbox = Wx::ListBox->new($self->{Tax_Type_Panel},-1,wxDefaultPosition(),wxDefaultSize(),[]);
	$fill_sizer->Add($tax_fillbutton,1,wxCENTER,10);
	$fill_sizer->Add($tax_listbox,5,wxCENTER|wxEXPAND|wxTOP|wxLEFT|wxRIGHT,10);
	
	my $title_sizer = Wx::FlexGridSizer->new(1,2,10,10);
	$title_sizer->AddGrowableCol(1,2);
	my $title_label = Wx::StaticText->new($self->{Tax_Type_Panel},-1,"Chart Title: ");
	my $title_box = Wx::TextCtrl->new($self->{Tax_Type_Panel},-1,"");
	$title_box->SetValue($self->{Sync_Tax}[$selection]->{Title});
	$title_sizer->Add($title_label,1,wxLEFT|wxCENTER,20);
	$title_sizer->Add($title_box,1,wxEXPAND|wxCENTER|wxRIGHT,20);

	$self->{Tax_Type_Sizer}->Add($title_sizer,1,wxEXPAND|wxTOP,10);
	$self->{Tax_Type_Sizer}->Add($fill_sizer,3,wxCENTER|wxEXPAND,5);
	$self->{Tax_Type_Sizer}->Add($or_sizer,1,wxCENTER,5);
	$self->{Tax_Type_Sizer}->Add($level_sizer,1,wxCENTER|wxEXPAND,5);
	
	if ($self->{Sync_Tax}[$selection]->{Is_Fill} == 1) {
		$self->Fill_From_File($file_box,$tax_listbox,$tax_box,\@{$self->{Sync_Tax}});
	}
	
	$self->{Tax_Type_Panel}->SetSizer($self->{Tax_Type_Sizer});
	$self->{Tax_Type_Panel}->Layout;
	
	EVT_LISTBOX($self->{Tax_Type_Panel},$tax_listbox,sub{$self->Set_Fill_Selection($selection,$tax_listbox,\@{$self->{Sync_Tax}})});
	EVT_COMBOBOX($self->{Tax_Type_Panel},$tax_box,sub{$self->Tax_Level_Box($selection,$tax_box,$tax_listbox,\@{$self->{Sync_Tax}})});
	EVT_TEXT($self->{Tax_Type_Panel},$title_box,sub{$self->Fill_Title($selection,$title_box,\@{$self->{Sync_Tax}})});
	EVT_BUTTON($self->{Tax_Type_Panel},$tax_fillbutton,sub{$self->Fill_From_File($file_box,$tax_listbox,$tax_box,\@{$self->{Sync_Tax}})});
}

sub Classification_Menu {
	my ($self) = @_;

	my $class_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $class_center_display = Wx::BoxSizer->new(wxHORIZONTAL);

	my $file_panel = Wx::Panel->new($self->{Class_Panel},-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$file_panel->SetBackgroundColour($blue);
	my $file_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $file_title = Wx::StaticText->new($file_panel,-1,"Choose Classification Output File: ");
	my $file_box = Wx::ListBox->new($file_panel,-1);
	my $fbutton_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $file_button = Wx::Button->new($file_panel,-1,"Add");
	$fbutton_sizer->Add($file_button,1,wxCENTER);
	
	$file_sizer->Add($file_title,1,wxCENTER,100);
	$file_sizer->Add($fbutton_sizer,1,wxCENTER,100);
	$file_sizer->Add($file_box,5,wxCENTER|wxEXPAND|wxBOTTOM|wxLEFT|wxRIGHT,20);
	$file_panel->Layout;
	$file_panel->SetSizer($file_sizer);
	
	$self->{Class_Type_Panel} = Wx::Panel->new($self->{Class_Panel},-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$self->{Class_Type_Panel}->SetBackgroundColour($blue);
	$self->{Class_Type_Sizer} = Wx::BoxSizer->new(wxVERTICAL);
	
	my $enter_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $check_sync = Wx::CheckBox->new($self->{Class_Panel},-1,"View Charts Separately");
	my $gbutton_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $generate_button = Wx::Button->new($self->{Class_Panel},-1,"Generate");
	$gbutton_sizer->Add($generate_button,1,wxCENTER,0);
	$enter_sizer->Add($check_sync,1,wxCENTER,0);
	$enter_sizer->Add($gbutton_sizer,1,wxCENTER,0);
	
	$class_center_display->Add($file_panel,1,wxLEFT|wxCENTER|wxEXPAND|wxRIGHT,10);
	$class_center_display->Add($self->{Class_Type_Panel},1,wxRIGHT|wxCENTER|wxEXPAND,10);
	
	$class_sizer->Add($class_center_display,5,wxCENTER|wxEXPAND,5);
	$class_sizer->Add($enter_sizer,1,wxCENTER);

	$self->{Class_Panel}->SetSizer($class_sizer);
	$self->{Class_Panel}->Layout;
	
	EVT_LISTBOX($self->{Class_Panel},$file_box,sub{$self->Classification_Data_Menu($file_box)});
	EVT_BUTTON($self->{Class_Panel},$file_button,sub{$self->Open_For_Pie_Dialog($file_box,"",$self->{Class_Type_Panel},0,1,\@{$self->{Sync_Class}},\&PieMenu::Classification_Data_Menu);});
	EVT_BUTTON($self->{Class_Panel},$generate_button,sub{$self->Classification_Prepare($check_sync->GetValue)});
	EVT_LISTBOX_DCLICK($self->{Class_Panel},$file_box,sub{$self->Delete_List_Item($file_box,\@{$self->{Sync_Class}},$self->{Class_Type_Panel},\&PieMenu::Classification_Data_Menu)});
	
}

sub Classification_Data_Menu {
	my ($self,$file_box) = @_;
	
	my $selection = $file_box->GetSelection;
	$self->{Class_Type_Sizer}->Clear;
	$self->{Class_Type_Panel}->DestroyChildren;
	$self->{Class_Type_Panel}->Refresh;
	$self->{Class_Type_Panel}->SetBackgroundColour($blue);

	my $check_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $check_top = Wx::CheckBox->new($self->{Class_Type_Panel},-1,"Use Top Level Classifier");
	if ($self->{Sync_Class}[$selection]->{Is_Fill} == 0) {
		$check_top->SetValue(1);
		$self->{Sync_Class}[$selection]->{Is_Level} = 1;
	}
	$check_sizer->Add($check_top,1,wxCENTER|wxLEFT,20);
	
	my $or_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $or = Wx::StaticText->new($self->{Class_Type_Panel},-1,"OR");
	$or_sizer->Add($or,1,wxCENTER);
	
	my $fill_sizer = Wx::BoxSizer->new(wxVERTICAL);	
	my $class_fillbutton = Wx::Button->new($self->{Class_Type_Panel},-1,"Fill");
	my $class_listbox = Wx::ListBox->new($self->{Class_Type_Panel},-1,wxDefaultPosition(),wxDefaultSize(),[]);
	$fill_sizer->Add($class_fillbutton,1,wxCENTER,10);
	$fill_sizer->Add($class_listbox,5,wxCENTER|wxEXPAND|wxTOP|wxLEFT|wxRIGHT,10);
	
	my $title_sizer = Wx::FlexGridSizer->new(1,2,10,10);
	$title_sizer->AddGrowableCol(1,2);
	my $title_label = Wx::StaticText->new($self->{Class_Type_Panel},-1,"Chart Title: ");
	my $title_box = Wx::TextCtrl->new($self->{Class_Type_Panel},-1,"");
	$title_box->SetValue($self->{Sync_Class}->[$selection]->{Title});
	$title_sizer->Add($title_label,1,wxLEFT|wxCENTER,20);
	$title_sizer->Add($title_box,1,wxEXPAND|wxCENTER|wxRIGHT,20);

	$self->{Class_Type_Sizer}->Add($title_sizer,1,wxEXPAND|wxTOP,10);
	$self->{Class_Type_Sizer}->Add($fill_sizer,3,wxCENTER|wxEXPAND,5);
	$self->{Class_Type_Sizer}->Add($or_sizer,1,wxCENTER,5);
	$self->{Class_Type_Sizer}->Add($check_sizer,1,wxCENTER|wxEXPAND,5);
	
	if ($self->{Sync_Class}->[$selection]->{Is_Fill} == 1) {
		$self->Fill_From_File($file_box,$class_listbox,$check_top,\@{$self->{Sync_Class}});
	}
	
	$self->{Class_Type_Panel}->SetSizer($self->{Class_Type_Sizer});
	$self->{Class_Type_Panel}->Layout;
	
	EVT_LISTBOX($self->{Class_Type_Panel},$class_listbox,sub{$self->Set_Fill_Selection($selection,$class_listbox,\@{$self->{Sync_Class}})});
	EVT_CHECKBOX($self->{Class_Type_Panel},$check_top,sub{$self->Class_Level_Box($selection,$check_top,$class_listbox,\@{$self->{Sync_Class}})});
	EVT_TEXT($self->{Class_Type_Panel},$title_box,sub{$self->Fill_Title($selection,$title_box,\@{$self->{Sync_Class}})});
	EVT_BUTTON($self->{Class_Type_Panel},$class_fillbutton,sub{$self->Fill_From_File($file_box,$class_listbox,$check_top,\@{$self->{Sync_Class}})});
	
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
	$self->{CurrentProcess} = undef;
	$self->{ProcessPanel} = undef;
	$self->{PiePanel} = undef;
	$self->{ResultsPanel} = undef;
	$self->{TablePanel} = undef;
	
	$self->{Sizer}->Add($self->{Panel},1,wxGROW);
	$self->SetSizer($self->{Sizer});
	
	$self->{Tax_Panel} = undef;
	$self->{Tax_Sizer} = undef;
	$self->{Tax_Type_Panel} = undef;
	$self->{Tax_Type_Sizer} = undef;
	$self->{Class_Panel} = undef;
	$self->{Class_Sizer} = undef;
	$self->{Class_Type_Panel} = undef;
	$self->{Class_Type_Sizer} = undef;
	$self->{PieNotebook} = undef;
	$self->{Sync_Tax} = (); # array of taxonomy objects to be processed into pie charts.
	$self->{Sync_Class} = (); # array of classification objects to be processed into pie charts.
	
	$self->{ProcessNotebook} = undef;
	$self->{Processes} = (); #array
	$self->{Queue} = undef;
	
	$self->{WidgetToProcess} = (); # when a widget is updated, its associated process should be as well.
	
	$self->Centre();
	return $self;
}

sub OpenDialogSingle {
	my ($self,$text_entry,$title,$process_function) = @_;
	my $dialog = 0;
	my $file_label = "";
	$dialog = Wx::FileDialog->new($self,$title);
	if ($dialog->ShowModal==wxID_OK) {
		my @split = split($os_manager->{path_separator},$dialog->GetPath);
		$file_label = $split[@split-1];
	}
	$text_entry->SetValue($file_label);
	my $selection = $self->{ProcessNotebook}->GetSelection;
	$process_function->($self->{Processes}->[$selection],$dialog->GetPath);
}

sub DirectoryEntered {
	my ($self,$checkbox,$text_entry,$title) = @_;
	my $checkbox_value = $checkbox->GetValue;
	my $selection = $self->{ProcessNotebook}->GetSelection;
	if ($checkbox_value == 0) {
		$self->{Processes}->[$selection]->SetDirectory("",0);
		$text_entry->SetValue("");
	}
	else {
		my $dialog = 0;
		my $file_label = "";
		$dialog = Wx::DirDialog->new($self,$title);
		if ($dialog->ShowModal==wxID_OK) {
			$file_label = $dialog->GetPath;
		}
		$text_entry->SetValue($file_label);
		$self->{Processes}->[$selection]->SetDirectory($dialog->GetPath,1);
	}
}

sub TableChecked {
	my ($self,$checkbox,$textbox) = @_;
	my $value = $checkbox->GetValue;
	my $selection = $self->{ProcessNotebook}->GetSelection;
	my $name = "";
	if ($value == 1) {
		$name = $os_manager->ReadyForDB($self->{ProcessNotebook}->GetPageText($selection));
	}
	$textbox->ChangeValue($name);
	$self->{Processes}->[$selection]->SetSendTable($value,$name);
}

sub TableEntered {
	my ($self,$checkbox,$textbox) = @_;
	my $name = $textbox->GetValue;
	my $selection = $self->{ProcessNotebook}->GetSelection;
	$self->{Processes}->[$selection]->SetSendTable(1,$name);
	$checkbox->SetValue(1);
}

sub OpenDialogMultiple {
	my ($self,$text_entry,$title,$process_function) = @_;
	my $dialog = 0;
	my $file_label = "";
	$dialog = Wx::FileDialog->new($self,$title);
	if ($dialog->ShowModal==wxID_OK) {
		my @split = split($os_manager->{path_separator},$dialog->GetPath);
		$file_label = $split[@split-1];
	}
	my $selection = $text_entry->GetCount;
	$text_entry->InsertItems([$file_label],$selection);
	my $selection = $self->{ProcessNotebook}->GetSelection;
	$process_function->($self->{Processes}->[$selection],$dialog->GetPath);
}

sub AddSingleFinder {
	my ($self,$sizer,$panel,$titlelabel,$buttonlabel,$dirlabel,$process_function) = @_;
	my $item_label = Wx::StaticText->new($panel,-1,$titlelabel);
	my $item_text = Wx::TextCtrl->new($panel,-1,'',wxDefaultPosition,wxDefaultSize);
	$item_text->SetEditable(0);
	my $item_button = Wx::Button->new($panel,-1,$buttonlabel);
	$sizer->Add($item_label,1,wxCENTER,0);
	$sizer->Add($item_text,1,wxCENTER|wxEXPAND,0);
	$sizer->Add($item_button,1,wxCENTER,0);
	EVT_BUTTON($panel,$item_button,sub{$self->OpenDialogSingle($item_text,$dirlabel,$process_function);});
	return $item_text;
}

sub AddMultipleFinder {
	my ($self,$sizer,$panel,$titlelabel,$buttonlabel,$dir_label,$process_function) = @_;
	my $item_label = Wx::StaticText->new($panel,-1,$titlelabel);
	my $item_text = Wx::ListBox->new($panel,-1,wxDefaultPosition,wxDefaultSize);
	my $item_button = Wx::Button->new($panel,-1,$buttonlabel);
	$sizer->Add($item_label,1,wxBOTTOM|wxCENTER,3);
	$sizer->Add($item_text,3,wxEXPAND|wxCENTER,3);
	$sizer->Add($item_button,1,wxTOP|wxCENTER,3);
	EVT_BUTTON($panel,$item_button,sub{$self->OpenDialogMultiple($item_text,$dir_label,$process_function);});
	return $item_text;
}

sub CheckProcess {
	my ($self) = @_;
	if (not defined $self->{CurrentProcess}->{output_file} or $self->{CurrentProcess}->{output_file} eq "") {
		$self->SetStatusText("Please Choose a Blast File");
		return 0;
	}
	elsif (not defined $self->{CurrentProcess}->{fasta_file} or $self->{CurrentProcess}->{fasta_file} eq "") {
		$self->SetStatusText("Please Choose a Fasta File");
		return 0;
	}
	elsif (not defined $self->{CurrentProcess}->{outputDir} or $self->{CurrentProcess}->{outputDir} eq "") {
		$self->SetStatusText("Please Choose an Output Directory");
		return 0;
	}
	else {
		return 1;
	}
}

sub NewProcessForQueue {
	my ($self) = @_;
	if ($self->CheckProcess() == 1) {
		$self->AddProcessQueue($self->{CurrentProcess});
		$self->NewPage();
	}
	else {
		return 0;
	}
}

sub NewPage {
	my ($self) = @_;
	my $newpage = $self->NewProcessMenu();
	my $NumSelections = $self->{ProcessNotebook}->GetPageCount;
	$self->{ProcessNotebook}->AddPage($newpage,"");
	$self->{ProcessNotebook}->SetSelection($NumSelections);
}

sub AddProcessQueue {
	my ($self,$process) = @_;
	my $count = scalar(@{$self->{Processes}});
	$self->{QueueList}->InsertItems([$self->{ProcessNotebook}->GetPageText($self->{ProcessNotebook}->GetSelection)],$count-1);
}

sub RunProcessCheck {
	my ($self,$event)  = @_;
	my $processcheck = $self->CheckProcess();
	my $count = scalar(@{$self->{Processes}});
	if ($processcheck == 1) {
		$self->{QueueList}->InsertItems([$self->{ProcessNotebook}->GetPageText($self->{ProcessNotebook}->GetSelection)],$count-1);
		OkDialog->new($self,"Run Processes","$count process(es) to run. Continue?",\&Display::RunProcesses,[]);
	}
	elsif ($processcheck == 0 and scalar(@{$self->{Processes}})>1) {
		OkDialog->new($self,"Incomplete Process","There is an incomplete process. Continue?",
		\&OkDialog,[$self,"Run Processes","$count process(es) to run. Continue?",\&Display::RunProcesses,[]]);
	}
	else {
	}
}

sub RunProcesses {
	my ($self) = @_;
	for my $process(@{$self->{Processes}}) {
		$process->ProcessBlast();
	}
	$self->SetStatusText("Done Processing");
}

sub DeleteProcess {
	my ($self) = @_;
	my $selection = $self->{QueueList}->GetSelection;
	splice(@{$self->{Processes}},$selection,1);
	$self->{QueueList}->Delete($selection);
	$self->{ProcessNotebook}->RemovePage($selection);
}

# $parameters is an array with two items: the first is the widget, and the second
# is the list to remove the item from.
sub DeleteListItem {
	my ($self,$parameters) = @_;
	my $selection = $parameters->[0]->GetSelection;
	splice(@{$parameters->[1]},$selection,1);
	$parameters->[0]->Delete($selection);
}

sub DisplayProcessMenu {
	my ($self,$selection) = @_;
	$self->{ProcessNotebook}->SetSelection($selection);
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
	if (defined $self->{ProcessPanel}) {
		$self->{ProcessPanel}->Show;
	}
	else {
		
		$self->{ProcessPanel} = Wx::Panel->new($self,-1);
		my $sizer = Wx::BoxSizer->new(wxHORIZONTAL);
		
		my $splitter = Wx::SplitterWindow->new($self->{ProcessPanel},-1,wxDefaultPosition,wxDefaultSize,wxSP_3D);
	
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
		
		EVT_LISTBOX($self->{LeftPanel},$self->{QueueList},sub{$self->DisplayProcessMenu($self->{QueueList}->GetSelection)});
		EVT_LISTBOX_DCLICK($self->{LeftPanel},$self->{QueueList},sub{OkDialog->new($self,"Delete","Delete Process?",\&Display::DeleteProcess,
		[])});
		
		$self->{RightPanel} = Wx::Panel->new($splitter,-1);
		$self->{RightPanel}->SetBackgroundColour($turq);
		my $menusizer = Wx::BoxSizer->new(wxVERTICAL);
		$self->{ProcessNotebook} = Wx::Notebook->new($self->{RightPanel},-1);
		$self->{ProcessNotebook}->SetBackgroundColour($turq);
		my $page = $self->NewProcessMenu(); # Shouldn't this take ProcessPanel?
		$self->{ProcessNotebook}->AddPage($page,"");
		$self->{RightPanel}->Layout;
		
		$self->{ProcessNotebook}->Layout;
		$menusizer->Add($self->{ProcessNotebook},5,wxEXPAND);
		$self->{RightPanel}->SetSizer($menusizer);
		
		my $splitsize = ($self->GetSize()->width)/4;
		$splitter->SplitVertically($self->{LeftPanel},$self->{RightPanel},$splitsize);
	
		$sizer->Add($splitter,1,wxEXPAND);
		$self->{ProcessPanel}->SetSizer($sizer);
	}
	$self->{ProcessPanel}->Layout;
	$self->{Sizer}->Clear;
	$self->{Sizer}->Add($self->{ProcessPanel},1,wxEXPAND);
	$self->Layout;
	$self->{FileMenu}->Enable(103,1);
}

sub NewProcessMenu {

	my ($self) = @_;
	
	$self->{CurrentProcess} = ProcessDB->new($os_manager);
	push(@{$self->{Processes}},$self->{CurrentProcess});
	
	my $pagesizer_horiz = Wx::BoxSizer->new(wxHORIZONTAL);
	my $page = Wx::Panel->new($self->{ProcessNotebook},-1);
	$page->SetBackgroundColour($brown);
	
	my $pagesizer_vert = Wx::BoxSizer->new(wxVERTICAL);
	
	my $filespanel = Wx::Panel->new($page,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$filespanel->SetBackgroundColour($brown);
	my $filessizer = Wx::BoxSizer->new(wxVERTICAL);

	my $title_label = Wx::StaticText->new($filespanel,-1,"");
	$filessizer->Add($title_label,1,wxCENTER,0);
	
	my $center_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	$center_sizer->Add(Wx::BoxSizer->new(wxVERTICAL),1,wxLEFT,0);
	
	my $singles_sizer = Wx::FlexGridSizer->new(3,3,15,15);	
	$singles_sizer->AddGrowableCol(1,2);
	my $blast_widget = $self->AddSingleFinder($singles_sizer,$filespanel,'BLAST File:','Find','Choose BLAST File',\&ProcessDB::SetBlastFile);
	my $fasta_widget = $self->AddSingleFinder($singles_sizer,$filespanel,'FASTA File:','Find','Choose FASTA File',\&ProcessDB::SetFastaFile);
	
	my $multiples_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $flag_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $flag_widget = $self->AddMultipleFinder($flag_sizer,$filespanel,'Hits to Flag:','Add','Find Flag File',\&ProcessDB::SetFlag);
	$multiples_sizer->Add($flag_sizer,1,wxLEFT,15);
	my $tax_sizer =  Wx::BoxSizer->new(wxVERTICAL);
	my $tax_widget = $self->AddMultipleFinder($tax_sizer,$filespanel,'Taxonomy:','Add','Find Taxonomy File',\&ProcessDB::SetTax);
	$multiples_sizer->Add($tax_sizer,1,wxLEFT|wxRIGHT,10);
	my $class_sizer =  Wx::BoxSizer->new(wxVERTICAL);
	my $class_widget = $self->AddMultipleFinder($class_sizer,$filespanel,'Other Classification:','Add','Find Classification File',\&ProcessDB::SetClass);
	$multiples_sizer->Add($class_sizer,1,wxRIGHT,15);

	$center_sizer->Add($singles_sizer,4,wxCENTER,0);
	$center_sizer->Add(Wx::BoxSizer->new(wxVERTICAL),1,wxRIGHT,0);
	
	$filessizer->Add($center_sizer,3,wxCENTER|wxEXPAND,0);
	$filessizer->Add($multiples_sizer,3,wxCENTER|wxEXPAND,0);
	$filespanel->SetSizer($filessizer);

	EVT_TEXT($filespanel,$blast_widget,sub{$self->{ProcessNotebook}->SetPageText($self->{ProcessNotebook}->GetSelection,$blast_widget->GetValue)});
	EVT_LISTBOX_DCLICK($filespanel,$flag_widget,sub{OkDialog->new($self,"Delete","Delete Flag File?",\&Display::DeleteListItem,
		[$flag_widget,$self->{Processes}->[$self->{ProcessNotebook}->GetSelection]->{FlagFiles}])});
	EVT_LISTBOX_DCLICK($filespanel,$tax_widget,sub{OkDialog->new($self,"Delete","Delete Taxonomy File?",\&Display::DeleteListItem,
		[$tax_widget,$self->{Processes}->[$self->{ProcessNotebook}->GetSelection]->{TaxFiles}])});
	EVT_LISTBOX_DCLICK($filespanel,$class_widget,sub{OkDialog->new($self,"Delete","Delete Classification File?",\&Display::DeleteListItem,
		[$class_widget,$self->{Processes}->[$self->{ProcessNotebook}->GetSelection]->{ClassFiles}])});
	
	my $parameterspanel = $self->ParameterMenu($page);
	$parameterspanel->SetBackgroundColour($brown);
	
	my $add_panel = Wx::Panel->new($page,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$add_panel->SetBackgroundColour($brown);
	my $add_sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $send_title = Wx::StaticText->new($add_panel,-1,"Send Results To:");
	
	my $table_check = Wx::CheckBox->new($add_panel,-1,"Database Table");
	my $text_check = Wx::CheckBox->new($add_panel,-1,"Text Files");
	my $directory_title = Wx::StaticText->new($add_panel,-1,"Output Directory:");
	my $directory_widget = Wx::TextCtrl->new($add_panel,-1,"");
	my $table_title = Wx::StaticText->new($add_panel,-1,"Table Name:");
	my $table_widget = Wx::TextCtrl->new($add_panel,-1,"");
	$directory_widget->SetEditable(0);
	
	my $check_sizer = Wx::FlexGridSizer->new(2,3,20,20);
	$check_sizer->AddGrowableCol(2,1);
	$check_sizer->Add($text_check,1,wxCENTER);
	$check_sizer->Add($directory_title,1,wxCENTER);
	$check_sizer->Add($directory_widget,1,wxCENTER|wxEXPAND);
	$check_sizer->Add($table_check,1,wxCENTER);
	$check_sizer->Add($table_title,1,wxCENTER);
	$check_sizer->Add($table_widget,1,wxCENTER|wxEXPAND);
	EVT_CHECKBOX($add_panel,$text_check,sub{$self->DirectoryEntered($text_check,$directory_widget,"Choose Directory")});
	EVT_CHECKBOX($add_panel,$table_check,sub{$self->TableChecked($table_check,$table_widget)});
	EVT_TEXT($add_panel,$table_widget,sub{$self->TableEntered($table_check,$table_widget)});
	
	my $button_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $add_button = Wx::Button->new($add_panel,-1,'Queue');
	$button_sizer->Add($add_button,1,wxCENTER);
	
	$add_sizer->Add($send_title,1,wxCENTER);
	$add_sizer->Add($check_sizer,3,wxCENTER|wxEXPAND|wxLEFT|wxRIGHT,50);
	$add_sizer->Add($button_sizer,1,wxCENTER);
	
	$add_panel->SetSizer($add_sizer);
	EVT_BUTTON($add_panel,$add_button,sub{$self->NewProcessForQueue()});
	
	$pagesizer_horiz->Add($filespanel,2,wxEXPAND);
	$pagesizer_horiz->Add($parameterspanel,1,wxEXPAND);
	
	$pagesizer_vert->Add($pagesizer_horiz,3,wxEXPAND);
	$pagesizer_vert->Add($add_panel,1,wxEXPAND);
	
	$page->SetSizer($pagesizer_vert);
	
	$self->SetStatusText("");
	
	return $page;
}

sub ParameterMenu {
	my ($self,$parent) = @_;
	my $current_process = $self->{CurrentProcess};
	my $parameters = $current_process->{Parameters};
	
	my $panel = Wx::Panel->new($parent,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$panel->SetBackgroundColour($brown);
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $title_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $title = Wx::StaticText->new($panel,-1,"Parameters");
	$title_sizer->Add($title,1,wxCENTER);
	
	my $choice_wrap = Wx::BoxSizer->new(wxVERTICAL);
	$choice_wrap->Add(Wx::BoxSizer->new(wxVERTICAL),1,wxEXPAND);
	my $choice_sizer = Wx::FlexGridSizer->new(1,2,20,20);
	
	my $bit_label = Wx::StaticText->new($panel,-1,"Bit Score:");
	$choice_sizer->Add($bit_label,1,wxCENTER);
	my $bit_widget = Wx::TextCtrl->new($panel,-1,$parameters->{'bits'});
	$choice_sizer->Add($bit_widget,1,wxCENTER);
	
	$choice_wrap->Add($choice_sizer,3,wxCENTER);
	$choice_wrap->Add(Wx::BoxSizer->new(wxVERTICAL),1,wxEXPAND);
	
	$sizer->Add($title_sizer,1,wxEXPAND|wxCENTER);
	$sizer->Add($choice_wrap,5,wxEXPAND|wxCENTER);
	$panel->SetSizer($sizer);
	
	EVT_TEXT($panel,$bit_widget,sub{$current_process->SetBit($bit_widget->GetValue)});
	
	return $panel;
}

sub ResultMenu {
	my($self,$outputDir) = @_;
	
	$self->{ResultsPanel} = Wx::Panel->new($self,-1);
	
	$self->{Panel}->Hide;
	if (defined $self->{PiePanel}) {
		$self->{PiePanel}->Hide;
	}
	if (defined $self->{ProcessPanel}) {
		$self->{ProcessPanel}->Hide;
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
	if (defined $self->{ProcessPanel}) {
		$self->{ProcessPanel}->Hide;
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
	my $newblast = $self->{FileMenu}->Append(101,"New BLAST");
	my $newfasta = $self->{FileMenu}->Append(102,"New FASTA");
	$self->{FileMenu}->AppendSeparator();
	my $run = $self->{FileMenu}->Append(103,"Run Processes");
	my $close = $self->{FileMenu}->Append(104,"Quit");
	EVT_MENU($self,101,\&OnProcessClicked);
	EVT_MENU($self,103,\&RunProcessCheck);
	EVT_MENU($self,104,sub{$self->Close(1)});

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
