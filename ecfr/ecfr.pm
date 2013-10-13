#!/users/ccn/bin/perl -w
package ecfr;
use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
require Exporter;
our $VERSION = '1.0';
our @ISA = qw(Exporter);
our @EXPORT = qw( &get_title &get_titles &get_current_date );
my $st = time();
use LWP::UserAgent;
use HTTP::Cookies;
use HTML::TokeParser::Simple;
use DateTime::Format::Strptime;
my $cj = HTTP::Cookies->new; # cookie jar
our $ua = LWP::UserAgent->new; # HTTP user agent
$ua->timeout(300);
$ua->agent("Mozilla/5.0");
$ua->cookie_jar($cj);
   push @{ $ua->requests_redirectable }, 'POST';
my %htmlcache; # html cache
my $debug=1;
my $baseurl = "http://ecfr.gpoaccess.gov/";

sub get_title_html {
my $title = shift;
my @titles = get_titles();
foreach my $t(@titles) {
return get_html($t->{url}) if ($title eq $t->{number});
}
die("Error: page for title $title not found\n");
}

sub get_titles {
my $html = get_html("http://ecfr.gpoaccess.gov/");
my $p = HTML::TokeParser::Simple->new(\$html)
or die("Error: can't initialize HTML TokeParser: $!\n");
my @titles;
# find the "Select a title" form
my $foundform=0;
while(my $ft = $p->get_token()) {
if ($ft->is_start_tag('form') && defined($ft->get_attr('name')) && $ft->get_attr("name") eq "browseselect") {
$foundform=1;
last;
}
}
die("Error: unable to find browseselect form\n") unless $foundform;
# collect titles
while (my $token = $p->get_token()) {
last if ($token->is_end_tag("form"));
if ($token->is_start_tag("option") && defined($token->get_attr("value")) && $token->get_attr("value") =~ /^\//) {
my $title_url =$baseurl . $token->get_attr("value");
my $title_number = "Unknown";
my $title_name = "Unknown";
$token = $p->get_token();
#printf("--Token Start--\n%s\n--Token End--\n", $token->as_is);
if ($token->as_is =~/Title.*?(\d+)&nbsp;-&nbsp;(.*)\s+$/s) {
$title_number = $1;
$title_name = $2;
chomp $title_name;
my $title = {};
$title->{number} = $title_number;
$title->{name} = $title_name;
$title->{url} = $title_url;
push(@titles, $title);
}
}
}
return @titles;
}

sub get_html {
my $url = shift;
$url = $baseurl . $url if ($url =~ /^\//);
$url =~ s/\s|\r|\n//g;
my $cachepath = "cache/";
mkdir($cachepath) unless -d $cachepath;
my $filename = $cachepath . md5_hex($url) . ".cache";
# we use $filename so that if redirected another call to the original
# page will get html for the latest redirect
return $htmlcache{$filename} if defined $htmlcache{$filename};
if (-f $filename) {
open(FIN, "<", $filename)
or die("Error: can't open $filename for reading: $!\n");
my $contents;
read(FIN, $contents, -s $filename);
close FIN;
#printf("Returning from cache: %s\n", $filename);
return $contents;
}
my $resp;
my $html;
    TRYFETCH:
$url = $baseurl . $url if ($url =~ /^\//);
$url =~ s/\s|\r|\n//g;
unless ($url) {
print("get_html: supplied URL is blank\n") if $debug;
return "<html></html>";
}
    # sleep for a haf second so pages aren't fetched to quickly
select(undef, undef, undef, 0.5);
print("URL: $url\n");
$resp = $ua->get($url);
if ($resp->is_success()) {
my @headers=split(/\n/, $resp->headers_as_string());
foreach my $h(@headers) {
#printf("Header: %s\n", $h);
if ($h =~ /Refresh: \d+; URL=(.*)$/) {
$url = $1;
#printf("Refreshing...\n");
goto TRYFETCH;
}
}
$html = $resp->content;
# cache a copy
$htmlcache{$filename} = $html;
open(FOUT, ">", $filename)
or die("Error: can't open $filename for writing: $!\n");
print FOUT $html;
close FOUT;
}
else {
$html = "<html></html>";
printf("Blank html: %s: %s\n", $url, $resp->status_line) if $debug;
}
return $html;
}

sub process_date {
my $pdt = shift;
if (defined $pdt) {
$pdt =~ s/\,//g;
my $dt_parser = DateTime::Format::Strptime->new(pattern => '%b %d %Y');
my $dt_published = $dt_parser->parse_datetime($pdt)
or die("Error: couldn't get date from $pdt\n");
return $dt_published->ymd;
}
else { return "1900-01-01"; }
}

sub element_has {
my ($element, $attr, $text) = (@_);
if (defined $element->attr($attr)) {
$element->attr($attr) =~ /$text/i;
}
}

sub strip_html {
my $html = shift;
$html =~ s/<.*?>//gs;
return $html;
}

sub get_current_date {
my $html = get_html("http://ecfr.gpoaccess.gov/");
if ($html =~ /<STRONG>e-CFR Data is current as of (.*?)<\/STRONG>/) {
my $dt = $1; # date text
return process_date($dt);
}
}

sub table_as_hash {
my $html = shift @_;
my $table_number = shift @_ || 1;
# fix "<TD blah blah/>" which confuses algorithm
$html =~ s/<(td|TD)(.*?)\/>/<$1$2><\/TD>/gs;
my $p = HTML::TokeParser::Simple->new(\$html)
or die("Can't create parser: $!\n");
my $intable=0;
my $data = {};
$data->{maxrows}=$data->{maxcols}=0;
my $rp=0; # row position
my $cp=0; # column position
my $tn=0; # table number found
while (my $token = $p->get_token) {
$tn+=1 if ($token->is_start_tag("table"));
$intable = 1 if ($tn == $table_number);
if ($intable && $token->is_start_tag("tr")) {
$cp=0;
$rp+=1;
#printf("This is row %s\n", $rp);
}
if ($intable and ($token->is_start_tag("td") or $token->is_start_tag("th"))) {
$cp+=1;
while (defined $data->{$rp . "." . $cp}) { 
#printf("Skipping column %s because it already has data.\n", $cp);
$cp+=1;
}
#printf("Getting cell for row %s, column %s\n", $rp, $cp);
my $cell = "";
my $rowspan=0;
my $colspan=0;
$rowspan=$token->get_attr("rowspan") if defined $token->get_attr("rowspan");
$colspan=$token->get_attr("colspan") if defined $token->get_attr("colspan");
$token = $p->get_token;
until ($token->is_end_tag("th") or $token->is_end_tag("td")) {
$cell .= $token->as_is;
$token = $p->get_token;
}
$cell =~ s/\n//gs;
#printf("--Begin Cell--\n%s\n--End Cell--\n", $cell);
if (!defined $data->{$rp . "." . $cp}) {
#printf("Cell will be inserted at row %s, column %s\n", $rp, $cp);
$data->{$rp . "." . $cp} = $cell;
}
else { printf("Error: position at row %s column %s already has data\n", $rp, $cp); }
if ($rowspan > 0) {
#printf("Row span is %s\n", $rowspan);
for(my $counter = $rp+1; $counter <= $rp+$rowspan-1; $counter++) {
#printf("Cell will also be inserted at row %s, column %s\n", $counter, $cp);
$data->{$counter . "." . $cp} = $cell;
}
}
if ($colspan > 0) {
#printf("Col span is %s\n", $colspan);
for(my $counter = $cp+1; $counter <= $cp+$colspan-1; $counter++) {
#printf("Cell will also be inserted at row %s, column %s\n", $rp, $counter);
$data->{$rp . "." . $counter} = $cell;
}
}
}
# update max rows and cols
$data->{maxrows} = $rp if $rp > $data->{maxrows};
$data->{maxcols} = $cp if $cp > $data->{maxcols};
# find end of table
if ($intable && $token->is_end_tag("table")) {
$intable=$rp=$cp=0;
#printf("End of table\n");
}
}
#printf("Table has %s rows and %s columns.\n", $data->{maxrows}, $data->{maxcols});
return $data;
}

sub get_parts {
my $title = shift;
my $table = ecfr::table_as_hash(ecfr::get_title_html($title), 8);
my @parts;
for(my $row=2; $row <= $table->{maxrows}; $row+=1) {
my $part = {};
$part->{title} = strip_html($table->{$row . "." . 1});
$part->{volume} = strip_html($table->{$row . "." . 2});
$part->{chapter} = strip_html($table->{$row . "." . 3});
my $html = $table->{$row . "." . 4};
my $p = HTML::TokeParser::Simple->new(\$html);
while (my $t = $p->get_token()) {
if ($t->is_start_tag("a")) {
$part->{part_url} = $t->get_attr("href");
}
if ($t->is_start_tag("font")) {
$t = $p->get_token();
if ($t->as_is =~ /(\d+)-(\d+)/) {
$part->{part_begin} = $1;
$part->{part_end} = $2;
}
}
}
$part->{entity} = strip_html($table->{$row . "." . 5});
push(@parts, $part) if $part->{part_url};
}
return @parts;
}

sub get_sections {
my($title, $part) = @_;
my @parts = get_parts($title);
my $part_url;
foreach my $p(@parts) {
if (defined($p->{part_begin}) and defined($p->{part_end}) and defined $p->{part_url}) {
#printf("Examining: part_begin %s, part %s, part_end %s\n", $p->{part_begin}, $part, $p->{part_end});
if ($p->{part_begin} <= $part and $p->{part_end} >= $part) {
$part_url = $p->{part_url};
last;
}
}
}
return undef unless $part_url;
#printf("Found Part URL: %s\n", $part_url);
my @sections;
my $section = {};
my $html = get_html($part_url);
my $p = HTML::TokeParser::Simple->new(\$html)
or die("Error: can't initialize HTML TokeParser: $!\n");
my $last_url;
while(my $t = $p->get_token()) {
if ($t->is_start_tag("a")) { $last_url = $t->get_attr("href") if defined $t->get_attr("href"); }
if ($t->as_is =~ /(\d+\.\d+)\s+to\s+(\d+\.\d+)/) {
$section->{url} = $last_url;
$section->{begin} = $1;
$section->{end} = $2;
# if begin is 21.2 and end is 21.8, base is 21
if ($section->{begin} =~ /^(\d+)/) {
$section->{base} = $1;
}
# find <table> then <td>
$t = $p->get_token() until ($t->is_start_tag("table"));
$t = $p->get_token() until ($t->is_start_tag("td"));
$t = $p->get_token();
$section->{title} = $t->as_is;
$t = $p->get_token();
until ($t->is_end_tag("td")) {
$section->{title} .= $t->as_is;
$t = $p->get_token();
}
chomp $section->{title};
push(@sections, $section);
#printf("Title: %s\nURL: %s\nBegin: %s\nEnd: %s\n", $section->{title}, $section->{url}, $section->{begin}, $section->{end});
$section={};
}
}
return @sections;
}

sub get_subsections {
my ($title, $part, $section) = @_;
my @sections = get_sections($title, $part);
my $section_url;
foreach my $s(@sections) {
if (defined($s->{base}) and defined ($s->{url})) {
if ($section == $s->{base}) {
$section_url = $s->{url};
last;
}
}
}
return undef unless $section_url;
my $html = get_html($section_url);
my $p = HTML::TokeParser::Simple->new(\$html)
or die("Error: can't initialize HTML TokeParser: $!\n");
my @subsections;
my $subsection = {};
my $subpart;
my $order=0;
while(my $t = $p->get_token()) {
if ($t->is_start_tag("p") and defined($t->get_attr("class")) and $t->get_attr("class") eq "subpart") {
for(1..2) { $t = $p->get_token(); }
$subpart =$t->as_is;
#printf("Subpart: %s\n", $subpart);
}
if ($t->is_start_tag("table") and defined($t->get_attr("width")) and $t->get_attr("width") eq "480") {
$subsection->{subpart} = $subpart || "Untitled";
$order+=1;
$subsection->{order} = $order;
#printf("Order: %s\n", $order);
$t = $p->get_token until $t->is_start_tag("table");
$t = $p->get_token until $t->is_start_tag("td");
$t = $p->get_token;
my $url = undef;
# some of these are reserved and have text instead of a <a> tag.
$url = $t->get_attr("href") if $t->is_start_tag("a");
$t = $p->get_token();
# unless this subsection has no link
unless ($t->is_end_tag("td")) {
unless ($t->as_is eq "Appendix") {
$subsection->{url} = $url;
#printf("URL: %s\n", $subsection->{url});
until ($t->is_end_tag("a")) {
$subsection->{number_html} .= $t->as_is;
$t = $p->get_token();
}
if ($subsection->{number_html} =~ /(\d+\.\d+)/) {
$subsection->{number} = $1;
}
#printf("Number: %s\n", $subsection->{number});
# look for table, td, next is description
$t = $p->get_token until $t->is_start_tag("table");
$t = $p->get_token until $t->is_start_tag("td");
$t = $p->get_token();
until ($t->is_end_tag("td")) {
$subsection->{description} .= $t->as_is;
$t = $p->get_token();
}
#printf("Description: %s\n", $subsection->{description});
}
else {
# this is an appendix; the first table just says "appendix", the second
# table has the name and description
# go to the next table and td and a
 $t = $p->get_token() until $t->is_start_tag("table");
 $t = $p->get_token() until $t->is_start_tag("td");
 $t = $p->get_token() until $t->is_start_tag("a");
$subsection->{url} = $t->get_attr("href");
#printf("Appendix URL: %s\n", $subsection->{url});
$t = $p->get_token();
$subsection->{number} = $t->as_is;
#printf("Appendix number: %s\n", $subsection->{number});
for(1..2) { $t = $p->get_token(); }
my $desc = $t->as_is;
$desc =~ s/--//;
$subsection->{description} = $desc;
chomp $subsection->{description};
#printf("Appendix description: %s\n", $subsection->{description});
}
push(@subsections, $subsection);
$subsection={};
}
}
}
return @subsections;
}

sub get_content {
my ($title, $part, $section, $subsection) = @_;
die("get_content: title not found\n") unless $title;
die("get_content: part not found\n") unless $part;
die("get_content: section not found\n") unless $section;
die("get_content: subsection not found\n") unless $subsection;
my $content = {};
$content->{title} = $title;
$content->{part} = $part;
$content->{section} = $section;
$content->{subsection} = $subsection;
my @subs = get_subsections($title, $part, $section);
my $url;
foreach my $s(@subs) {
if ($subsection eq $s->{number}) {
$url = $s->{url};
last;
}
}
return undef unless defined $url;
$content->{url} = $url;
my $html = get_html($url);
my $p = HTML::TokeParser::Simple->new(\$html)
or die("Error: can't initialize HTML TokeParser: $!\n");
my $t; # token
while (my $t = $p->get_token()) {
if ($t->is_start_tag("h5")) {
$t = $p->get_token();
until ($t->is_end_tag("h5")) {
$content->{title} .= $t->as_is;
$t = $p->get_token();
}
$t = $p->get_token();
my $chtml; # content html
until ($t->is_start_tag("hr") and $t->get_attr("width") eq "70%" and $t->get_attr("align") eq "center") {
$chtml .= $t->as_is;
$t = $p->get_token();
}
$content->{html} = $chtml;
}
}
return $content;
}

1;
