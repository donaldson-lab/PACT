package TaxonomyXML;
use Bio::TreeIO::phyloxml;

sub new {
	my ($class) = @_;
	my $self = {};
	bless ($self,$class);
	return $self;
}

sub AddFile {
	my ($self,$phyloxml_file) = @_;
	$self->{TreeIO} = new Bio::TreeIO(-file=>$phyloxml_file,-format=>'phyloxml');
	$self->{Tree} = $self->{TreeIO}->next_tree;
	$self->{Title} = $self->{Tree}->get_tag_values("Title");
	$self->{RootName} = $self->GetName($self->{Tree}->get_root_node());
}

# get the names and values (in a special hash) of all items of a particular rank in a subtree specified by the sub_node_name
sub PieDataNode {
	my ($self,$sub_node_name,$rank) = @_;
	my $sub_node = $self->FindNode($sub_node_name);
	return $self->PieDataRank($sub_node,$rank);
}

sub PieDataRank {
	my ($self,$sub_node,$rank) = @_;
	my %pie_data = {"Names"=>[],"Values"=>[],"Total"=>0};
	my $subtotal = 0;
	$pie_data{"Total"} = $self->GetValue($sub_node);
	if ($sub_node->descendent_count == 0) {
		if ($self->GetRank($sub_node) eq $rank) {
			push(@{$pie_data{"Names"}},$self->GetName($sub_node));
			push(@{$pie_data{"Values"}},$self->GetValue($sub_node));
			$subtotal += $self->GetValue($sub_node);
		}
		elsif ($rank eq "species" and $self->GetRank($sub_node->ancestor()) eq "species") {
			push(@{$pie_data{"Names"}},$self->GetName($sub_node));
			push(@{$pie_data{"Values"}},$self->GetValue($sub_node));
			$subtotal += $self->GetValue($sub_node);
		}
		return \%pie_data;
	}
	
	for my $sub_sub_node($sub_node->get_all_Descendents) {
		if ($self->GetRank($sub_sub_node) eq $rank){
			push(@{$pie_data{"Names"}},$self->GetName($sub_sub_node));
			push(@{$pie_data{"Values"}},$self->GetValue($sub_sub_node));
			$subtotal += $self->GetValue($sub_sub_node);
		}
		#elsif ($rank eq "species" and $self->GetRank($sub_sub_node->ancestor()) eq "species") {
		#	push(@{$pie_data{"Names"}},$self->GetName($sub_sub_node));
		#	push(@{$pie_data{"Values"}},$self->GetValue($sub_sub_node));
		#	$subtotal += $self->GetValue($sub_sub_node);
		#	print $self->GetName($sub_sub_node) . "\n";
		#}
	}
	
	# The 'unassigned' case
	my $unassigned_count = $pie_data{"Total"} - $subtotal;
	if ($unassigned_count > 0) {
		push(@{$pie_data{"Names"}},"Unassigned");
		push(@{$pie_data{"Values"}},$unassigned_count);
	}
	
	return \%pie_data;
}

sub GetTaxonomyAnnotation {
	my ($self,$node,$get_key) = @_;
	
	my $ac = $node->annotation();
	foreach my $key ( $ac->get_all_annotation_keys() ) {
		if ($key eq "taxonomy") {
			my @values = $ac->get_Annotations($key);
			my $taxonomy = $values[0];
			foreach my $key ( $taxonomy->get_all_annotation_keys()) {
				if ($key eq $get_key) {
					my @key_values = $taxonomy->get_Annotations($key);
					foreach my $key_value(@key_values) {
						my $ret_value = $key_value->display_text;
						chomp $ret_value;
						return $ret_value;
					}
				}
			}
		}
    }
}

sub GetCladeAnnotation {
	my ($self,$node,$get_key) = @_;
	my $ac = $node->annotation();
	foreach my $key ( $ac->get_all_annotation_keys() ) {
		if ($key eq $get_key) {
			my @values = $ac->get_Annotations($key);
			foreach my $value(@values) {
				my $ret_value = $value->display_text;
				chomp $ret_value;
				return $ret_value;
			}
		}
	}
	
}

sub GetID {
	my ($self,$node) = @_;
	$self->GetCladeAnnotation($node,"name");
}

sub GetName {
	my ($self,$node) = @_;
	return $self->GetTaxonomyAnnotation($node,"scientific_name");
}

sub GetRank {
	my ($self,$node) = @_;
	return $self->GetTaxonomyAnnotation($node,"rank");
}

sub GetValue {
	my ($self,$node) = @_;
	$self->GetCladeAnnotation($node,"value");
}

sub FindNode {
	my ($self,$sub_node_name) = @_;
	for my $node($self->{Tree}->get_nodes) {
		if ($self->GetName($node) eq $sub_node_name) {
			return $node;
		}
	}
}

sub GetNamesAlphabetically {
	my ($self) = @_;
	my @node_names = ();
	for my $node($self->{Tree}->get_nodes) {
		push(@node_names,$self->GetName($node));
	}
	my @alpha = (sort {lc($a) cmp lc($b)} @node_names);
	return \@alpha;
}

sub GetNodesLevel {
	my ($self,$level) = @_;
	my @level_nodes = ();
	for my $node($self->{Tree}->get_nodes) {
		if ($self->GetRank($node) eq $level) {
			push(@level_nodes,$self->GetRank($node));
		}
	}
	return \@level_nodes;
}

# saves the tree to a phyloxml file
sub SaveTreePhylo {
	my ($self,$tree,$data,$title,$file_path) = @_;
	$tree->remove_all_tags();
	$tree->add_tag_value("Title",$title);
	
	open(my $handle, ">>" . $file_path . ".xml");
	my $out = new Bio::TreeIO(-fh => $handle, -format => 'phyloxml');
	
	for my $node($tree->get_nodes) {
		my $ann = $node->annotation;
		foreach my $key ( $ann->get_all_annotation_keys() ) {
			if ($key eq "value") {
				$ann->remove_Annotations($key);
			}
		}
		my $value = $data->{$node->id};
		$out->add_phyloXML_annotation(-obj=>$node,-xml=>"<value>$value</value>");
	}
	$out->write_tree($tree);
	#close $handle;
}

# prints the text file with values for each node
sub PrintSummaryText {
	my ($self,$tree,$data,$sub_node_name,$rank,$dir,$path) = @_;
	
	chdir($dir);
	
	sub GetDepth {
		my ($node,$rank) = @_;
		my $depth = 0;
		while (defined $node->ancestor) {
			if ($self->GetRank($node) eq $rank) { return $depth;}
			$depth++;
			$node = $node->ancestor;
		}
		return $depth;
	}
	
	sub AboveRank {
		my ($node,$rank) = @_;
		if ($self->GetRank($node) eq $rank) {
			return 0;
		}
		while (defined $node->ancestor) {
			$node = $node->ancestor;
			if ($self->GetRank($node) eq $rank) {
				return 0;
			}
		}
		return 1;
	}
	
	sub IsDescendent {
		my ($node,$sub_node_name) = @_;
		if ($self->GetName($node) eq $sub_node_name) {
			return 1;
		}
		while (defined $node->ancestor) {
			$node = $node->ancestor;
			if ($self->GetName($node) eq $sub_node_name) {
				return 1;
			}
		}
		return 0;
	}
	
	open(TREE,'>>' . $path . ".txt");
	for my $node($tree->get_nodes) {
		next unless IsDescendent($node,$sub_node_name) == 1 and $sub_node_name ne "";
		next unless AboveRank($node,$rank) == 0 and $rank ne "";
		my $space = "";
		my $depth = GetDepth($node,$rank);
		for (my $i=0; $i<$depth; $i++) {
			$space = $space . "  ";
		}
		print TREE $space . $self->GetName($node) . ": " . $data->{$node->id} . "\n";
	}
	close TREE;
}


1;