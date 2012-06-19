=head1 NAME

Display

=head1 DESCRIPTION
The main GUI class.

=cut

package Display;
use Global qw($database_feature $local_tax_feature $io_manager $green $blue);
use Cwd;
use QueuePanel;
use ViewTreeMenu;
use SaveTreeMenu;
use PiePanels;
use ResultsMenu;
use TableMenu;
use ErrorMessage;
use OkDialog;
use FileBox;

#use Cava::Packager;
#Cava::Packager::SetResourcePath($io_manager->{CurrentDirectory} . $io_manager->{PathSeparator} . "Resources");
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
	my ($class) = @_;

	my $self = $class->SUPER::new(undef,-1,'PACT',wxDefaultPosition,Wx::Size->new(1000,500));
	
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
	$self->SetMinSize(Wx::Size->new(1000,500));
	
	return $self;
}

### 


## Shows the selected panel and hides all others. Display data is maintained.
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

## creates the panel for generating and running parsings (See QueuePanel). Otherwise, displays the existing panel.
sub OnProcessClicked {
	my ($self,$event) = @_;
	if (not defined $self->{QueuePanel}) {
		$self->{QueuePanel} = QueuePanel->new($self);
		push(@{$self->{PanelArray}},$self->{QueuePanel});	
	}
	$self->DisplayPanel($self->{QueuePanel});
}

## creates the panel for producing taxonomy pie charts if that panel does not exist. Otherwise, displays the existing panel.
sub InitializeTaxPieMenu {
	my($self,$event) = @_;
	if (not defined $self->{TaxPiePanel}) {
		$self->{TaxPiePanel} = TaxonomyPiePanel->new($self,"Taxonomy Results","Pie Charts");
		push(@{$self->{PanelArray}},$self->{TaxPiePanel});	
	}
	$self->DisplayPanel($self->{TaxPiePanel});
}

## creates the panel for producing classification pie charts if that panel does not exist. Otherwise, displays the existing panel.
sub InitializeClassPieMenu {
	my($self,$event) = @_;
	if (not defined $self->{ClassPiePanel}) {
		$self->{ClassPiePanel} = ClassificationPiePanel->new($self,"Classification Results","Pie Charts");
		push(@{$self->{PanelArray}},$self->{ClassPiePanel});	
	}
	$self->DisplayPanel($self->{ClassPiePanel});
}

## creates or loads the existing panel for reading TaxonomyXML data from a result and saving in a new format.
sub InitializeTreeSaveMenu {
	my($self,$event) = @_;
	if (not defined $self->{TreePanel}) {
		$self->{TreePanel} = TreeMenu->new($self);
		push(@{$self->{PanelArray}},$self->{TreePanel});	
	}
	$self->DisplayPanel($self->{TreePanel});
}

## creates or loads the existing panel for viewing tree/taxonomy data. 
sub InitializeTreeViewMenu {
	my ($self,$event) = @_;
	if (not defined $self->{TreeViewPanel}) {
		$self->{TreeViewPanel} = TreeViewPanel->new($self);
		push(@{$self->{PanelArray}},$self->{TreeViewPanel});
	}
	$self->DisplayPanel($self->{TreeViewPanel});

}

## creates or loads the existing panel for choosing results stored on the database table to be view (see below).
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
	EVT_BUTTON($self->{TablePanel}->{GeneratePanel},$self->{TablePanel}->{GenerateButton},sub{$self->DisplayTable()});
}

## creates the panel for viewing the database tables of the chosen results (from TableMenu).
sub DisplayTable {
	my ($self) = @_;
	if (not defined $self->{TableDisplay}) {
		my $table_names = $self->{TablePanel}->{CompareListBox}->GetAllFiles;
		my $bit = scalar($self->{TablePanel}->{BitTextBox}->GetValue);
		my $evalue = scalar($self->{TablePanel}->{EValueTextBox}->GetValue);
		
		$self->{TableDisplay} = TableDisplay->new($self,$table_names,$bit,$evalue);
		push(@{$self->{PanelArray}},$self->{TableDisplay});	
	}
	else {
		$self->{TableDisplay}->UpdateItems();
	}
	$self->DisplayPanel($self->{TableDisplay});
	$self->{TableDisplay}->OnSize(0);
}

# creates or loads existing panel for managing the database tables of results. See ResultManager.
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

## Called when the "Update NCBI Taxonomy Files" menu item is selected. 
sub TaxonomyFileUpdater {
	my ($self,$event) = @_;
	my $update_dialog = OkDialog->new($self,"Update NCBI Taxonomy Files","New files will be downloaded from: ftp://ftp.ncbi.nih.gov/pub/taxonomy/\nProceed?");
	if ($update_dialog->ShowModal == wxID_OK) {
		$io_manager->DownloadNCBITaxonomies();
	}
	$update_dialog->Destroy;
}

## displays the contents/help manual in a new window.
sub ShowContents {
	my ($self,$event) = @_;
	my $contents_frame = Wx::Frame->new(undef,-1,"PACT Contents",[-1,-1],[-1,-1]);
	my $size = $contents_frame->GetClientSize();
	my $width = $size->GetWidth();
	my $height = $size->GetHeight();
	my $window = Wx::HtmlWindow->new($contents_frame,-1);
	$window->SetSize($width,$height);
	$window->LoadPage(Cava::Packager::GetResource('contents.html')); # $io_manager->{CurrentDirectory} . $io_manager->{PathSeparator} . 
	$contents_frame->Show();
}

## Creates all menu items
sub TopMenu {
	my ($self) = @_;

	$self->{FileMenu} = Wx::Menu->new();
	my $newblast = $self->{FileMenu}->Append(101,"Parser Menu");
	if ($database_feature==1 and $io_manager->{HasDatabase} == 1) {
		my $manage = $self->{FileMenu}->Append(102,"Manage Table Results");
		$self->{FileMenu}->AppendSeparator();
		EVT_MENU($self,102,\&InitializeResultManager);
	}
	if ($local_tax_feature == 1) {
		my $updater = $self->{FileMenu}->Append(103,"Update NCBI Taxonomy Files");
		EVT_MENU($self,103,\&TaxonomyFileUpdater);
	}
	$self->{FileMenu}->AppendSeparator();
	my $close = $self->{FileMenu}->Append(104,"Quit");
	EVT_MENU($self,101,\&OnProcessClicked);
	EVT_MENU($self,104,sub{$self->Close(1)});

	my $viewmenu = Wx::Menu->new();
	
	# if there is no installed SQLite, then the table option is hidden
	if ($database_feature==1 and $io_manager->{HasDatabase} == 1) {
		my $table = $viewmenu->Append(201,"Table");
		EVT_MENU($self,201,\&InitializeTableViewer);
	}
	my $pie = Wx::Menu->new();
	$viewmenu->AppendSubMenu($pie,"Pie Charts");
	$pie->Append(202,"Taxonomy");
	$pie->Append(203,"Classification");
	my $tax = $viewmenu->Append(204,"Tree");
	my $save_trees = $viewmenu->Append(205,"Save Trees");
	EVT_MENU($self,202,\&InitializeTaxPieMenu);
	EVT_MENU($self,203,\&InitializeClassPieMenu);
	EVT_MENU($self,204,\&InitializeTreeViewMenu);
	EVT_MENU($self,205,\&InitializeTreeSaveMenu);
	
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
}

1;