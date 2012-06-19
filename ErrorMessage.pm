=head1 NAME

ErrorMessage

=head1 SYNOPSIS

my $error_message = ErrorMessage->new($panel,"PACT could not connect to NCBI","Error");

=head1 DESCRIPTION

Pops up when the user choose an action that fails (ie, the computer is not connected to the internet to check
taxonomic information), or a warning.
Gives a warning and description of what happened.

=cut

package ErrorMessage;
use Global qw($green);
use Wx qw /:everything/;
use Wx::Event qw(EVT_BUTTON);
use base 'Wx::MessageDialog';

sub new {
	my ($class,$parent,$dialog,$type) = @_;
	my $self = $class->SUPER::new($parent,$dialog,$type,wxSTAY_ON_TOP|wxOK|wxCENTRE,wxDefaultPosition);
	$self->CenterOnParent(wxBOTH);
	$self->SetBackgroundColour($green);
	bless ($self,$class);
	return $self;
}

1;