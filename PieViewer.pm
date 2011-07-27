use Wx::Perl::Packager;
use Wx;

my $turq = Wx::Colour->new("TURQUOISE");
my $blue = Wx::Colour->new(130,195,250);
my $brown = Wx::Colour->new(205,133,63);


=head1 
Pie Data is:
Names (array)
Values (array)
Total
=cut


package PiePanel;
use base 'Wx::Panel';
use Math::Trig;
use Wx qw /:everything/;
use Wx::Event qw(EVT_LEFT_DCLICK);
use Wx::Event qw(EVT_TEXT_ENTER);
use Wx::Event qw(EVT_SIZE);
use Wx::Event qw(EVT_PAINT);
use Wx::Event qw(EVT_MOTION);

sub new {
	my ($class,$parent,$data,$background,$title,$legend,$values) = @_;
	my $self = $class->SUPER::new($parent,-1);
	$self->{Bitmap} = Wx::Bitmap->new(1,1,-1);
	$self->{Data} = $data;
	$self->{Background} = $background;
	$self->{Legend} = $legend;
	$self->{Values} = $values;
	$self->{Radius} = 0;
	$self->{ValuesRadius} = undef;
	$self->{Brushes} = undef;
	$self->{Title} = $title;
	$self->{TitleDimensions} = undef;
	$self->{LegendLocations} = ();
	
	$self->TruncateData();
	EVT_PAINT($self,\&OnPaint);
	EVT_SIZE($self,\&OnSize);
	EVT_LEFT_DCLICK($self,\&GetCoordinates);
	EVT_MOTION($self,sub{$self->ResizeNumbers($_[0],$_[1])});
	bless $self,$class;
	return $self;
}

sub TruncateData {
	my ($self) = @_;
	my @names_ = @{$self->{Data}->{Names}};
	my @values_ = @{$self->{Data}->{Values}};
	my $others = 0;
	
	if (scalar(@values_) < 9) {
		return 0;
	}
	
	my %NameToValue = ();
	for (my $i=0; $i<@values_; $i++) {
		$NameToValue{$names_[$i]} = $values_[$i];
	}
	
	my $Names = [];
	my $Values = [];
	
	my $count = 0;
	foreach $key (sort {$NameToValue{$b} <=> $NameToValue{$a} } keys %NameToValue)
	{
	    if ($count >= 8) {
			$others += $NameToValue{$key}; 	
		}
		else {
			push(@$Names,$key);
			push(@$Values,$NameToValue{$key});
		}
		$count++;
	}
	
	push(@$Names,"Other");
	push(@$Values,$others);
	
	$self->{Data}->{Names} = $Names;
	$self->{Data}->{Values} = $Values;
	
}

sub GetCoordinates {
	my ($self,$event) = @_;
	my $x = $event->GetPosition()->x;
	my $y = $event->GetPosition()->y;
	for (my $i=0; $i<keys(%{$self->{LegendLocations}}); $i++) {
		my $lx = $self->{LegendLocations}{$i}->[0];
		my $ly = $self->{LegendLocations}{$i}->[1];
		my $lwidth = $self->{LegendLocations}{$i}->[2];
		my $lheight = $self->{LegendLocations}{$i}->[3];
		if ($x >= $lx and $x <= $lx + $lwidth and $y >= $ly and $y <= $ly + $lheight) {
			my $label = $self->{Data}->{Names}->[$i];
			my $label_dialog = Wx::TextEntryDialog->new($self,"New Label","Enter New Legend Label:",$label);
			if ($label_dialog->ShowModal == wxID_OK) {
				$self->ProcessNewLegend($label_dialog->GetValue,$i);
			}
			$label_dialog->Destroy;
			return 1;
		}
	}
}

sub ProcessNewLegend {
	my ($self,$new_label,$index) = @_;
	my @new_label_array = ($new_label);
	$self->{Brushes}{$new_label} = $self->{Brushes}{$self->{Data}->{Names}->[$index]};
	splice(@{$self->{Data}->{Names}},$index,1,@new_label_array);
	$self->OnSize(0);
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
	if ($self->{Data}->{Total} != 0){
		$self->Draw($memory);
	}
}

sub SetBrushes {
	my ($self) = @_;
	my @brush_array = ( wxRED_BRUSH,
	+ wxGREEN_BRUSH,wxCYAN_BRUSH,
	+ Wx::Brush->new(Wx::Colour->new(255,105,180),wxSOLID), #pink
	+ Wx::Brush->new(Wx::Colour->new(255,165,0),wxSOLID), #orange
	+ Wx::Brush->new(Wx::Colour->new(255,255,0),wxSOLID), #yellow
	+ wxBLUE_BRUSH,
	+ Wx::Brush->new(Wx::Colour->new(160,32,240),wxSOLID) ); #purple
	
	sub fisher_yates_shuffle {
	    my $array = shift;
	    my $i = @$array;
	    while ( --$i )
	    {
	        my $j = int rand( $i+1 );
	        @$array[$i,$j] = @$array[$j,$i];
	    }
	}
	fisher_yates_shuffle( \@brush_array );
	
	
	$self->{Brushes} = ();

	my @labels = @{$self->{Data}->{Names}};
	my $count;
	if (scalar(@brush_array) > scalar(@labels)) {
		$count = scalar(@labels);
	}
	else {
		$count = scalar(@brush_array);
	}
	for (my $i = 0; $i<$count; $i++) {
		$self->{Brushes}{$labels[$i]} = $brush_array[$i];
	}
}

sub SetBrushesSync {
	my ($self,$colors) = @_;
	for $name(keys(%{$colors})) {
		my $color = $colors->{$name};
		$self->{Brushes}{$name} = Wx::Brush->new(Wx::Colour->new($color->[0],$color->[1],$color->[2]),wxSOLID);
	}
	
}

sub ResizeNumbers {
	my ($self,$panel,$event) = @_;
	my $x = $event->GetPosition()->x;
	my $y = $event->GetPosition()->y;
	my $width = $panel->GetRect()->width();
	my $height = $panel->GetRect()->height();
	my $legend_y = 4/5*$height; #this needs to be global
	my $center_x = $width/2;
	my $center_y = $legend_y/2;
	if ($event->Dragging and $y<$legend_y) {
		$self->{ValuesRadius} = sqrt(($x-$center_x)**2 + ($y-$center_y)**2);
		$self->OnSize(0);
	}	
}

sub Values {
	my ($self,$event) = @_;
	$self->{Values} *= -1;
	$self->OnSize(0);
}

sub Background {
	my ($self,$event) = @_;
	$self->{Background} *= -1;
	$self->OnSize(0);
}

sub Legend {
	my ($self,$event) = @_;
	$self->{Legend} *= -1;
	$self->OnSize(0);
}

sub Title {
	my ($self,$event) = @_;
	my $title_dialog = Wx::TextEntryDialog->new($self,"Pie Chart Title","Enter Title");
	if ($title_dialog->ShowModal == wxID_OK) {
		$self->{Title} = $title_dialog->GetValue;
		$self->OnSize(0);
	}
	$title_dialog->Destroy;
}

sub Draw {
	my ($self,$dc) = @_;
	
	my $gc = Wx::GraphicsContext::Create($dc);

	# Chart Data
	my @labels = @{$self->{Data}->{Names}};
	my @values = @{$self->{Data}->{Values}};
	my $total = $self->{Data}->{Total};
	
	# Chart dimensions
	my $rect = $self->GetRect();
	my $width = $rect->width();
	my $height = $rect->height();
	my $x_origin = $rect->GetX();
	my $y_origin = $rect->GetY();
	
	# Legend Dimensions
	my $legend_x = 0;
	my $legend_y = 4*$height/5; #should be class variable
	my $legend_width = $width;
	my $legend_height = $height/5; #ratio should be class defined
	
	# Set colors for main rectangle.
	if ($self->{Background} == 1) {
		$dc->SetBrush(wxWHITE_BRUSH);
		$dc->SetPen(wxWHITE_PEN);
	}
	else {
		$dc->SetBrush(wxLIGHT_GREY_BRUSH);
		$dc->SetPen(wxLIGHT_GREY_PEN);
	}
	
	# Set font for text 
	my $font = Wx::Font->new(14,wxFONTFAMILY_SCRIPT,wxNORMAL,wxNORMAL,0);
	$dc->SetFont($font);
	
	$dc->DrawRectangle(0,0,$width,$height);
	
	my $radius = $width;
	if ($height < $width) {
		$radius = $height;
	}
	$self->{Radius} = $radius;

	my $prev_angle = 0;
	my $has_keyword = 0;
	
	#Draw Legend Rectangle.
	$self->DrawLegendRectangle($dc,$legend_x,$legend_y,$legend_width,$legend_height);
	
	if ($self->{Values} == 1) {
		$dc->DrawText("n=" . $total,3/4*$legend_width,$legend_y - 1/4*$legend_height);
	}

	## Draw Pie Chart and Legend
	for (my $count=0;$count<@values;$count++){
		
		#Draw Arc
		my $current_angle = $prev_angle + 2*pi*$values[$count]/$total;
		
		# Draws the pie arc, and if specified, the numeric value.
		$self->DrawSlice($dc,$gc,$width,$height,$radius,$legend_height,$prev_angle,$current_angle,$count,$labels[$count],$values[$count]);
		
		$prev_angle = $current_angle;

		# Draws the label on the legend.
		$self->DrawLegendItem($dc,$legend_width,$legend_height,$legend_x,$legend_y,\@labels,$count);
	}
	
	# Draw title, if one is specified.
	$self->DrawTitle($dc,$width);
	
	$self->Refresh;
	$self->Layout;
}

sub DrawLegendRectangle {
	my ($self,$dc,$legend_x,$legend_y,$legend_width,$legend_height) = @_;
	
	if ($self->{Legend} == 1) {
		if ($self->{Background} == 1) {
			$dc->SetBrush(wxLIGHT_GREY_BRUSH); #alternative grey: Wx::Brush->new(wxSYS_COLOUR_BACKGROUND,wxSOLID)
			$dc->SetPen(wxLIGHT_GREY_PEN);
		}
		else {
			$dc->SetBrush(wxWHITE_BRUSH);
			$dc->SetPen(wxWHITE_PEN);
		}
		$dc->DrawRectangle($legend_x,$legend_y,$legend_width,$legend_height);
	}
	
}

sub DrawLegendItem {
	my ($self,$dc,$legend_width,$legend_height,$legend_x,$legend_y,$labels,$count) = @_;
	
	if ($self->{Legend} == 1) {
		if ($count == 8) {
			$dc->SetBrush(wxGREY_BRUSH);
		}
		else {
			$dc->SetBrush($self->{Brushes}{$labels->[$count]});
		}
		my $label_x = $legend_x + 1/25*$legend_width + 8/25*$legend_width*(($count)%3);
		my $label_y = $legend_y + 1/8*$legend_height + 2/8*$legend_height*((int(($count))/int(3))%3);
		my $label_width = 1/25*$legend_width; #can these two be pulled out of loop?
		my $label_height = 1/8*$legend_height;
		
		$dc->DrawRectangle($label_x,$label_y,$label_width,$label_height);
		$self->{LegendLocations}{$count} = [$label_x,$label_y,$label_width,$label_height];
		my @string_data = $dc->GetTextExtent($labels->[$count],undef); # Get text height to center.
		my $h = $string_data[1];
		$dc->DrawText($labels->[$count],$label_x + (26/25)*$label_width,$label_y - (1/2)*($h-$label_height));
	}
	
}

sub DrawSlice {
	my ($self,$dc,$gc,$width,$height,$radius,$legend_height,$prev_angle,$current_angle,$count,$label,$value) = @_;
	
	my $path = $gc->CreatePath();
	if ($count == 8) {
		$gc->SetBrush($gc->CreateBrush(wxGREY_BRUSH));
	}
	else {
		$gc->SetBrush($gc->CreateBrush($self->{Brushes}{$label}));
	}
	$gc->Translate($width/2,2*$height/5);
	$path->MoveToPoint(0.0,0.0);
	my $start = 2*pi - $prev_angle;
	my $end = 2*pi - $current_angle;
	$path->AddArc(0,0,(1/3)*$radius,$start,$end,0);
	$gc->FillPath($path,wxODDEVEN_RULE);
	$gc->Translate(-$width/2,-2*$height/5);
	
	# Draw Values
	if ($self->{Values} == 1) {
		my @string_data = $dc->GetTextExtent($value,undef); # Get text height of digits.
		my $w = $string_data[0];
		my $h = $string_data[1];
		
		my $value_x;
		my $value_y;
		my $values_radius;
		if (defined $self->{ValuesRadius}) {
			$values_radius = $self->{ValuesRadius};
		}
		else {
			$values_radius = (1/3)*$radius;
		}
		my $mid_angle_cos = cos(($current_angle+$prev_angle)/2);
		my $mid_angle_sin = sin(($current_angle+$prev_angle)/2);
		if ($mid_angle_cos < 0) {
			$value_x = $width/2 + $values_radius*$mid_angle_cos - $w;
		}
		else {
			$value_x = $width/2 + $values_radius*$mid_angle_cos;
		}
		if ($mid_angle_sin < 0) {
			$value_y = ($height - $legend_height)/2 - $values_radius*$mid_angle_sin;
		}
		else {
			$value_y = ($height - $legend_height)/2 - $values_radius*$mid_angle_sin - $h;
		}
		$dc->DrawText($value,$value_x,$value_y);
	}
	
	
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
		$self->{TitleDimensions} = [$title_x,$title_y,$w,$h];
		$dc->DrawText($self->{Title},$title_x + 1/4*$w,$title_y + 1/3*$h);
	}
	
}

package PieViewer;
use Math::Trig;
use List::Util qw(shuffle);
use IO::File;
use base 'Wx::Frame';
use Wx qw /:everything/;
use Wx::Event qw(EVT_MENU);
use Wx::Event qw(EVT_BUTTON);
use Wx::Event qw(EVT_LEFT_DCLICK);
use Wx::Event qw(EVT_LEFT_DOWN);
use Wx::Event qw(EVT_NOTEBOOK_PAGE_CHANGED);

sub new {
	my ($class,$data,$titles,$labels,$x,$y,$control) = @_;
	my $self = $class->SUPER::new(undef,-1,'Pie Chart Viewer',[$x,$y],[500,500],);
	$self->TopMenu($single);
	$self->{Notebook} = undef;
	$self->{Sync} = 0;
	$self->Notebook($data,$titles,$labels);
	$self->{Control} = $control;
	bless $self,$class;
	$self->Show;
	return $self;
}

sub Notebook {
	my($self,$data,$titles,$labels) = @_;
	
	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
	$self->{Notebook} = Wx::Notebook->new($self,-1);
	
	my $i;
	for ($i=0; $i<@{$data}; $i++) {
		
		my $panel = PiePanel->new($self->{Notebook},$data->[$i],1,$titles->[$i],1,1);
		$panel->SetBrushes();
		
		$self->{Notebook}->AddPage($panel,$labels->[$i]);
	}	

	$self->{Notebook}->Layout;
	$sizer->Add($self->{Notebook},1,wxEXPAND);
	$self->SetSizer($sizer);
	$self->{Notebook}->SetSelection($i-1);
	$self->Layout;
}

sub TopMenu {
	my ($self) = @_; 
	my $filemenu = Wx::Menu->new();
	my $export = $filemenu->Append(101,"Export");
	my $save = $filemenu->Append(102,"Save Color Scheme");
	my $load = $filemenu->Append(103,"Load Color Scheme");
	my $close = $filemenu->Append(104,"Quit");
	EVT_MENU($self,101,\&ExportDialog);
	EVT_MENU($self,102,\&SaveDialog);
	EVT_MENU($self,103,\&LoadDialog);
	EVT_MENU($self,104,sub{$self->Close(1)});
	
	my $formatmenu = Wx::Menu->new();
	my $sync = $formatmenu->Append(201,"Sync/Unsync Colors");
	my $color = $formatmenu->Append(202,"Toggle Chart Colors");
	my $background = $formatmenu->Append(203,"Toggle Background");
	my $values = $formatmenu->Append(204,"Toggle Values");
	my $title = $formatmenu->Append(205,"Add/Remove Title");
	my $legend = $formatmenu->Append(206,"Add/Remove Legend");
	
	EVT_MENU($self,201,\&Sync);
	EVT_MENU($self,202,\&Switch);
	EVT_MENU($self,203,\&Background);
	EVT_MENU($self,204,\&Values);
	EVT_MENU($self,205,\&Title);
	EVT_MENU($self,206,\&Legend);

	my $menubar = Wx::MenuBar->new();
	$menubar->Append($filemenu,"File");
	$menubar->Append($formatmenu,"Format");
	$self->SetMenuBar($menubar);
}

sub SaveDialog {
	my ($self,$event) = @_;
	my $save_dialog = Wx::TextEntryDialog->new($self,"Enter Name","Save Color Preferences");
	if ($save_dialog->ShowModal == wxID_OK) {
		$self->SaveColors($save_dialog->GetValue);
	}
	$save_dialog->Destroy;
}

sub SaveColors {
	my ($self,$save_name) = @_;
	chdir($self->{Control}->{ColorPrefs});
	dbmopen(my %COLOR,$save_name,0644) or die "Cannot create $save_name: $!";
	for (my $i=0; $i<$self->{Notebook}->GetPageCount; $i++) {
		my $pie = $self->{Notebook}->GetPage($i);
		for my $name(keys(%{$pie->{Brushes}})) {
			my $red = $pie->{Brushes}{$name}->GetColour()->Red;
			my $green = $pie->{Brushes}{$name}->GetColour()->Green;
			my $blue = $pie->{Brushes}{$name}->GetColour()->Blue;
			$COLOR{$name} = "$red;$green;$blue";
		}
	}
}

sub LoadDialog {
	my ($self,$event) = @_;
	my $loadframe = Wx::Frame->new(undef,-1,"Load Color Preferences");
	my $loadpanel = Wx::Panel->new($loadframe,-1);
	my $framesizer = Wx::BoxSizer->new(wxVERTICAL);
	
	my $textsizer = Wx::BoxSizer->new(wxHORIZONTAL);
	my $label = Wx::StaticText->new($loadpanel,-1,"Name:");
	my $text = Wx::ListBox->new($loadpanel,-1,wxDefaultPosition,wxDefaultSize,[],wxEXPAND);
	$textsizer->Add($label,1,wxLEFT|wxCENTER|wxRIGHT,10);
	$textsizer->Add($text,3,wxLEFT|wxCENTER|wxRIGHT,10);
	
	opendir(DIR,$self->{Control}->{ColorPrefs});
	my @files = readdir(DIR);
	for my $file(@files) {
		if ($file =~ /.db/g) {
			$text->InsertItems([$file],0);
		}
	}
	closedir DIR;
	
	my $enter = Wx::Button->new($loadpanel,-1,"Enter");
	$framesizer->Add($textsizer,2,wxCENTER);
	$framesizer->Add($enter,1,wxCENTER);
	
	EVT_BUTTON($loadpanel,$enter,sub{$self->LoadColors($loadframe,$text->GetString($text->GetSelection))});
	$loadpanel->SetSizer($framesizer);
	$loadframe->Layout;
	$loadframe->Show;
}

sub LoadColors {
	my ($self,$loadframe,$loadname) = @_;
	$loadname =~s/.db//g;
	chdir($self->{Control}->{ColorPrefs});
	dbmopen(my %COLOR,$loadname,0644) or die "Cannot open color_pref: $!";
	%colors = ();
	for my $key(keys(%COLOR)) {
		my @color_array = split(/;/,$COLOR{$key});
		$colors{$key} = \@color_array;
	}
	$self->{Sync} = 1;
	for (my $i=0; $i<$self->{Notebook}->GetPageCount; $i++) {
		my $pie = $self->{Notebook}->GetPage($i);
		$pie->SetBrushesSync(\%colors);
		$pie->OnSize(0);
	}
	$loadframe->Destroy;
}

sub RandomColor {
	my ($self) = @_;
	my $range = 255;
	return [rand($range),rand($range),rand($range)];
}

sub UnSync {
	my ($self) = @_;
	my $piecount = $self->{Notebook}->GetPageCount();
	for (my $i=0; $i<$piecount; $i++) {
		my $pie = $self->{Notebook}->GetPage($i);
		$pie->SetBrushes();
		$pie->OnSize(0);
	}
}

sub Sync {
	my ($self) = @_;
	
	if ($self->{Sync} == 1) {
		$self->UnSync();
	}
	else {
		my %colors = ();
		my $piecount = $self->{Notebook}->GetPageCount();
		for (my $i=0; $i<$piecount; $i++) {
			my $pie = $self->{Notebook}->GetPage($i);
			my @names = @{$pie->{Data}->{Names}};
			for my $name(@names) {
				if (not exists $colors{$name}) {
					$colors{$name} = $self->RandomColor();	
				}	
			}
		}
		
		for (my $i=0; $i<$piecount; $i++) {
			my $pie = $self->{Notebook}->GetPage($i);
			$pie->SetBrushesSync(\%colors);
			$pie->OnSize(0);
		}
	}
	$self->{Sync} *= -1;
}

sub Switch {
	my ($self) = @_;
	my $pie = $self->{Notebook}->GetCurrentPage();
	$pie->SetBrushes();
	$pie->OnSize(0);
}

sub Background {
	my ($self,$event) = @_;
	my $pie = $self->{Notebook}->GetCurrentPage();
	$pie->Background($event);
}

sub Values {
	my ($self,$event) = @_;
	my $pie = $self->{Notebook}->GetCurrentPage();
	$pie->Values($event);
}

sub Legend {
	my ($self,$event) = @_;
	my $pie = $self->{Notebook}->GetCurrentPage();
	$pie->Legend($event);
}

sub Title {
	my ($self,$event) = @_;
	my $pie = $self->{Notebook}->GetCurrentPage();
	$pie->Title($event);	
}

sub ExportDialog {
	my ($self,$event) = @_;
	my $dialog = Wx::FileDialog->new($self,"Save Pie Chart","","","*.*",wxFD_SAVE);
	if ($dialog->ShowModal==wxID_OK){
		$self->Export($dialog->GetPath);
	}
}

sub Export {
	my ($self,$file_name) = @_;
	my $handler = Wx::PNGHandler->new();
	my $file = IO::File->new($file_name . ".pact.png","w");
	my $pie = $self->{Notebook}->GetCurrentPage();
	$handler->SaveFile($pie->{Bitmap}->ConvertToImage(),$file); #$file);
}

1;
