package ClassificationXML;
use XML::Simple;

sub new {
	my ($class,$file_name) = @_;
	my $self = {};
	$self->{XML} = new XML::Simple;
	$self->{ClassificationHash} = $self->{XML}->XMLin($file_name);
	$self->{Title} = $self->{ClassificationHash}->{"Title"};
	bless ($self,$class);
	return $self;
}

sub GetClassifiers {
	my ($self) = @_;
	my @classifier_list = ();
	my $classifiers =  $self->{ClassificationHash}->{"classifier"};
	# case of only one classifier
	if (defined $classifiers->{"item"}) {
		push(@classifier_list,$classifiers->{"name"});
	}
	else {
		for my $key (keys(%{$classifiers})) {
			push(@classifier_list,$key);
		}
	}
	return \@classifier_list;
}

sub PieClassifierData {
	my ($self,$input_class) = @_;
	my $piedata = {"Names"=>[],"Values"=>[],"Total"=>0};
	my $classifiers =  $self->{ClassificationHash}->{"classifier"};
	if (defined $classifiers->{"item"}) {
		for my $item (keys(%{$classifiers->{"item"}})) {
			my $value = $classifiers->{"item"}->{$item}->{"value"};
			if ($value == 0) {
				next;
			}
			push(@{$piedata->{Names}},$item);
			push(@{$piedata->{Values}},$value);
			$piedata->{Total} += $value;
		}
	}
	else {
		for my $class (keys(%{$classifiers})) {
			if ($class eq $input_class) {
				for my $item(keys(%{$classifiers->{$class}->{"item"}})) {
					my $value = $classifiers->{$class}->{"item"}->{$item}->{"value"};
					if ($value == 0) {
						next;
					}
					push(@{$piedata->{Names}},$item);
					push(@{$piedata->{Values}},$value);
					$piedata->{Total} += $value;
				}
			}
		}
	}
	return $piedata;
}

sub PieAllClassifiersData {
	my ($self) = @_;
	my $piedata = {"Names"=>[],"Values"=>[],"Total"=>0};
	my $classifiers =  $self->{ClassificationHash}->{"classifier"};
	if (defined $classifiers->{"item"}) {
		my $value = $classifiers->{"value"};
		if ($value == 0) {
			next;
		}
		push(@{$piedata->{Names}},$classifiers->{"name"});
		push(@{$piedata->{Values}},$value);
		$piedata->{Total} += $value;
	}
	else {
		for my $class (keys(%{$classifiers})) {
			my $value = $classifiers->{$class}->{"value"};
			if ($value == 0) {
				next;
			}
			push(@{$piedata->{Names}},$class);
			push(@{$piedata->{Values}},$value);
			$piedata->{Total} += $value;
		}
	}
	return $piedata;
}

1;