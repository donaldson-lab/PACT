=head1 NAME

OkDialog

=head1 SYNOPSIS

my $ok_dialog = OkDialog->new($panel,"Title","Message");

=head1 DESCRIPTION

Appears when there is a choice to proceed. 

=cut

package OkDialog;
use Global qw($green);
use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use base 'Wx::MessageDialog';

# Takes a parent (frame base class),title string, and message string. 
sub new {
	my ($class,$parent,$title,$dialog) = @_;
	my $self = $class->SUPER::new($parent,$dialog,$title,wxSTAY_ON_TOP|wxOK|wxCANCEL|wxCENTRE,wxDefaultPosition);
	$self->CenterOnParent(wxBOTH);
	$self->SetBackgroundColour($green);
	bless ($self,$class);
	return $self;
}

1;