use OkDialog;
package QueuePanel;
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
use ParserPanel;
use Parser;

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
	$self->SetBackgroundColour($green);
	
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
	$self->{GeneratePanel}->SetBackgroundColour($green);
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
	$self->{QueuePanel}->SetBackgroundColour($green);
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
	my $check = $page->CheckProcess();
	
	if ($check == 1) {
		$self->AddProcessQueue();
		return 1;
	}
	
	
	if ($check == 0) {
		my $dialog = Wx::MessageDialog->new($self->GetParent,"","Please Choose a Parsing Name","");
		#$dialog->SetBackgroundColour($green);
		#$dialog->CenterOnParent();
		$dialog->ShowModal;
		return 0;	
	}
	elsif ($check == -1) {
		my $dialog = Wx::MessageDialog->new($self->GetParent,"","Please Choose a BLAST Output File","");
		$dialog->SetBackgroundColour($green);
		$dialog->Centre();
		$dialog->ShowModal;
		return 0;	
	}
	elsif ($check == -2) {
		my $dialog = Wx::MessageDialog->new($self->GetParent,"","Please Choose a FASTA File","");
		$dialog->SetBackgroundColour($green);
		$dialog->CenterOnParent();
		$dialog->ShowModal;
		return 0;	
	}
	elsif ($check == -3) {
		my $dialog = Wx::MessageDialog->new($self->GetParent,"","Please Choose an Output Directory","");
		$dialog->SetBackgroundColour($green);
		$dialog->CenterOnParent();
		$dialog->ShowModal;
		return 0;
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
	my $queue_panel = ParserPanel->new($self,$io_manager);
	$queue_panel->CopyData($self->{ParserPanel});
	$queue_panel->Hide;
	push(@{$self->{QueuedPanels}},$queue_panel);
	EVT_TEXT($queue_panel,$queue_panel->{ParserNameTextCtrl},sub{$self->{QueueList}->SetString($self->{QueueList}->GetSelection,$queue_panel->{ParserNameTextCtrl}->GetValue);});
}

sub GenerateParser {
	my ($self,$page) = @_;
	
	my $parser = BlastParser->new($io_manager,$page->{ParserNameTextCtrl}->GetValue,$page->{OutputDirectoryPath});
	$parser->SetBlastFile($page->{BlastFilePath});
	$parser->SetSequenceFile($page->{FastaFilePath});
	$parser->SetParameters($page->{BitTextBox}->GetValue,$page->{EValueTextBox}->GetValue);
	
	if (defined $page->{TableCheck} and $page->{TableCheck}->GetValue==1) {
		my $table_key = $io_manager->AddTableName($page->{ParserNameTextCtrl}->GetValue);
		my $table = SendTable->new($io_manager,$table_key);
		$parser->AddProcess($table);
	}

	my $taxonomy;
	if ($page->{TaxSource} ne "") {
		my @ranks = ();
		my @roots = ();
		if ($roots_feature == 1) {
			@roots = $page->{RootList}->GetStrings;
		}
		# check if internet connection is available
		if ($page->{TaxSource} eq "Connection") {
			$taxonomy = ConnectionTaxonomy->new(\@ranks,\@roots,$io_manager);
		}
		else {
			## Check first to see if NCBI taxonomies are there in the taxdump folder
			if ($io_manager->CheckTaxDump()==1) {
				$taxonomy = FlatFileTaxonomy->new($io_manager->{NodesFile},$io_manager->{NamesFile},\@ranks,\@roots,$io_manager);
			}
			else {
				## if not, ask to download them.
				my $download_dialog = OkDialog->new($self->GetParent(),"Taxonomy files not found","Download NCBI taxonomy files?");
				if ($download_dialog->ShowModal == wxID_OK) {
					$io_manager->DownloadNCBITaxonomies();
				}
			}
		}
	}
	
	my @classes = ();
	my @flags = ();
	my $class_files = $page->{ClassBox}->GetAllFiles;
	my $flag_files = $page->{FlagBox}->GetAllFiles;
	for my $class_file(@$class_files) {
		my $class = Classification->new($class_file,$io_manager);
		push(@classes,$class);
	}
	for my $flag_file (@$flag_files) {
		my $flag = FlagItems->new($page->{OutputDirectoryPath},$flag_file,$io_manager);
		push(@flags,$flag);
	}
	
	for my $class(@classes) {
		$parser->AddProcess($class);
	}
	for my $flag(@flags) {
		$parser->AddProcess($flag);
	}
	
	if ($page->{TextCheck}->GetValue == 1) {
		my $text;
		if (defined $taxonomy) {
			$text = TaxonomyTextPrinter->new($page->{OutputDirectoryPath},$taxonomy,$io_manager);
		}
		else {
			$text = TextPrinter->new($page->{OutputDirectoryPath},$io_manager);
		}
		$parser->AddProcess($text);
	}
	else {
		$parser->AddProcess($taxonomy) unless not defined $taxonomy;
	}
	
	push(@{$self->{Parsers}},$parser);
}

# loops through each parsing, the most important task!
sub RunParsers {
	my ($self) = @_;
	
	my $progress_dialog = Wx::ProgressDialog->new("","",100,$self,wxSTAY_ON_TOP|wxPD_APP_MODAL);
	$progress_dialog->Centre();
	for my $parser(@{$self->{Parsers}}) {
		$parser->prepare(); # sets up the folders, counts sequences
		my @label_strings = split("\\" . $io_manager->{PathSeparator},$parser->{BlastFile});
		my $label = $label_strings[@label_strings - 1];
		$progress_dialog->Update(-1,"Parsing " . $label . " ...");
		$progress_dialog->Fit();
		$parser->Parse($progress_dialog);
		# delete parser?
	}
	$progress_dialog->Destroy;
}

# 
sub Run {
	my ($self) = @_;
	$self->{Parsers} = ();
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
	}
}

1;