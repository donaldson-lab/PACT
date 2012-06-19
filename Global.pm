package Global;
use Wx;
use IOHandler;
require Exporter;

@ISA = qw(Exporter);
@EXPORT_OK = qw($green $blue $roots_feature $database_feature $local_tax_feature $has_database $io_manager);

# Global colors
our $green = Wx::Colour->new("LIGHT BLUE"); #Wx::Colour->new("SEA GREEN");
our $blue = Wx::Colour->new("LIGHT BLUE"); #Wx::Colour->new("SKY BLUE");

# 0 if the feature for defining roots in taxonomy search is not available
our $roots_feature = 0;

# database enabled?
our $database_feature = 1;

# local tax files enabled?
our $local_tax_feature = 0;

# Global variable for determining whether SQLite or other rdbms is installed.

our $io_manager = IOHandler->new($database_feature); # First and only instantiation of IOHandler.

1;