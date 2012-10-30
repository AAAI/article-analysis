#!/usr/bin/perl -w

use strict;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use Text::CSV;
use Data::Dumper;

$| = 1;

my $csv = Text::CSV->new ( { binary => 1 } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();

my @articles;

my $earliest_year = 10000;
my $latest_year = 0;

open(CSV, $ARGV[0]);
while (<CSV>){
    $csv->parse($_);
    my @columns = $csv->fields;
    my $nodeid = $columns[11];
    my $authors = $columns[1];
    my $year = $columns[3];
    my $author_first;
    if (defined($authors)){
        ($author_first) = ($authors =~ m/^(.*?),/);
    }
    my $title = $columns[2];

    if (defined($nodeid) && defined($year) && defined($author_first) && defined($title)){
        push(@articles, {nodeid => $nodeid, author_first => $author_first,
                         year => $year, title => $title});
        if ($year < $earliest_year && $year >= 1940) { $earliest_year = $year; }
        if ($year > $latest_year) { $latest_year = $year; }
    }
}

my @potentials;

for (my $i = 0; $i <= $#articles; $i++){
    my %article1 = %{$articles[$i]};

    # my $colorint = int(255 * (($article1{year} - $earliest_year) / 
    #     ($latest_year - $earliest_year)));
    # if ($colorint < 0) { $colorint = 0; }
    # my $color = sprintf("%02x", $colorint);
    # print "$article1{nodeid} [color=\"#$color$color$color\"];\n";

    for (my $j = 0; $j <= $#articles; $j++){
        my %article2 = %{$articles[$j]};
        if (-e "$article2{nodeid}.txt") {
            if ($article2{year} >= $article1{year} && $article2{nodeid} != $article1{nodeid}){
                my $regex = "<".substr($article1{author_first}, 0, 8).">#".
                    substr($article1{title}, 0, 10)."#<".$article1{year}.">";
                $regex =~ s/[\-\*\'\"\`]//g;
                $regex =~ s/\s+/\\s+/g;
                my $match = `agrep -i -4 '$regex' $article2{nodeid}.txt`;
                if ($match =~ m/$article1{author_first}/){
                    my $s = "$article1{author_first} $article1{title} $article1{year} ".
                        "(from: $article2{author_first} $article2{title} $article2{year})\n\n".
                        "$article2{nodeid} -> $article1{nodeid}\n".
                        "agrep -i -4 '$regex' $article2{nodeid}.txt\n\n".
                        "\t$match\n".
                        "\n\n^^^^^^^^^^ $i/$#articles\n\n".
                        "Good?\n\n";
                    
                    my $r = "$article2{nodeid},$article1{nodeid},$article2{year},$article1{year}\n";
                    
                    push(@potentials, [ $s, $r ]);
                }
            }
        }
    }
}

print STDERR "\n\n";

print "nodeid1,nodeid2,year1,year2\n";
foreach my $i (0..$#potentials) {
    my $s = $potentials[$i][0];
    my $r = $potentials[$i][1];

    print STDERR "\n$i/$#potentials\n\n";
    print STDERR $s;

    system "stty", '-icanon', 'eol', "\001"; # for getting a key at a time (getc)
    my $yesno = getc(STDIN);
    system 'stty', 'icanon', 'eol', '^@'; # ASCII NUL
    
    if ($yesno eq 'y'){
        print $r;
    }
    print STDERR "\n";
}
