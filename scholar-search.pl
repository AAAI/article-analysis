#!/usr/bin/perl -w

use strict;
use Carp;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use LWP::UserAgent;
use WWW::Mechanize;
use URI::Escape;
use HTML::TreeBuilder::XPath;
use My::Google::Scholar::Paper;
use Data::Dumper;
use Text::CSV::Encoded;
use HTTP::Cookies;
use Text::LevenshteinXS qw(distance);

$| = 1;


my %cookies = ();

my $csv = Text::CSV::Encoded->new ( { binary => 1, eol => $/, encoding => "utf8" } )
    or die "Cannot use CSV: ".Text::CSV->error_diag ();

my $ua = WWW::Mechanize->new ( autocheck => 0, 
                               cookie_jar => HTTP::Cookies->new( file => "scholar-cookies.txt" ),
                               agent => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/536.11 (KHTML, like Gecko) Ubuntu/12.04 Chromium/20.0.1132.47 Chrome/20.0.1132.47 Safari/536.11" );

# grab IJCAI proceedings links first
my $tree1 = HTML::TreeBuilder::XPath->new;
$ua->get("http://ijcai.org/Past%20Proceedings/");
$tree1->parse_content($ua->{content});
my @ijcai_year_links = $tree1->findnodes('/html/body//a');
my %ijcai_index = ();
foreach my $n (@ijcai_year_links){
    my $year = $n->as_text();
    my $url = $n->attr('href');
    my $ua2 = $ua->clone();
    $ua2->get($url);
    my $tree2 = HTML::TreeBuilder::XPath->new;
    $tree2->parse_content($ua2->{content});
    my @ijcai_papers = $tree2->findnodes('/html/body//a');
    foreach my $p (@ijcai_papers){
        my $base_url = "http://ijcai.org/Past%20Proceedings/$url";
        $base_url =~ s!/[^/]*$!/!;
        $ijcai_index{$year}{$p->as_text()} = $base_url.$p->attr('href');
    }
}

sub search_title {
    my $title = shift;
    my $author = shift;
    my $query = uri_escape("$author $title");
    my $url = "http://scholar.google.com/scholar?hl=en&q=$query&as_sdt=1%2C36";
    my $resp = $ua->get($url);
    my $content = "";
    my $tree= HTML::TreeBuilder::XPath->new;

    while (! $resp->is_success){
        $content = $ua->{content};
        $ua->form_number(1);
        $tree->parse($content);
        my @captcha_images = $tree->findnodes('/html/body//img');
        if (@captcha_images) {
            my $captcha_src = $captcha_images[0]->attr('src');

            my $tmpua = $ua->clone();
            $tmpua->get("http://scholar.google.com/$captcha_src", ":content_file" => "captcha.jpg");
            
            `eog captcha.jpg &`;
            my $answer = <STDIN>;
            chomp $answer;
            $resp = $ua->get("http://www.google.com/sorry/Captcha?continue=".
                             uri_escape($ua->value("continue"))."&captcha=$answer&submit=Submit&id=".
                             $ua->value("id"));
        } else {
            sleep 20;
            $ua = WWW::Mechanize->new ( autocheck => 0, 
                                        cookie_jar => HTTP::Cookies->new( file => "scholar-cookies.txt" ),
                                        agent => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/536.11 (KHTML, like Gecko) Ubuntu/12.04 Chromium/20.0.1132.47 Chrome/20.0.1132.47 Safari/536.11" );
            $resp = $ua->get($url);
        }
    }
    $content = $ua->{content};

    if ($content =~ m/<META HTTP-EQUIV="refresh" content="1; url=(.*?)">/){
        $ua->get($1);
        $content = $ua->{content};
    }

    $tree->parse($content);
    
    my @papers_html = $tree->findnodes( '/html/body//div[@class="gs_r"]' );
    my @papers;
    for my $n (@papers_html ) {
        my $paper = My::Google::Scholar::Paper->new($n->as_XML_indented);
        push(@papers, $paper);
        last; # only get one paper link (top)
    }
    return @papers;
}

open my $io, "<", $ARGV[0] or die "$ARGV[0]: $!\n";
while (my $row = $csv->getline ($io)){
    my @columns = @$row;
    my $title = $columns[2];
    my $authors = $columns[1];
    my $year = $columns[3];
    my $guid = $columns[0];
    my $source = $columns[4];

    print STDERR $guid." | ".$title."\n";

    if ($source =~ m/IJCAI/i){
        foreach my $article (keys %{$ijcai_index{$year}}){
            if (distance($title, $article) < 4){
                $columns[5] = $ijcai_index{$year}{$article};
                print STDERR "UPDATED\n";
                last;
            }
        }
    } elsif($columns[5] eq "") {
        my @papers = search_title($title, $authors);
        my @urls;
        my @linktitles;
        my $i = 1;
        foreach my $paper (@papers){
            if (defined($paper->url())){
                push(@urls, $paper->url());
                push(@linktitles, "Link $i");
                $i++;
            }
        }
        if($#urls >= 0) {
            $columns[5] = $urls[0];
            print STDERR "UPDATED\n";
        }
        if($#urls >= 1) {
            shift @linktitles;
            shift @urls;
            if ($columns[6] eq ""){
                $columns[6] = join(";", @linktitles);
                $columns[7] = join(";", @urls);
            }
            else {
                $columns[6] = $columns[6].";".join(";", @linktitles);
                $columns[7] = $columns[7].";".join(";", @urls);
            }
        }
        sleep 2;
    }
    $csv->combine(@columns);
    print $csv->string();
}
