use strict;
use Wx;
use ErrorMessage;
use Cwd;

package Application;
use base 'Wx::App';
use Global qw($database_feature $io_manager);
use Display;

sub OnInit {
	my $self = shift;

	Wx::InitAllImageHandlers();
	my $display = Display->new();
	$display->TopMenu();
	$display->Show();

	if ($database_feature==1 and $io_manager->{HasDatabase} != 1) {
		my $no_db = ErrorMessage->new($display,"SQLite is not installed. Database functions are not available.","Warning");
		$no_db->ShowModal;
	}
	return 1;
}

package main;
my $app = Application->new;
$app->MainLoop;
