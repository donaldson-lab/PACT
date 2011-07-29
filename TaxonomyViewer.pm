use Wx;
use Bio::Tree::Tree;
use Bio::TreeIO;

package TaxonomyPanel;

use base 'Wx::Panel';
use Math::Trig;
use Wx qw /:everything/;
use Wx::Event qw(EVT_PAINT);
use Wx::Event qw(EVT_SIZE);
use Wx::Event qw(EVT_LEFT_DOWN);
use Wx::Event qw(EVT_MOTION);

sub new {
	my ($class,$parent,$x,$y,$taxonomy,$title) = @_;
	my $self = $class->SUPER::new($parent,-1);
	$self->{Taxonomy} = $taxonomy;
	$self->{Title} = $title;
	$self->{Labels} = 1;
	$self->{NodeLabels} = ();
	for my $node($self->{Taxonomy}->get_nodes('breadth')) {
		$self->{NodeLabels}{$node} = 1;
	}
	$self->SetBackgroundColour(wxWHITE);
	$self->{Colors} = (); # actually pens
	$self->{SelectedNode} = undef;
	$self->{Offset} = 400;
	$self->getCoordinates();
	
	EVT_PAINT($self,\&OnPaint);
	EVT_SIZE($self,\&OnSize);
	EVT_LEFT_DOWN($self,\&GetClickedCoordinates);

	bless $self,$class;
	return $self;
}

sub OnPaint {
	my ($self,$event) = @_;
	my $dc = Wx::PaintDC->new($self);
	$dc->DrawBitmap($self->{Bitmap},0,0,1);
}

sub OnSize {
	my ($self,$event) = @_;
	my $size = $self->GetClientSize();
	my $width = $size->GetWidth();
	my $height = $size->GetHeight();
	$self->{Bitmap} = Wx::Bitmap->new($width,$height,-1);
	my $memory = Wx::MemoryDC->new();
	$memory->SelectObject($self->{Bitmap});
	$self->draw($memory,$width,$height);
}

sub GetClickedCoordinates {
	my ($self,$event) = @_;
	my $size = $self->GetClientSize();
	my $width = $size->GetWidth();
	my $height = $size->GetHeight();
	my $x = $event->GetPosition()->x - $width/2;
	my $y = $height/2 - $event->GetPosition()->y;
	
	for my $node($self->{Taxonomy}->get_nodes('breadth')) {
		my @coords = @{$self->{vertex_to_coords}{$node}};
		my $distance = sqrt(($x-$coords[0])**2 + ($y-$coords[1])**2);
		if ( $distance < 3.0) {
			if ($self->{Labels} != 1) {
				$self->{NodeLabels}{$node} *= -1;	
			}
			$self->{SelectedNode} = $node;
			$self->OnSize(0);
			EVT_MOTION($self,\&MoveNode);
			return 1;
		}
	}
	$self->{OriginalOffset} = $self->{Offset};
	$self->{MotionStart} = [$event->GetPosition()->x,$event->GetPosition()->y];
	EVT_MOTION($self,\&Resize);
	$self->{SelectedNode} = undef;
}

sub Resize {
	my ($self,$event) = @_;
	my $x = $event->GetPosition()->x;
	my $y = $event->GetPosition()->y;
	my $width = $self->GetRect()->width();
	my $height = $self->GetRect()->height();
	my $center_x = $width/2;
	my $center_y = $height/2;
	if ($event->Dragging) {
		my $dot = ($self->{MotionStart}->[0] - $x)*($center_x - $x) + ($self->{MotionStart}->[1] - $y)*($center_y - $y);
		my $center_distance = sqrt(($x-$center_x)**2 + ($y-$center_y)**2);
		my $distance;
		if ($center_distance == 0) {
			$distance = 0;
		}
		else { 
			$distance = $dot/$center_distance;
		}
		$self->{Offset} = $self->{OriginalOffset} + $distance;
		$self->getCoordinates();
		$self->OnSize(0);
	}
}

sub MoveNode {
	my ($self,$event) = @_;
	if (not defined $self->{SelectedNode}) {
		return 0;
	}
	my $size = $self->GetClientSize();
	my $width = $size->GetWidth();
	my $height = $size->GetHeight();
	if ($event->Dragging) {
		my $x_coord = $event->GetPosition()->x - $width/2;
		my $y_coord = $height/2 - $event->GetPosition()->y;
		$self->{vertex_to_coords}{$self->{SelectedNode}} = [$x_coord,$y_coord];
	}
	$self->OnSize(0);
}

sub draw {
	my ($self,$dc,$width,$height) = @_;
	
	$dc->SetBrush(wxWHITE_BRUSH);
	$dc->SetPen(wxWHITE_PEN);
	
	$dc->DrawRectangle(0,0,$width,$height);

	for my $node($self->{Taxonomy}->get_nodes('breadth')) {
		my @coords = @{$self->{vertex_to_coords}{$node}};
		my @pcoords = @{$self->{vertex_to_coords}{$node->ancestor()}};
		if (defined $self->{Colors}{$self->GetDepth($node)}) {
			$dc->SetPen($self->{Colors}{$self->GetDepth($node)});
		}
		else {
			$dc->SetPen($self->SetLevelColor($self->GetDepth($node)));
		}
		$dc->DrawLine($coords[0]+$width/2,-$coords[1]+$height/2,$pcoords[0]+$width/2,-$pcoords[1]+$height/2);
	}
	for my $node($self->{Taxonomy}->get_nodes('breadth')) {
		$dc->SetBrush(wxBLACK_BRUSH);
		$dc->SetPen(wxBLACK_PEN);
		my @coords = @{$self->{vertex_to_coords}{$node}};
		$dc->DrawCircle($coords[0]+$width/2,-$coords[1]+$height/2,3);
		if ($self->{NodeLabels}{$node}==1) {
			my @string_data = $dc->GetTextExtent($node->id,undef); # Get text height to center.
			my $w = $string_data[0];
			my $h = $string_data[1];
			if ($coords[0] < 0) {
				if ($coords[1] < 0) {
					$dc->DrawText($node->id,$coords[0]+$width/2 - $w,-$coords[1]+$height/2 - $h);
				}
				else {
					$dc->DrawText($node->id,$coords[0]+$width/2 - $w,-$coords[1]+$height/2 - $h);
				}
			}
			else {
				if ($coords[1] < 0) {
					$dc->DrawText($node->id,$coords[0]+$width/2,-$coords[1]+$height/2);
				}
				else {
					$dc->DrawText($node->id,$coords[0]+$width/2,-$coords[1]+$height/2 - $h);
				}
			}
		}
	}
	$self->DrawTitle($dc,$width);
	$self->Refresh;
}

sub DrawTitle {
	
	my ($self,$dc,$width) = @_;
	
	if ($self->{Title} ne "") {
		my $font = Wx::Font->new(16,wxFONTFAMILY_SCRIPT,wxNORMAL,wxNORMAL,0);
		$dc->SetFont($font);
		my @title_dim = $dc->GetTextExtent($self->{Title},undef); # Get text height to center.
		my $w = $title_dim[0];
		my $h = $title_dim[1];
		my $title_x = $width/2 - 3*$w/4;
		my $title_y = 0;
		$dc->DrawText($self->{Title},$title_x + 1/4*$w,$title_y + 1/3*$h);
	}
	
}

sub SetLevelColor {
	my ($self,$level) = @_;
	my $r = rand(255);
	my $g = rand(255);
	my $b = rand(255);
	my $pen = Wx::Pen->new(Wx::Colour->new($r,$g,$b),2,wxSOLID);
	$self->{Colors}{$level} = $pen;
}

sub GetDepth {
	my ($self,$node) = @_;
	my $depth = 0;
	while (defined $node->ancestor) {
		$depth++;
		$node = $node->ancestor;
	}
	return $depth;
}

sub getCoordinates {
	my ($self) = @_;
	$self->{vertex_to_offset} = ();
	$self->{vertex_to_coeff} = ();
	$self->{vertex_to_coords} = ();
	$self->{numLeaves} = 0;
	$self->circular_tree();
}

## Algorithm adapted from Bachmaier, Brandes, and Schlieper.
sub circular_tree {
	my ($self) = @_;
	$self->{i} = 0;
	for my $node($self->{Taxonomy}->get_nodes) {
		if ($node->each_Descendent == 0) {
			$self->{numLeaves}++;
		}
	}
	
	$self->postorder_traversal($self->{Taxonomy}->get_root_node());
	$self->preorder_traversal($self->{Taxonomy}->get_root_node());
}

sub postorder_traversal {
	my ($self,$node) = @_;
	for my $child($node->each_Descendent()) {
		$self->postorder_traversal($child);
	}
	
	my $size = $node->descendent_count;
	if ($size==0) {
		$self->{vertex_to_coeff}{$node} = [0,0];
		my $angle = (2*pi*$self->{i}/$self->{numLeaves});
		$self->{vertex_to_offset}{$node} = [$self->{Offset}*cos($angle),$self->{Offset}*sin($angle)];
		$self->{i}++;
	}
	else {
		my $degree = $size + 1;
		my $S =  1 + (1/($degree-1))*$size;
		my $t = [0,0];
		my $tprime = [0,0];
		for my $child($node->each_Descendent) {
			$t->[0] = $t->[0] + ((1/($degree-1))/$S)*$self->{vertex_to_coeff}{$child}->[0];
			$t->[1] = $t->[1] + ((1/($degree-1))/$S)*$self->{vertex_to_coeff}{$child}->[1];
			$tprime->[0] = $tprime->[0] + ((1/($degree-1))/$S)*$self->{vertex_to_offset}{$child}->[0];
			$tprime->[1] = $tprime->[1] + ((1/($degree-1))/$S)*$self->{vertex_to_offset}{$child}->[1];
		}
		if ($node eq $self->{Taxonomy}->get_root_node) {
			$self->{vertex_to_coeff}{$node} = [1/($S*(1-$t)),1/($S*(1-$t))];
		}
		$self->{vertex_to_offset}{$node} = [$tprime->[0]/(1-$t->[0]),$tprime->[1]/(1-$t->[1])];
	}
}

sub preorder_traversal {
	my ($self,$node) = @_;
	if ($node eq $self->{Taxonomy}->get_root_node) {
		$self->{vertex_to_coords}{$node} = [0,0];
	}
	else {
		my @coords = ();
		$coords[0] = $self->{vertex_to_coeff}{$node}->[0]*$self->{vertex_to_coords}{$node->ancestor}->[0] + $self->{vertex_to_offset}{$node}->[0];
		$coords[1] = $self->{vertex_to_coeff}{$node}->[1]*$self->{vertex_to_coords}{$node->ancestor}->[1] + $self->{vertex_to_offset}{$node}->[1];
		$self->{vertex_to_coords}{$node} = \@coords;
	}
	for my $child($node->each_Descendent) {
		$self->preorder_traversal($child);
	}
}

package TaxonomyViewer;
use IO::File;
use base 'Wx::Frame';
use Wx qw /:everything/;
use Wx::Event qw(EVT_MENU);

sub new {
	my ($class,$tree,$title) = @_;
	my $self = $class->SUPER::new(undef,-1,"",[-1,-1],[1000,1000]);
	$self->TopMenu();
	$self->{TaxView} = TaxonomyPanel->new($self,-1,-1,$tree,$title);
	$self->Show;
	return $self;
}

sub TopMenu {
	my ($self) = @_; 
	my $filemenu = Wx::Menu->new();
	my $export = $filemenu->Append(101,"Export");
	my $close = $filemenu->Append(102,"Quit");
	EVT_MENU($self,101,\&ExportDialog);
	EVT_MENU($self,102,sub{$self->Close(1)});
	
	my $formatmenu = Wx::Menu->new();
	my $color = $formatmenu->Append(201,"Toggle Colors");
	my $background = $formatmenu->Append(202,"Toggle Labels");
	my $title = $formatmenu->Append(203,"Add/Remove Title");
	$formatmenu->AppendSeparator();
	my $restore = $formatmenu->Append(204,"Restore");
	
	EVT_MENU($self,201,\&Switch);
	EVT_MENU($self,202,\&Labels);
	EVT_MENU($self,203,\&Title);
	EVT_MENU($self,204,\&Restore);

	my $menubar = Wx::MenuBar->new();
	$menubar->Append($filemenu,"File");
	$menubar->Append($formatmenu,"Format");
	$self->SetMenuBar($menubar);
}

sub ExportDialog {
	my ($self,$event) = @_;
	my $dialog = Wx::FileDialog->new($self,"Save Taxonomy","","","*.*",wxFD_SAVE);
	if ($dialog->ShowModal==wxID_OK){
		$self->Export($dialog->GetPath);
	}
}

sub Export {
	my ($self,$file_name) = @_;
	my $handler = Wx::PNGHandler->new();
	my $file = IO::File->new($file_name . ".png","w");
	$handler->SaveFile($self->{TaxView}->{Bitmap}->ConvertToImage(),$file);
}

sub Switch {
	my ($self) = @_;
	$self->{TaxView}->{Colors} = ();
	$self->{TaxView}->OnSize(0);
}

sub Labels {
	my ($self) = @_;
	$self->{TaxView}->{Labels} *= -1;
	for my $node($self->{TaxView}{Taxonomy}->get_nodes('breadth')) {
		$self->{TaxView}->{NodeLabels}{$node} = $self->{TaxView}->{Labels};
	}
	$self->{TaxView}->OnSize(0);
}

sub Restore {
	my ($self,$event) = @_;
	$self->{TaxView}->{Offset} = 400;
	$self->{TaxView}->getCoordinates();
	$self->{TaxView}->OnSize(0);
}

sub Title {
	my ($self,$event) = @_;
	if ($self->{TaxView}->{Title} ne "") {
		$self->{TaxView}->{Title} = "";
		$self->{TaxView}->OnSize(0);
	}
	else {
		my $title_dialog = Wx::TextEntryDialog->new($self,"Tree Title","Enter Title");
		if ($title_dialog->ShowModal == wxID_OK) {
			$self->{TaxView}->{Title} = $title_dialog->GetValue;
			$self->{TaxView}->OnSize(0);
		}
		$title_dialog->Destroy;	
	}
}

1;
