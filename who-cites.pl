#!/usr/bin/perl -w

use strict;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use Text::CSV::Encoded;
use Data::Dumper;

if ($#ARGV < 1){
    print "Usage: who-cites.pl citations.csv classics.csv > updated-classics.csv\n";
    exit;
}

my $csv = Text::CSV::Encoded->new ( { binary => 1, eol => $/, encoding  => "utf8" } )
    or die "Cannot use CSV: ".Text::CSV::Encoded->error_diag ();

my %citations = ();

open(CITATIONS, $ARGV[0]) or die "Could not open $ARGV[0]\n";
while(<CITATIONS>) {
    if (m/^(\d+),(\d+),/){
        # nodeid1 cites nodeid2
        my $nodeid1 = $1;
        my $nodeid2 = $2;
        if (!defined($citations{$nodeid1})){
            $citations{$nodeid1} = [ $nodeid2 ];
        } else {
            push(@{$citations{$nodeid1}}, $nodeid2);
        }
    }
}
close(CITATIONS);

open my $io, "<", $ARGV[1] or die "$ARGV[1]: $!";
while (my $row = $csv->getline ($io)){
    my @columns = @$row;
    my $nodeid = $columns[11];
    if ($nodeid eq "NodeID"){
        push(@columns, "Cites");
    } elsif ($citations{$nodeid}){
        push(@columns, join(";", @{$citations{$nodeid}}));
    }
    $csv->combine(@columns);
    print $csv->string();
}




