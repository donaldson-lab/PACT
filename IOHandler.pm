=head1 NAME

IOHandler

=head1 SYNOPSIS

my $main_control = IOHandler->new();

=head1 DESCRIPTION

Used to access program files, folders. Basically a wrapper object that can be passed to processes
during parsing.
wxWidgets might already have classes and functions to
do this?

=cut

package IOHandler;
use DBI;
use Cwd;
use IO::File;
use LWP::Simple;
use Archive::Tar;
use Fcntl;
use DB_File;
use File::Path;
use File::Find;
use File::Basename;
use Win32;

sub new {
	my ($class,$database_feature) = @_;
	my $self = {
		HasDatabase => 0
		};
	bless ($self,$class);
	
	my $current = cwd();
	
	# Initialize program files and folders
	$self->GetPathSeparator();
	$self->GetCurrentDirectory($current);

	if ($database_feature==1) {
		$self->MakeResultsFolder();
	}
	$self->MakeColorPrefsFolder();
	$self->SetTaxDump();
	
	chdir($current);
	return $self;
}

# The directory of the program. To be used as the parent directory to store all files and
# folders containing user data, NCBI taxonomy files, table results, etc.
sub GetCurrentDirectory {
	my ($self,$current) = @_;
	
	# removes bin from directory name - quick hack not relevant for script
	$self->{CurrentDirectory} = substr($current,0,-3) . $self->{PathSeparator} . "usr";

	if (mkdir($self->{CurrentDirectory})==0) {
		$self->{CurrentDirectory} = $current . $self->{PathSeparator} . "usr";
		mkdir($self->{CurrentDirectory});
	}
	chdir($self->{CurrentDirectory});
}

# Folder that stores NCBI taxonomy look-up files.
sub SetTaxDump {
	my ($self) = @_;
	$self->{TaxDump} = $self->{CurrentDirectory} . $self->{PathSeparator} . "taxdump";
	mkdir($self->{TaxDump});
}

# Check to see if NCBI taxonomies files are stored. If not, 
sub CheckTaxDump {
	my ($self) = @_;
	chdir($self->{TaxDump});
	if (-e "nodes.dmp" and -e "names.dmp") {
		$self->{NodesFile} = $self->{TaxDump} . $self->{PathSeparator} . "nodes.dmp";
		$self->{NamesFile} = $self->{TaxDump} . $self->{PathSeparator} . "names.dmp";
	}
	else {
		return 0;	
	}
	return 1;
}

# Downloads NCBI taxonomy files from the given url.
# returns 0 if NCBI taxdump file could not be retrieved.
sub DownloadNCBITaxonomies {
	my $self = shift;
	chdir($self->{TaxDump});
	
	my $url = "ftp://ftp.ncbi.nih.gov/pub/taxonomy/";
	my $file = "taxdump.tar.gz";
	getstore("$url/$file",$file) or return 0;
	my $tar = Archive::Tar->new;
	$tar->read($file);
	$tar->extract();
	unlink($file);
}

## Results Folder is where table result db files are stored
sub MakeResultsFolder {
	my ($self) = @_;
	$self->{Results} = $self->{CurrentDirectory} . $self->{PathSeparator} . "Results";
	mkdir $self->{Results};
	# test database connection
	#my @drivers = DBI->available_drivers(); # This does not work in CAVA!
	if ($self->ConnectDatabase != -1) {
		$self->{HasDatabase} = 1;
	}
	else {
	}
}

## Removes the table from the database. Deletes the key,label in the TableNames hash.  
sub DeleteResult {
	my ($self,$key) = @_;
	chdir($self->{Results});
	tie(my %TABLENAMES,'DB_File',"TABLENAMES.db",O_CREAT|O_RDWR,0644) or return 0;
	if (defined $TABLENAMES{$key}) {
		$self->RemoveResultTables($key);
		delete $TABLENAMES{$key};
	}
}

## Adds the key and label to a FileBox. See FileBox
sub AddResultsBox {
	my ($self,$box) = @_;
	$box->{ListBox}->Clear;
	chdir($self->{Results});
	my $TABLENAMES = $self->GetTableNames();
	while ( my ($key, $value) = each(%$TABLENAMES) ) {
		$box->AddFile($key,$value);
	}
}

# Generates a key for the table, then stores the key and label in a hash (see below).
sub AddTableName {
	my ($self,$label) = @_;
	chdir($self->{Results});
	tie(my %TABLENAMES,'DB_File',"TABLENAMES.db",O_CREAT|O_RDWR,0644) or return 0;
	my $key = $self->GenerateTableKey();
	$TABLENAMES{$key} = $label;
	return $key;
}

# returns a hash of table names (table key to English name)
sub GetTableNames {
	my ($self) = @_;
	chdir($self->{Results});
	tie(my %TABLENAMES,'DB_File',"TABLENAMES.db",O_CREAT|O_RDWR,0644) or return 0;
	return \%TABLENAMES;
}

# Creates a key for naming the result tables. The key is 3 random letters plus the date of creation.  
sub GenerateTableKey {
	my ($self) = @_;
	my @alpha = ("a".."z");
	my @timeData = localtime(time);
	srand;
	my $name_key = "";
	foreach (1..3) 
	{    
		my $rand = int(rand scalar(@alpha));
		$name_key = $name_key . $alpha[$rand];
	}
	$name_key = $name_key . "d" . $timeData[3] . "m" . $timeData[4] . "y" . $timeData[5];
	return $name_key;
}

# The folder for storing db hash files containing a user-defined color code for pie charts. 
sub MakeColorPrefsFolder {
	my $self = shift;
	$self->{ColorPrefs} = $self->{CurrentDirectory} . $self->{PathSeparator} . "ColorPrefs";
	mkdir $self->{ColorPrefs};
}

# Using DBI to connect to SQLite DB file.
# Returns integer code. -1 for failed SQL connection, 0 for failed DB hash connection. 
sub ConnectDatabase {
	my ($self) = @_;
	
	chdir($self->{Results});
	my $db_user = "";
	my $db_pass = "";
	
	$self->{Connection} = DBI->connect("dbi:SQLite:Results.db","","") or return -1; 
	tie(my %TABLENAMES,'DB_File',"TABLENAMES.db",O_CREAT|O_RDWR,0644) or return 0;
	return 1;
}

# Called when user deletes a result table through the "Manage Results" panel. Vacuum clears the memory
# taken up by the db file.
sub RemoveResultTables {
	my ($self,$key) = @_;
	$self->{Connection}->do("DROP TABLE $key" . "_AllHits");
	$self->{Connection}->do("DROP TABLE $key" . "_HitInfo");
	$self->{Connection}->do("DROP TABLE $key" . "_QueryInfo");
	$self->{Connection}->do("VACUUM");
}

# Gets the path separator for different operating systems.
sub GetPathSeparator {
	my ($self) = @_;
	$self->{OS} = $^O;
	if (($self->{OS} eq "darwin") or ($self->{OS} eq "MacOS") or ($self->{OS} eq "linux")) {
		$self->{PathSeparator} = "/";
	}
	elsif ($self->{OS} =~ m/MS/ or $self->{OS} =~ m/win/i) {
		$self->{PathSeparator} = "\\";
	}
	else {
		exit;
	}
}

# Processes string to use as filename
sub ReadyForFile {
    my($self,$name) = @_;
    
    $name =~s/\//_/g;
    $name =~s/\:/_/g;
    $name =~s/\*/_/g;
    $name =~s/\?/_/g;
    $name =~s/\\/_/g;
    $name =~s/\</_/g;
    $name =~s/\>/_/g;
    $name =~s/\"/_/g;
    $name =~s/\|/_/g;
    
    if (length ($name) > 100) {
    	$name = substr($name,0,100)
    }
    return $name;
}

1;