#!/usr/bin/perl -w
use strict;
use ecfr;
my $title = shift(@ARGV) || 49;
my $part = shift(@ARGV) || 185;
my $section = shift(@ARGV) || 172;
my $subsection = shift(@ARGV) || "172.101";
my $current_date = ecfr::get_current_date();
printf("Current date is %s\n", $current_date);
my $basefile = "table_" . $current_date;
my $htmlfile = $basefile . ".html";
my $xlsfile = $basefile . ".xls";
my $content = ecfr::get_content($title, $part, $section, $subsection);
open(FOUT, ">$htmlfile")
or die("Error: can't open $htmlfile for writing: $!\n");
print FOUT $content->{html};
close FOUT;
my $table = ecfr::table_as_hash($content->{html}, 3);
my $str;
for(my $r=1; $r <= $table->{maxrows}; $r+=1) {
for(my $c=1; $c <= $table->{maxcols}; $c+=1) {
if (defined($table->{$r . "." . $c})) {
$str .= $table->{$r . "." . $c};
}
else { $str .= "Undefined (" . $r . ", " . $c . ")"; }
$str .= "\t" if $c < $table->{maxcols};
}
$str .= "\n";
}
open(FOUT, ">$xlsfile")
or die("Error: can't open $xlsfile for writing: $!\n");
print FOUT $str;
close FOUT;
printf("Table has %s rows and %s columns\n", $table->{maxrows}, $table->{maxcols});

