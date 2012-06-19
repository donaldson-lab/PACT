use PieViewer;
use FileBox;
use OkDialog;

=head1 NAME

ClassificationTypePanel

=head1 DESCRIPTION
In ClassificationPiePanel (its parent), this is the panel that displays choices of attributes
by which to select classification data to be displayed (by pie chart, for example).
=cut

package ClassificationTypePanel;

use ClassificationXML;

use Global qw($blue);
use Wx;
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

# set up the panel display. Implementation specific
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

# fill the classifier attribute ListBox  
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

# 
sub CopyData {
	my ($self,$panel) = @_;
	$self->{DataReader} = $panel->{DataReader};
	$self->{TitleBox}->SetValue($panel->{TitleBox}->GetValue);
	$self->{ClassifierBox}->SetSelection($panel->{ClassifierBox}->GetSelection);
}

=head1 NAME

ClassificationPiePanel

=head1 DESCRIPTION
Provides a template for a panel to view the results of a classification search (ie, through pie charts).
Provides uniformity in appearance in all such panels. There is a ListBox on the left for results to
choose from, a middle section for selecting attributes to narrow the data set (see Classification), and a ListBox on the right 
for showing the results to be combined. This is also a base class for TaxonomyPiePanel. 
=cut

package ClassificationPiePanel;

use Global qw($io_manager $green $blue);
use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use Wx::Event qw(EVT_TEXT);
use Wx::Event qw(EVT_CHECKBOX);
use Wx::Event qw(EVT_COMBOBOX);
use Wx::Event qw(EVT_LISTBOX);
use Wx::Event qw(EVT_LISTBOX_DCLICK);

use base 'Wx::Panel';
use Fcntl;

sub new {
	my ($class,$parent,$file_label,$group_label) = @_;
	
	my $self = $class->SUPER::new($parent,-1);
	$self->SetBackgroundColour($green);
	
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
	$self->{GeneratePanel}->SetBackgroundColour($green);
	
	my $gbutton_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $gbutton_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	$self->{GenerateButton} = Wx::Button->new($self->{GeneratePanel},-1,"Generate");
	$gbutton_sizer_v->Add($self->{GenerateButton},1,wxCENTER);
	$gbutton_sizer_h->Add($gbutton_sizer_v,1,wxCENTER);
	$self->{GeneratePanel}->SetSizer($gbutton_sizer_h);
	
	$sizer->Add($self->{CenterDisplay},7,wxEXPAND);
	$sizer->Add($self->{GeneratePanel},1,wxEXPAND);
	
	$self->SetSizer($sizer);

	$self->Layout;
	
	EVT_BUTTON($self->{GeneratePanel},$self->{GenerateButton},sub{$self->GenerateCharts()});
}

sub CenterDisplay {

	my ($self) = @_;

	$self->{CenterDisplay} = Wx::BoxSizer->new(wxHORIZONTAL);

	$self->{FilePanel} = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$self->{FilePanel}->SetBackgroundColour($blue);
	my $file_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	
	$self->{ItemListLabel} = Wx::StaticBox->new($self->{FilePanel},-1,$self->{FileLabel});
	$self->{ItemListLabelSizer} = Wx::StaticBoxSizer->new($self->{ItemListLabel},wxVERTICAL);
	my $browse_button_sizer_outer = Wx::BoxSizer->new(wxVERTICAL);
	my $browse_button_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{BrowseButton} = Wx::Button->new($self->{FilePanel},-1,"Browse");
	$browse_button_sizer->Add($self->{BrowseButton},1,wxCENTER);
	$browse_button_sizer_outer->Add($browse_button_sizer,1,wxCENTER);
	$self->{FileBox} = FileBox->new($self->{FilePanel});
	$self->{ItemListLabelSizer}->Add($browse_button_sizer_outer,1,wxCENTER);
	$self->{ItemListLabelSizer}->Add($self->{FileBox}->{ListBox},7,wxEXPAND);
	
	$file_sizer->Add($self->{ItemListLabelSizer},3,wxCENTER|wxEXPAND);
	$self->{FilePanel}->Layout;
	$self->{FilePanel}->SetSizer($file_sizer);
	
	$self->{ButtonsSizer} = Wx::BoxSizer->new(wxHORIZONTAL);
	my $chart_button_sizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{AddButton} = Wx::Button->new($self,-1,"Add");
	$self->{RemoveButton} = Wx::Button->new($self,-1,"Remove");
	$chart_button_sizer->Add($self->{AddButton},1,wxCENTER|wxBOTTOM,10);
	$chart_button_sizer->Add($self->{RemoveButton},1,wxCENTER|wxTOP,10);
	$self->{ButtonsSizer}->Add($chart_button_sizer,1,wxCENTER);
	
	$self->{EmptyPanel} = $self->NewTypePanel();
	$self->{TypePanel} = $self->{EmptyPanel};
	
	$self->{ChartPanel} = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$self->{ChartPanel}->SetBackgroundColour($blue);
	my $chart_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	
	my $chart_list_label = Wx::StaticBox->new($self->{ChartPanel},-1,$self->{GroupLabel});
	my $chart_list_label_sizer = Wx::StaticBoxSizer->new($chart_list_label,wxVERTICAL);
	$self->{ChartBox} = FileBox->new($self->{ChartPanel});
	$chart_list_label_sizer->Add($self->{ChartBox}->{ListBox},1,wxEXPAND);
	
	$chart_sizer->Add($chart_list_label_sizer,3,wxCENTER|wxEXPAND);
	$self->{ChartPanel}->Layout;
	$self->{ChartPanel}->SetSizer($chart_sizer);
	
	$self->{CenterDisplay}->Add($self->{FilePanel},3,wxTOP|wxCENTER|wxEXPAND|wxBOTTOM,10);
	$self->{CenterDisplay}->Add($self->{TypePanel},5,wxTOP|wxBOTTOM|wxCENTER|wxEXPAND,10);
	$self->{CenterDisplay}->Add($self->{ButtonsSizer},1,wxCENTER|wxEXPAND,10);
	$self->{CenterDisplay}->Add($self->{ChartPanel},3,wxTOP|wxCENTER|wxEXPAND|wxBOTTOM,10);
	
	EVT_LISTBOX($self,$self->{FileBox}->{ListBox},sub{$self->DisplayNew(); $self->{ChartBox}->{ListBox}->SetSelection(-1);});
	EVT_LISTBOX($self,$self->{ChartBox}->{ListBox},sub{$self->DisplayPiePanel();});
	EVT_BUTTON($self,$self->{BrowseButton},sub{$self->LoadFile()});
	EVT_BUTTON($self,$self->{AddButton},sub{$self->AddPieChart();});
	EVT_BUTTON($self,$self->{RemoveButton},sub{$self->DeleteChart();});
}

# 
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
		my @split = split("\\" . $io_manager->{PathSeparator},$dialog->GetPath);
		$file_label = $split[@split - 1];
		$self->{FileBox}->AddFile($dialog->GetPath,$file_label);
		$self->{FileBox}->{ListBox}->SetSelection($self->{FileBox}->{ListBox}->GetCount - 1);
		$self->DisplayNew();
	}
	
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
	my $label = $pie_panel->{DataReader}->{Title};
		
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
		PieViewer->new($chart_data->[0],$chart_data->[1],$chart_data->[2],-1,-1,$io_manager);
	}
	else {
	}
}

=head1 NAME

TaxonomyTypePanel

=head1 DESCRIPTION

This is the attribute selection panel for TaxonomyPiePanel (similar to ClassificationTypePanel).
Allows users to select the taxonomy data by root, rank, etc.

=cut

package TaxonomyTypePanel;

use Global qw($io_manager $green $blue);
use TaxonomyXML;
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
		my $names = $io_manager->GetTaxonomyNodeNames($tax_file);
		my $ranks = $io_manager->GetTaxonomyNodeRanks($tax_file);
		my $seqids = $io_manager->GetTaxonomyNodeIds($tax_file);
		my $values = $io_manager->GetTaxonomyNodeValues($tax_file);
		$self->{DataReader} = TaxonomyData->new($tax_file,$names,$ranks,$seqids,$values);
	}
	elsif ($tax_file ne "") {
		$self->{DataReader} = TaxonomyXML->new($tax_file);
		$self->{DataReader}->AddFile($tax_file);
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
	if (defined $panel->{TitleBox}) {
		$self->{TitleBox}->SetValue($panel->{TitleBox}->GetValue);
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

=head1 NAME

TaxonomyTypePanelTitle

=head1 DESCRIPTION
Just like TaxonomyTypePanel, but implements a title box (wxTextCtrl).
=cut

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

package TaxonomyPiePanel;
use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use Wx::Event qw(EVT_TEXT);
use Wx::Event qw(EVT_CHECKBOX);
use Wx::Event qw(EVT_COMBOBOX);
use Wx::Event qw(EVT_LISTBOX);
use Wx::Event qw(EVT_LISTBOX_DCLICK);
use Fcntl;

use base ("ClassificationPiePanel");

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
	my $label = $pie_panel->{DataReader}->{Title};
		
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

1;