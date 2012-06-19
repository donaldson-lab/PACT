=head1 NAME

QueryTextDisplay

=head1 SYNOPSIS

my $query_display = QueryTextDisplay->new($panel);

=head1 DESCRIPTION
A wxPanel that displays (via html) the descriptive information of the hit associated
with the query.
=cut

package QueryTextDisplay;

use Wx qw /:everything/;
use Wx::Event qw(EVT_SIZE);
use Wx::Event qw(EVT_PAINT);
use Wx::Html;
use base 'Wx::Panel';

sub new {
	my ($class,$parent) = @_;
	my $self = $class->SUPER::new($parent,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$self->{Query} = "";
	$self->{GI} = "";
	$self->{Description} = "";
	$self->{HLength} = "";
	$self->{QLength} = "";
	$self->{QStart} = "";
	$self->{QEnd} = "";
	$self->{HStart} = "";
	$self->{HEnd} = "";
	$self->{Bitmap} = Wx::Bitmap->new(1,1,-1);
	$self->SetBackgroundColour(wxWHITE);
	EVT_PAINT($self,\&OnPaint);
	EVT_SIZE($self,\&OnSize);
	return $self;
}

sub OnPaint {
	my ($self,$event) = @_;
	if ($self->{Query} eq "") {
		return 0;
	}
	my $dc = Wx::PaintDC->new($self);
	$dc->DrawBitmap($self->{Bitmap},0,0,1);
}

sub OnSize {
	my ($self,$event) = @_;
	if ($self->{Query} eq "") {
		return 0;
	}
	my $size = $self->GetClientSize();
	my $width = $size->GetWidth();
	my $height = $size->GetHeight();
	$self->{Bitmap} = Wx::Bitmap->new($width,$height,-1);
	my $memory = Wx::MemoryDC->new();
	$memory->SelectObject($self->{Bitmap});
	$self->DisplayTextInfo($memory);
}

sub SetQuery {
	my ($self,$query,$gi,$descr,$hlength,$qlength,$qstart,$qend,$hstart,$hend,$bit) = @_;
	$self->{Query} = "$query";
	$self->{GI} = "$gi";
	$self->{Description} = "$descr";
	$self->{Bit} = $bit;
	$self->{HLength} = "$hlength";
	$self->{QLength} = "$qlength";
	$self->{QStart} = "$qstart";
	$self->{QEnd} = "$qend";
	$self->{HStart} = "$hstart";
	$self->{HEnd} = "$hend";
	$self->OnSize(0);
}

sub DisplayTextInfo {
	my ($self,$dc) = @_;
	my $size = $self->GetClientSize();
	my $width = $size->GetWidth();
	my $height = $size->GetHeight();
	my $window = Wx::HtmlWindow->new($self,-1);
	$window->SetSize($width,$height);
	
	$window->SetPage("
	<html>
  	<head>
    <title></title>
  	</head>
  	<body>
  	<h1>$self->{Query}</h1>
  	<p>GI: $self->{GI}</p>
  	<p>Description: $self->{Description}</p>
  	<br>
  	<br>
  	
    </body>
    </head>
    </html>
    ");

	$self->Refresh;
	$self->Layout;
}

package TableDisplay;
use Global qw($io_manager $blue);
use Wx qw /:everything/;
use Wx::Event qw(EVT_LIST_ITEM_SELECTED);
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED);
use Wx::Event qw(EVT_LIST_COL_CLICK);
use Wx::Event qw(EVT_SIZE);
use base 'Wx::Panel';

sub new {
	my ($class,$parent,$table_names,$bit,$evalue) = @_;
	my $self = $class->SUPER::new($parent,-1);
	$self->{ResultHitListCtrl} = undef;
	$self->{ResultQueryListCtrl} = undef;
	$self->{QueryColumnHash} = ();
	bless ($self,$class);
	$self->MainDisplay($table_names,$bit,$evalue);
	return $self;
}

sub MainDisplay {
	my ($self,$table_names,$bit,$evalue) = @_;
	my $sizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $rightsizer = Wx::BoxSizer->new(wxVERTICAL);
	
	$self->{ResultHitListCtrl} = Wx::ListCtrl->new($self,-1,wxDefaultPosition,wxDefaultSize,wxLC_REPORT);
	$self->{ResultHitListCtrl}->InsertColumn(0,"Hit Name");
	$self->{ResultHitListCtrl}->InsertColumn(1,"Count");
	
	$self->{ResultQueryListCtrl} = Wx::ListCtrl->new($self,-1,wxDefaultPosition,wxDefaultSize,wxLC_REPORT);
	$self->{ResultQueryListCtrl}->InsertColumn(0,"Query");
	$self->{ResultQueryListCtrl}->InsertColumn(1,"Rank");
	$self->{ResultQueryListCtrl}->InsertColumn(2,"E-Value");
	$self->{ResultQueryListCtrl}->InsertColumn(3,"Bit Score");
	$self->{ResultQueryListCtrl}->InsertColumn(4,"Percent Id");
	
	my $info_sizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{InfoPanel} = QueryTextDisplay->new($self);
	$info_sizer->Add($self->{InfoPanel},1,wxEXPAND);
	
	my $qlist_sizer = Wx::BoxSizer->new(wxVERTICAL);
	$qlist_sizer->Add($self->{ResultQueryListCtrl},1,wxEXPAND);
	
	$rightsizer->Add($qlist_sizer,1,wxEXPAND);
	$rightsizer->Add($info_sizer,1,wxEXPAND);
	
	my $hlist_sizer = Wx::BoxSizer->new(wxVERTICAL);
	$hlist_sizer->Add($self->{ResultHitListCtrl},1,wxEXPAND);
	
	$sizer->Add($hlist_sizer,1,wxEXPAND);
	$sizer->Add($rightsizer,2,wxEXPAND);
	
	$self->CompareTables($table_names,$bit,$evalue);
	$self->SetSizer($sizer);

	EVT_SIZE($self,\&OnSize);
}

# For resizing the columns of the list controls
sub OnSize {
	my ($self,$event) = @_;

	my $size = $self->{ResultHitListCtrl}->GetClientSize();
	my $width = $size->GetWidth();
	$self->{ResultHitListCtrl}->SetColumnWidth(0,$width*2/3);
	$self->{ResultHitListCtrl}->SetColumnWidth(1,$width/2);
	
	my $size = $self->{ResultQueryListCtrl}->GetClientSize();
	my $width = $size->GetWidth();
	$self->{ResultQueryListCtrl}->SetColumnWidth(0,$width*1/3);
	$self->{ResultQueryListCtrl}->SetColumnWidth(1,$width/6);
	$self->{ResultQueryListCtrl}->SetColumnWidth(2,$width/6);
	$self->{ResultQueryListCtrl}->SetColumnWidth(3,$width/6);
	$self->{ResultQueryListCtrl}->SetColumnWidth(4,$width/5);
	
	$self->{InfoPanel}->Layout;
	$self->Refresh;
	$self->Layout;
}

sub CompareTables {
	my ($self,$table_names,$bit,$evalue) = @_;
	
	# This could probably be done much better. Also, the SQL operations should be moved to IOHandler.
	
	# establish connection to database in $io_manager
	#$io_manager->ConnectDatabase();
	
	$io_manager->{Connection}->do("DROP TABLE IF EXISTS t_1");
	$io_manager->{Connection}->do("CREATE TEMP TABLE t_1 (query TEXT,gi INTEGER,rank INTEGER,percent REAL,bit REAL,
	evalue REAL,starth INTEGER,endh INTEGER,startq INTEGER,endq INTEGER,ignore_gi INTEGER,description TEXT,hitname TEXT,hlength INTEGER,ignore_query TEXT,qlength INTEGER,sequence TEXT)");

	#print "begin table loop\n"; # simple test of speed
	for my $table(@$table_names) {
		my $all_hits = $table . "_AllHits";
		my $hit_info = $table . "_HitInfo";
		my $query_info = $table . "_QueryInfo";
		my $temp = $io_manager->{Connection}->do("INSERT INTO t_1 SELECT * FROM $all_hits INNER JOIN $hit_info ON $hit_info.gi=$all_hits.gi 
		INNER JOIN $query_info ON $all_hits.query=$query_info.query
		WHERE $all_hits.bit > $bit AND $all_hits.evalue < $evalue");
	}
	#print "end table loop\n";
	
	$io_manager->{Connection}->do("DROP TABLE IF EXISTS t");
	$io_manager->{Connection}->do("CREATE TEMP TABLE t (query TEXT,gi INTEGER,rank INTEGER,percent REAL,bit REAL,
	evalue REAL,starth INTEGER,endh INTEGER,startq INTEGER,endq INTEGER,
	description TEXT,hitname TEXT,hlength INTEGER,qlength INTEGER,sequence TEXT)");

	#print "begin inserting\n";
	$io_manager->{Connection}->do("INSERT INTO t SELECT t_1.query,t_1.gi,t_1.rank,t_1.percent,t_1.bit,
	t_1.evalue,t_1.starth,t_1.endh,t_1.startq,t_1.endq,
	t_1.description,t_1.hitname,t_1.hlength,t_1.qlength,t_1.sequence FROM t_1 
	INNER JOIN(SELECT t_1.query,MAX(t_1.bit) AS MaxBit FROM t_1 GROUP BY query) grouped 
	ON t_1.query=grouped.query AND t_1.bit = grouped.MaxBit");
	#print "end inserting\n";

	$io_manager->{Connection}->do("DROP TABLE t_1");
	$self->DisplayHits();
}

# why exactly is this outside the class scope?
my %hmap = (); # maps the column, row to the hitname. Used in sorting the hitname column alphabetically  
my $hcol = 0; # 
my %hcolstate = (0=>-1,1=>-1);

sub DisplayHits {
	my ($self) = @_;

	$self->{ResultHitListCtrl}->DeleteAllItems;
	
	# move to IOManager 
	my $row = $io_manager->{Connection}->selectall_arrayref("SELECT hitname,COUNT(query) FROM t GROUP BY hitname");

	my $i = 0;
	for my $item(@$row) {
		my $hitname = $item->[0];
		next if ($hitname eq "");
		my $count = $item->[1];
		my $item = $self->{ResultHitListCtrl}->InsertStringItem($i,"");
		$self->{ResultHitListCtrl}->SetItemData($item,$i);
		$self->{ResultHitListCtrl}->SetItem($i,0,$hitname);
		$hmap{0}{$i} = $hitname;
		$self->{ResultHitListCtrl}->SetItem($i,1,$count);
		$hmap{1}{$i} = $count;
		$i++;
	}
	
	EVT_LIST_ITEM_ACTIVATED($self,$self->{ResultHitListCtrl},\&Save);
	EVT_LIST_ITEM_SELECTED($self,$self->{ResultHitListCtrl},\&DisplayQueries);
	EVT_LIST_COL_CLICK($self,$self->{ResultHitListCtrl},\&OnSortHit);
} 

my %qmap = (); # maps   
my $qcol = 0; # The current selected query column  
my %qcolstate = (0=>-1,1=>-1,2=>-1,3=>-1,4=>-1); # alternates between -1 and 1, depending
# on the state of sorting (eg. a..z or z..a)

# Called when a hit is clicked on in the Hit/count column.
sub DisplayQueries {
	my ($self,$event) = @_;
	$self->{ResultQueryListCtrl}->DeleteAllItems;
	my $hitname = $event->GetText;
	my $hit_gis = $io_manager->{Connection}->selectall_arrayref("SELECT * FROM t WHERE hitname=?",undef,$hitname);
	
	my $count = 0;
	for my $row(@$hit_gis) {
		my $item = $self->{ResultQueryListCtrl}->InsertStringItem($count,"");
		$self->{ResultQueryListCtrl}->SetItemData($item,$count);
		$self->{ResultQueryListCtrl}->SetItem($count,0,$row->[0]); #query
		$qmap{0}{$count} = $row->[0];
		$self->{ResultQueryListCtrl}->SetItem($count,1,$row->[2]); #rank
		$qmap{1}{$count} = $row->[2];
		$self->{ResultQueryListCtrl}->SetItem($count,2,$row->[5]); #e-value
		$qmap{2}{$count} = $row->[5];
		$self->{ResultQueryListCtrl}->SetItem($count,3,$row->[4]); #bit score
		$qmap{3}{$count} = $row->[4];
		$self->{ResultQueryListCtrl}->SetItem($count,4,sprintf("%.2f",$row->[3])); #percent identity
		$qmap{4}{$count} = $row->[3];
		$count += 1;
	}

	EVT_LIST_COL_CLICK($self,$self->{ResultQueryListCtrl},\&OnSortQuery);
	EVT_LIST_ITEM_SELECTED($self,$self->{ResultQueryListCtrl},\&BindInfoPaint);
}

sub BindInfoPaint {
	my ($self,$event) = @_;
	my $query = $event->GetText;
	my ($query,$gi,$rank,$percid,$bit,$evalue,$starth,$endh,$startq,$endq,$ignore_gi,$descr,$hitname,$hlength,$ignore_query,$qlength,$sequence) = 
	@{ $io_manager->{Connection}->selectrow_arrayref("SELECT * FROM t WHERE query=?",undef,$query)};
	$self->{InfoPanel}->SetQuery($query,$gi,$descr,$hlength,$qlength,$startq,$endq,$starth,$endh,$bit);
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

# sort one of the hit items (hit name or count) alphabetically or numerically
sub OnSortHit {
	my($self,$event) = @_;
	$hcol = $event->GetColumn;
	$hcolstate{$hcol} *= -1;
	$self->{ResultHitListCtrl}->SortItems(\&HCompare);
}

# Sort the selected query attribute column (eg, bit score) in the reverse of the existing order 
sub OnSortQuery {
	my($self,$event) = @_;
	$qcol = $event->GetColumn;
	$qcolstate{$qcol} *= -1;
	$self->{ResultQueryListCtrl}->SortItems(\&QCompare);
}

# Saves the queries (seqid and sequence) of the selected hitname in a FASTA file. 
sub Save {
	my ($self,$event) = @_;
	my $hitname = $event->GetText;
	my $dialog = Wx::FileDialog->new($self,"Save Queries to FASTA","","",".",wxFD_SAVE);
	if ($dialog->ShowModal==wxID_OK) {
		my $queries = $io_manager->{Connection}->selectall_arrayref("SELECT query FROM t WHERE hitname=?",undef,$hitname);
		open(FASTA, '>>' . $dialog->GetPath);
		for my $query(@$queries) {
			my $sequence = $io_manager->{Connection}->selectrow_arrayref("SELECT sequence FROM t WHERE query=?",undef,$query->[0]);
			print FASTA ">" . $query->[0] . "\n";
		  	print FASTA $sequence->[0] . "\n";
		  	print FASTA "\n";
		}
	  	close FASTA;
	}
	$dialog->Destroy;
}

package TableMenu;
use Global qw($io_manager $blue);
use Wx;
use Wx qw /:everything/;
use Wx::Event qw(EVT_LISTBOX);
use Wx::Event qw(EVT_LISTBOX_DCLICK);
use Wx::Event qw(EVT_BUTTON);
use OkDialog;
use PiePanels;
use base ("ClassificationPiePanel");

sub new {
	my ($class,$parent) = @_;
	
	my $self = $class->SUPER::new($parent,"Result Tables");
	$self->{ResultListBox} = $self->{FileBox};
	$self->{CompareListBox} = $self->{ChartBox};
	bless ($self,$class);
	
	$self->{CenterDisplay}->Detach($self->{ButtonsSizer});
	$self->{CenterDisplay}->Detach($self->{ChartPanel});
	$self->{CenterDisplay}->Insert(1,$self->{ButtonsSizer},1,wxCENTER|wxEXPAND,10);
	$self->{CenterDisplay}->Insert(2,$self->{ChartPanel},3,wxCENTER|wxEXPAND|wxTOP|wxBOTTOM,10);

	$self->{GenerateButton}->SetLabel("View");
	#$self->{ItemListLabelSizer}->Remove($self->{BrowseButton});
	$self->{BrowseButton}->Destroy;
	$self->UpdateItems();
	EVT_BUTTON($self,$self->{AddButton},sub{$self->{CompareListBox}->AddFile($self->{ResultListBox}->GetFile,$self->{ResultListBox}->{ListBox}->GetStringSelection)});
	EVT_BUTTON($self,$self->{RemoveButton},sub{$self->DeleteCompareResult()});
	$self->Layout;
	return $self;
}

sub UpdateItems {
	my ($self) = @_;
	$io_manager->AddResultsBox($self->{ResultListBox});
}

sub NewTypePanel {
	my ($self) = @_;
	my $panel = Wx::Panel->new($self,-1,wxDefaultPosition,wxDefaultSize,wxSUNKEN_BORDER);
	$panel->SetBackgroundColour($blue);
	
	my $panel_sizer_h = Wx::BoxSizer->new(wxHORIZONTAL);
	my $panel_sizer_v = Wx::BoxSizer->new(wxVERTICAL);
	
	my $paramsizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $choice_text = Wx::StaticBox->new($panel,-1,"Filter Parameters: ");
	my $choice_wrap = Wx::StaticBoxSizer->new($choice_text, wxVERTICAL);
	my $choice_sizer = Wx::FlexGridSizer->new(2,2,20,20);
	
	my $bit_label = Wx::StaticText->new($panel,-1,"Bit Score:");
	$choice_sizer->Add($bit_label,1,wxCENTER);
	$self->{BitTextBox} = Wx::TextCtrl->new($panel,-1,"");
	$self->{BitTextBox}->SetValue("40.0");
	$choice_sizer->Add($self->{BitTextBox},1,wxCENTER);
	
	my $e_label = Wx::StaticText->new($panel,-1,"E-value:");
	$choice_sizer->Add($e_label,1,wxCENTER);
	$self->{EValueTextBox} = Wx::TextCtrl->new($panel,-1,"");
	$self->{EValueTextBox}->SetValue("0.001");
	$choice_sizer->Add($self->{EValueTextBox},1,wxCENTER);
	$choice_wrap->Add($choice_sizer,3,wxCENTER|wxEXPAND);
	
	$paramsizer->Add($choice_wrap,1,wxCENTER);
	
	$panel_sizer_v->Add($paramsizer,1,wxCENTER);
	$panel_sizer_h->Add($panel_sizer_v,1,wxCENTER);
	
	$panel->SetSizer($panel_sizer_h);
	
	return $panel;
}

sub DeleteCompareResult {
	my ($self) = @_;
	my $delete_dialog = OkDialog->new($self,"Delete","Remove Result?");
	if ($delete_dialog->ShowModal == wxID_OK and $self->{CompareListBox}->{ListBox}->GetCount > 0) {
		$self->{CompareListBox}->DeleteFile;
	}
	$delete_dialog->Destroy;
}

1;