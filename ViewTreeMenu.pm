package TreeViewPanel;
use Global qw($green);
use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use Wx::Event qw(EVT_TEXT);
use Wx::Event qw(EVT_CHECKBOX);
use Wx::Event qw(EVT_COMBOBOX);
use Wx::Event qw(EVT_LISTBOX);
use Wx::Event qw(EVT_LISTBOX_DCLICK);

use TreeCombiner;
use PiePanels;
use FileBox;
use base ("TaxonomyPiePanel");

sub new {
	my ($class,$parent) = @_;
	my $self = $class->SUPER::new($parent,"Taxonomy Results","Taxonomies to View");
	return $self;
}

sub MainDisplay {
	my ($self,$label) = @_;

	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	$self->CenterDisplay($label);
	
	$self->{GeneratePanel} = Wx::Panel->new($self,-1);
	$self->{GeneratePanel}->SetBackgroundColour($green);
	
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
	my $save_dialog = Wx::FileDialog->new($self,"","","","*.*",wxFD_SAVE);
	if ($save_dialog->ShowModal == wxID_OK) {
		my $files = $self->{FileBox}->GetAllFiles();
		my $combiner = TreeCombiner->new();
		my ($tree,$data) = $combiner->CombineTrees($files);
		my $tax_xml = TaxonomyXML->new();
		my $sub_node_name = $self->{TypePanel}->{NodeBox}->GetStringSelection;
		my $rank = $self->{TypePanel}->{RankBox}->GetValue;
		$tax_xml->PrintSummaryText($tree,$data,$sub_node_name,$rank,$save_dialog->GetDirectory,$save_dialog->GetPath);
	}
	$save_dialog->Destroy;
}

1;