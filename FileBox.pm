=head1 NAME

FileBox

=head1 DESCRIPTION

This class enables file paths to be stored and displayed in a wxListBox, so that a shortened
name is displayed, but not the actual path.  
Ideally, this would probably be inherited from the actual wxListBox.

=cut

package FileBox;
use Wx qw /:everything/;

sub new {
	my ($class,$parent) = @_;
	
	my $self = {};
	$self->{FileArray} = ();
	$self->{ListBox} = Wx::ListBox->new($parent,-1);
	bless ($self,$class);
	return $self;
}

# add the short name to the display ListBox, then add the path to the array
sub AddFile {
	my ($self,$file_path,$file_label) = @_;
	$self->{ListBox}->Insert($file_label,$self->{ListBox}->GetCount);
	push(@{$self->{FileArray}},$file_path);
}

# returns the path name of the selected file label
sub GetFile {
	my $self = shift;
	return $self->{FileArray}[$self->{ListBox}->GetSelection];
}

# returns all file paths
sub GetAllFiles {
	my $self = shift;
	return $self->{FileArray};
}

# removes both the displayed file label and the file path from memory
sub DeleteFile {
	my $self = shift;
	my $selection = $self->{ListBox}->GetSelection;
	splice(@{$self->{FileArray}},$selection,1);
	$self->{ListBox}->Delete($selection);
}

1;