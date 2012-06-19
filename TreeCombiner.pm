=head1 NAME

TreeCombiner

=head1 DESCRIPTION

=cut

package TreeCombiner;

use TaxonomyXML;

sub new {
	my ($class) = @_;
	my $self = {};
	bless ($self,$class);
	return $self;
}

sub CombineTrees {
	my ($self,$tree_files) = @_;
	my %data = ();
	my $tree;
	for my $file(@$tree_files) {
		my $tax_xml = TaxonomyXML->new();
		# add an exception if file is not phyloxml
		$tax_xml->AddFile($file);
		
		if (not defined $tree) {
			$tree = $tax_xml->{Tree};
			for my $node($tree->get_nodes) {
				$data{$node->id} = $tax_xml->GetValue($node);					
			}
		}
		else {
			for my $node($tax_xml->{Tree}->get_nodes) {
				$tree->get_root_node()->add_Descendent($node);
				$data{$node->id} += $tax_xml->GetValue($node);
			}
		}
	}
	return ($tree,\%data);
}

1;