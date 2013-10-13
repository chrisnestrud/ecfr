#!/usr/bin/perl -w
use strict;
use ecfr;
my $title = shift(@ARGV) || 49;
my $part = shift(@ARGV) || 185;
my $section = shift(@ARGV) || 172;
my @subsections = ecfr::get_subsections($title, $part, $section);
foreach my $s(@subsections) {
my @keys = qw/ number description /;
foreach my $key(@keys) {
printf("%s: %s\n", $key, $s->{$key});
}
}

