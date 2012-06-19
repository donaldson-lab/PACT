# Global colors
package ParserPanel;

use Global qw($io_manager $green $blue);
use Wx;
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
use OkDialog;

sub new {
	my ($class,$parent) = @_;
	
	my $self = $class->SUPER::new($parent,-1);
	$self->SetBackgroundColour($green);

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
	$self->{SourceCombo} = undef; #CheckBox
	$self->{TaxCheck} = undef;
	
	$self->{TaxSource} = "";
	
	bless ($self,$class);
	$self->ParserPanel();
	$self->Layout;
	return $self;
}

sub DirectoryButton {
	my ($self,$title) = @_;
	my $dialog = 0;
	my $file_label = "";
	my $path = "";
	$dialog = Wx::DirDialog->new($self,$title);
	if ($dialog->ShowModal==wxID_OK) {
		$path = $dialog->GetPath;
		my @split = split("\\" . $io_manager->{PathSeparator},$path);
		$file_label = $split[@split-2] . $io_manager->{PathSeparator} . $split[@split - 1];
		$self->{OutputDirectoryPath} = $path;
		$self->{DirectoryTextBox}->SetValue($file_label);
	}
}

sub OpenDialogSingle {
	my ($self,$text_entry,$title) = @_;
	my $dialog = 0;
	my $file_label = "";
	$dialog = Wx::FileDialog->new($self,$title);
	if ($dialog->ShowModal==wxID_OK) {
		my @split = split("\\" . $io_manager->{PathSeparator},$dialog->GetPath);
		$file_label = $split[@split-1];
		$text_entry->SetValue($file_label);
		return $dialog->GetPath;
	}
}

sub OpenDialogMultiple {
	my ($self,$title,$filebox) = @_;
	my $dialog = 0;
	my $file_label = "";
	$dialog = Wx::FileDialog->new($self,$title);
	if ($dialog->ShowModal==wxID_OK) {
		my @split = split("\\" . $io_manager->{PathSeparator},$dialog->GetPath);
		for (my $i=@split - 1; $i>0; $i--) {
			if ($i==@split - 2) {
				$file_label = $split[$i] . $io_manager->{PathSeparator} . $file_label;
				last;
			}
			$file_label = $split[$i] . $file_label;
		}
		$filebox->AddFile($dialog->GetPath,$file_label);
	}
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
	elsif ($self->{OutputDirectoryPath} eq "") {
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
	
	$self->{OptionsNotebook} = Wx::Notebook->new($self,-1);
	$self->{OptionsNotebook}->SetBackgroundColour($green);
	
	my $filespanel = $self->InputFilesMenu();
	my $classificationpanel = $self->ClassificationMenu();
	my $parameterspanel = $self->ParameterMenu();
	my $add_panel = $self->OutputMenu();
	
	$self->{OptionsNotebook}->AddPage($filespanel,"Input Files");
	$self->{OptionsNotebook}->AddPage($classificationpanel,"Classifications");
	
	if ($local_tax_feature == 1) {
		my $taxonomypanel = $self->TaxonomyMenu();
		$self->{OptionsNotebook}->AddPage($taxonomypanel,"NCBI Taxonomy");
	}
	$self->{OptionsNotebook}->AddPage($parameterspanel,"Parameters");
	$self->{OptionsNotebook}->AddPage($add_panel,"Output");
	
	$self->{OptionsNotebook}->Layout;
	
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
	
	EVT_LISTBOX_DCLICK($classificationpanel,$self->{FlagBox}->{ListBox},sub{$self->DeleteClassItem($self->{FlagBox},"Delete Flag File?")});
	EVT_LISTBOX_DCLICK($classificationpanel,$self->{ClassBox}->{ListBox},sub{$self->DeleteClassItem($self->{ClassBox},"Delete Classification File?")});
	return $classificationpanel;
}

sub DeleteClassItem {
	my ($self,$box,$message) = @_;

	my $parent = $self->GetParent();
	while (defined $parent->GetParent) {
		$parent = $parent->GetParent;
	}

	my $delete_dialog = OkDialog->new($parent,"Delete",$message);

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
	
	my $source_outer_sizer = Wx::BoxSizer->new(wxVERTICAL);
	my $source_label = Wx::StaticBox->new($tax_panel,-1,"Source");
	my $source_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $source_label_sizer = Wx::StaticBoxSizer->new($source_label,wxHORIZONTAL);
	$self->{SourceCombo} = Wx::ComboBox->new($tax_panel,-1,"",wxDefaultPosition,wxDefaultSize,["","Connection","Local Files"]);
	$self->{SourceCombo}->SetValue("");
	$source_label_sizer->Add($self->{SourceCombo},1,wxCENTER);
	$source_sizer->Add($source_label_sizer,3,wxCENTER);
	$source_outer_sizer->Add($source_sizer,1,wxCENTER);
	
	$sizer->Add($source_outer_sizer,1,wxEXPAND);
	if ($roots_feature == 1) {
		my $root_sizers = $self->RootOptions($tax_panel);
		my $root_sizer = $root_sizers->[0];
		my $clear_sizer_outer = $root_sizers->[1];
		$sizer->Add($root_sizer,3,wxEXPAND);
		$sizer->Add($clear_sizer_outer,1,wxEXPAND);
	}
	$tax_panel->SetSizer($sizer);

	return $tax_panel;
}

# For specifying the roots to be counted in a taxonomy search. Not used in first addition. 
sub RootOptions {
	my ($self,$tax_panel) = @_;
	
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
	
	Evt_COMBOBOX($tax_panel,$self->{SourceCombo},sub{$self->{TaxSource} = $self->{SourceCombo}->GetValue;});
	EVT_BUTTON($tax_panel,$clear_button,sub{$self->{RootList}->Clear;$self->{SourceCombo}->SetValue("");});
	
	return [$root_sizer,$clear_sizer_outer];
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
	
	my @sizer_items = ();
	
	my $directory_label = Wx::StaticBox->new($add_panel,-1,"Output Directory:");
	my $directory_label_sizer = Wx::StaticBoxSizer->new($directory_label,wxHORIZONTAL);
	$self->{DirectoryTextBox} = Wx::TextCtrl->new($add_panel,-1,"");
	$self->{DirectoryTextBox}->SetEditable(0);
	$self->{DirectoryButton} = Wx::Button->new($add_panel,-1,"Browse");
	my $dir_sizer = Wx::FlexGridSizer->new(1,3,20,20);
	$dir_sizer->AddGrowableCol(1,1);
	$dir_sizer->Add($self->{DirectoryButton},1,wxCENTER);
	$dir_sizer->Add($self->{DirectoryTextBox},1,wxCENTER|wxEXPAND);
	$directory_label_sizer->Add($dir_sizer,1,wxEXPAND);
	push(@sizer_items,$directory_label_sizer);
	
	my $text_label = Wx::StaticBox->new($add_panel,-1,"Text Files");
	my $text_label_sizer = Wx::StaticBoxSizer->new($text_label,wxHORIZONTAL);
	my $text_check_sizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{TextCheck} = Wx::CheckBox->new($add_panel,-1,"Yes");
	$text_check_sizer->Add($self->{TextCheck},1,wxCENTER);
	$text_label_sizer->Add($text_check_sizer,1,wxEXPAND);
	push(@sizer_items,$text_label_sizer);
	
	EVT_BUTTON($add_panel,$self->{DirectoryButton},sub{$self->DirectoryButton("Choose Directory")});
	
	# perhaps there should be a separate derived panel for the no database case.
	if ($has_database == 1 and $database_feature == 1) {
		my $table_label = Wx::StaticBox->new($add_panel,-1,"Add to Database?");
		my $table_label_sizer = Wx::StaticBoxSizer->new($table_label,wxHORIZONTAL);
		my $check_sizer = Wx::BoxSizer->new(wxVERTICAL);
		$self->{TableCheck} = Wx::CheckBox->new($add_panel,-1,"Yes");
		$check_sizer->Add($self->{TableCheck},1,wxCENTER);
		$table_label_sizer->Add($check_sizer,1,wxEXPAND);
		push(@sizer_items,$table_label_sizer);
	}
	if ($local_tax_feature == 0) {
		my $tax_label = Wx::StaticBox->new($add_panel,-1,"NCBI Taxonomy Folders?");
		my $tax_label_sizer = Wx::StaticBoxSizer->new($tax_label,wxHORIZONTAL);
		my $check_sizer = Wx::BoxSizer->new(wxVERTICAL);
		$self->{TaxCheck} = Wx::CheckBox->new($add_panel,-1,"Yes");
		$check_sizer->Add($self->{TaxCheck},1,wxCENTER);
		$tax_label_sizer->Add($check_sizer,1,wxEXPAND);
		EVT_CHECKBOX($self,$self->{TaxCheck},sub{$self->{TaxSource} = "Connection";});
		push(@sizer_items,$tax_label_sizer);
	}
	
	for my $item(@sizer_items) {
		$add_sizer_v->Add($item,1,wxCENTER|wxEXPAND|wxLEFT|wxRIGHT,50);
	}
	
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
	$self->{TextCheck}->SetValue($parser_panel->{TextCheck}->GetValue());
	if  (defined $self->{TableCheck}) {
		$self->{TableCheck}->SetValue($parser_panel->{TableCheck}->GetValue());	
	}
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

	if (defined $parser_panel->{RootList} and $roots_feature == 1) {
		my @roots = ();
		for (my $i=0; $i<$parser_panel->{RootList}->GetCount; $i++) {
			push(@roots,$parser_panel->{RootList}->GetString($i));
		}
		$self->{RootList}->Set(\@roots);
	}
	
	if ($local_tax_feature == 1) {
		if (defined $self->{SourceCombo}) {
			$self->{SourceCombo}->SetValue($parser_panel->{SourceCombo}->GetValue);
		}
	}
	else {
		if (defined $self->{TaxCheck}) {
			$self->{TaxCheck}->SetValue($parser_panel->{TaxCheck}->GetValue);
			$self->{TaxSource} = $parser_panel->{TaxSource};
		}
	}
}

1;