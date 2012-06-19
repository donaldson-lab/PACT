=head1 NAME

ResultsManager

=head1 DESCRIPTION
wxPanel 

=cut

package ResultsManager;
use Global qw($io_manager);
use Wx qw /:everything/;
use Wx::Event qw(EVT_LIST_ITEM_SELECTED);
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED);
use Wx::Event qw(EVT_LIST_COL_CLICK);
use Wx::Event qw(EVT_SIZE);
use base 'Wx::Panel';

sub new {
	my ($class,$parent) = @_;
	
	my $self = $class->SUPER::new($parent,-1);
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
	
	$self->{Sizer}->Add($self->{ResultsCtrl},1,wxEXPAND);
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
	my $table_names = $io_manager->GetTableNames();
	my $i = 0;
	for my $key(keys(%{$table_names})) {
		push(@{$self->{Keys}},$key);
		my $item = $self->{ResultsCtrl}->InsertStringItem($i,"");
		$self->{ResultsCtrl}->SetItemData($item,$i);
		$self->{ResultsCtrl}->SetItem($i,0,$table_names->{$key});
		$self->{ResultsCtrl}->SetItem($i,1,$self->GetDate($key));
		$self->{ResultsCtrl}->SetItem($i,2,"N/A");
		$i++;
	}
}

sub GetDate {
	my ($self,$key) = @_;
	
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
		$io_manager->DeleteResult($key);
	}
	$delete_dialog->Destroy;
}

1;