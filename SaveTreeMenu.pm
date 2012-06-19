use FileBox;


package TreeMenu;
use Global qw($io_manager $green $blue);
use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use Wx::Event qw(EVT_LISTBOX_DCLICK);
use base 'Wx::Panel';
use Cwd;
use Fcntl;
use Bio::TreeIO::nhx;
use Bio::TreeIO::newick;

sub new {
	my ($class,$parent) = @_;
	
	my $self = $class->SUPER::new($parent,-1);
	$self->SetBackgroundColour($green);
	$self->{TreeFileListBox} = undef;
	$self->{TreeListBox} = undef;
	$self->{TreeFormats} = {"Newick"=>"newick","PhyloXML"=>"phyloxml"};
	bless ($self,$class);
	$self->TreeBox();
	return $self;
}

sub TreeBox {
	my ($self) = @_;
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $center_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	
	my $file_panel = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$file_panel->SetBackgroundColour($blue);
	my $file_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	
	my $file_list_label = Wx::StaticBox->new($file_panel,-1,"Save tree file or merge files:");
	my $file_list_label_sizer = Wx::StaticBoxSizer->new($file_list_label,wxVERTICAL);
	my $browse_button_sizer_outer = Wx::BoxSizer->new(wxVERTICAL);
	my $browse_button_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $browse_button = Wx::Button->new($file_panel,-1,"Browse");
	$browse_button_sizer->Add($browse_button,1,wxCENTER);
	$browse_button_sizer_outer->Add($browse_button_sizer,1,wxCENTER);
	
	$self->{TreeFileListBox} = FileBox->new($file_panel);
	$file_list_label_sizer->Add($browse_button_sizer_outer,1,wxCENTER);
	$file_list_label_sizer->Add($self->{TreeFileListBox}->{ListBox},7,wxEXPAND);
	
	$file_sizer->Add($file_list_label_sizer,3,wxCENTER|wxEXPAND);
	$file_panel->Layout;
	$file_panel->SetSizer($file_sizer);
	
	my $choice_panel = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$choice_panel->SetBackgroundColour($blue);
	my $choice_panel_sizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $title_view_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $title_label = Wx::StaticBox->new($choice_panel,-1,"Title");
	my $title_label_sizer = Wx::StaticBoxSizer->new($title_label,wxHORIZONTAL);
	$self->{TitleBox} = Wx::TextCtrl->new($choice_panel,-1,"");
	$title_label_sizer->Add($self->{TitleBox},1,wxEXPAND);
	$title_view_sizer->Add($title_label_sizer,1,wxCENTER);

	my $f_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $f_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $format_label = Wx::StaticBox->new($choice_panel,-1,"File format:");
	my $format_sizer = Wx::StaticBoxSizer->new($format_label,wxVERTICAL);
	my @formats = keys(%{$self->{TreeFormats}});
	$self->{FormatChoice} = Wx::ComboBox->new($choice_panel,-1,"",wxDefaultPosition(),wxDefaultSize(),\@formats,wxCB_DROPDOWN);
	$format_sizer->Add($self->{FormatChoice},1,wxEXPAND);
	$f_sizer_v->Add($format_sizer,1,wxCENTER);
	$f_sizer_h->Add($f_sizer_v,1,wxCENTER);
	my $button_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	my $button_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $save_button = Wx::Button->new($self,-1,"Save");
	$button_sizer_v->Add($save_button,1,wxCENTER);
	$button_sizer_h->Add($button_sizer_v,1,wxCENTER);

	$choice_panel_sizer->Add($title_label_sizer,1,wxEXPAND);
	$choice_panel_sizer->Add($f_sizer_h,5,wxEXPAND|wxCENTER);
	$choice_panel->SetSizer($choice_panel_sizer);
	
	$center_sizer->Add($file_panel,1,wxEXPAND);
	$center_sizer->Add($choice_panel,1,wxEXPAND);
	
	$sizer->Add($center_sizer,8,wxEXPAND|wxLEFT|wxRIGHT|wxTOP|wxBOTTOM,10);
	$sizer->Add($button_sizer_h,1,wxCENTER);
	$self->SetSizer($sizer);

	EVT_BUTTON($self,$browse_button,sub{$self->LoadFile()});
	EVT_BUTTON($self,$save_button,sub{$self->SaveTree()});
	
	$self->Layout;
}

sub LoadFile {
	my ($self) = @_;
	my $dialog = 0;
	my $file_label = "";
	$dialog = Wx::FileDialog->new($self,"Choose Results");
	if ($dialog->ShowModal==wxID_OK) {
		# test to see if phyloxml
		my @split = split("\\" . $io_manager->{PathSeparator},$dialog->GetPath);
		$file_label = $split[@split - 1];
		$self->{TreeFileListBox}->AddFile($dialog->GetPath,$file_label);
		$self->{TreeFileListBox}->{ListBox}->SetSelection($self->{TreeFileListBox}->{ListBox}->GetCount - 1);
	}
	
}

sub SaveTree {
	my ($self) = @_;
	if ($self->{TreeFileListBox}->{ListBox}->GetCount == 0) {
		return 0;
	}
	my $save_dialog = Wx::FileDialog->new($self,"","","","*.*",wxFD_SAVE);
	if ($save_dialog->ShowModal == wxID_OK) {
		my $files = $self->{TreeFileListBox}->GetAllFiles();
		my $combiner = TreeCombiner->new();
		my ($tree,$data) = $combiner->CombineTrees($files);
		
		my $format = $self->{TreeFormats}->{$self->{FormatChoice}->GetValue};
		if ($format eq "") {
			$format = "newick";
		}
		
		my $helper = TaxonomyXML->new();
		if ($format eq "newick") {
			for my $node($tree->get_nodes) {
				$node->id($helper->GetName($node));
			}
			
			open(my $handle, ">>" . $save_dialog->GetPath());
			my $treeio = Bio::TreeIO->new(-format => 'newick',-fh => $handle);
			$treeio->write_tree($tree);
		}
		elsif ($format eq "phyloxml") {
			$helper->SaveTreePhylo($tree,$data,$self->{TitleBox}->GetValue,$save_dialog->GetPath());
		}
		elsif ($format eq "nhx") {
			#not implemented
			open(my $handle, ">>" . $save_dialog->GetPath());
			my $treeio = Bio::TreeIO->new(-format => 'nhx',-fh => $handle);
			$treeio->write_tree($tree);
		}
		else {
			
		}
	}
	$save_dialog->Destroy;
}

1;