#!/usr/bin/perl -w

use strict;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use WWW::Mechanize;
use HTTP::Cookies;
use Text::CSV;
use Data::Dumper;
use HTML::TreeBuilder::XPath;
use File::LibMagic ':complete';
use IO::Handle;

$| = 1;

my $magic = File::LibMagic->new();

my $tree= HTML::TreeBuilder::XPath->new;

my $csv = Text::CSV->new ( { binary => 1 } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();

my $ua = WWW::Mechanize->new(
    autocheck => 0, 
    cookie_jar => HTTP::Cookies->new( file => "cookies.txt", autosave => 1 ),
    agent => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/536.11 (KHTML, like Gecko) Ubuntu/12.04 Chromium/20.0.1132.47 Chrome/20.0.1132.47 Safari/536.11");

$ua->proxy(['http'] => 'socks://127.0.0.1:10000');

open(TRIED, "tried.txt");
my %tried = ();
if (fileno TRIED) {
    while (<TRIED>) {
        my $nodeid = $_;
        chomp $nodeid;
        if ($nodeid =~ m/^\d+$/) {
            $tried{$nodeid} = 1;
        }
    }
}
close(TRIED);

sub get_pdf {
    my $nodeid = shift;
    my $url = shift;

    print STDERR "\ttrying $url\n";
    my $resp = $ua->get($url, ":content_file" => "$nodeid.pdf");
    if ($resp->is_success) {
        my $ftype = $magic->checktype_filename("$nodeid.pdf");
        print $ftype."\n";
        if ($ftype eq "application/pdf; charset=binary") { return 1; }
        else { unlink "$nodeid.pdf"; return 0; }
    } else {
        print $resp->message."\n";
        return 0;
    }
}

sub find_pdf {
    my @columns = @_;
    my $nodeid = $columns[11];

    if(!$nodeid) { return; }
    if(-e "$nodeid.pdf") { print TRIED "$nodeid\n"; return; }

    if(defined($tried{$nodeid})) { return; }

    my @urls;
    if($columns[7]) { @urls = split(/;/, $columns[7]) };
    if($nodeid !~ m/^\d+$/ || ($#urls == -1 && !$columns[5])) { return; }
    push(@urls, $columns[5]);
    @urls = reverse(@urls);

    print STDERR "node $nodeid:\n";
    foreach my $url (@urls) {
        if ($url eq "") { next; }
        if ($url =~ m!http://books\.google\.com!) { next; }

        my $urlold = $url;
        if ($url =~ m!http://www\.sciencedirect\.com/!) {
            my $resp = $ua->get($url);
            if ($resp->is_success) {
                my $content = $ua->{content};
                if ($content =~ m/<a\s+id="pdfLink"\s+href="(.*?)"/m) {
                    $url = $1;
                }
            }
        }
        if ($url =~ m!^/+(sites.*)!) {
            $url = "http://aitopics.org/$1";
        }
        if ($url =~ m!http://dl\.acm\.org/citation\.cfm\?id=(\d+)!) {
            $url = "http://dl.acm.org/ft_gateway.cfm?id=$1&type=pdf";
        }
        if ($url =~ m!(http://www\.springerlink\.com/content/.*)!) {
            $url = "$1/fulltext.pdf";
        }
        if ($url =~ m!(http://.*)\.short!) {
            $url = "$1.full.pdf";
        }
        if ($url =~ m!http://ieeexplore\.ieee\.org/xpls/abs_all\.jsp\?arnumber=(\d+)!) {
            $url = "http://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=$1";
            my $resp = $ua->get($url);
            if ($resp->is_success) {
                my $content = $ua->{content};
                if ($content =~ m!<frame src="(http://ieeexplore.*?)"!m) {
                    $url = $1;
                }
            }
        }
            
        if ($url =~ m!(http://onlinelibrary\.wiley\.com/doi/.*)/abstract!) {
            $url = "$1/pdf";
        }
        if ($url =~ m!^(http://www\.ams\.org/.*)/(S[\d\-]+)/$!) {
            $url = "$1/$2/$2.pdf";
        }
        if ($url =~ m!http://www\.jstor\.org/(stable|discover)/[\.\d]+/(\d+)!) {
            $url = "http://www.jstor.org/stable/pdfplus/$2.pdf";
        }

        if ($url =~ m!http://citeseerx\.ist\.psu\.edu/viewdoc/summary\?doi=([\.\d]+)!) {
            my $doi = $1;
            $url = "http://citeseerx.ist.psu.edu/viewdoc/download?doi=$doi&rep=rep1&type=pdf";
        }
        if($urlold ne $url) {
            print STDERR "\tchanging to $urlold to $url\n";
        }

        if (get_pdf($nodeid, $url)) { last; }
    }

    print TRIED "$nodeid\n";
}

open(CSV, $ARGV[0]);
open(TRIED, ">>tried.txt");
TRIED->autoflush(1);
while (<CSV>){
    $csv->parse($_);
    my @columns = $csv->fields;
    find_pdf(@columns);
}
close(TRIED);
close(CSV);

