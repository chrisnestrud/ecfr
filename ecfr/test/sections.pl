#!/usr/bin/perl -w
use strict;
use ecfr;
my $title = shift(@ARGV) || 49;
my $part = shift(@ARGV) || 185;
my @sections = ecfr::get_sections($title, $part);
foreach my $section(@sections) {
my @keys = qw/ begin end base title /;
foreach my $key(@keys) {
printf("%s: %s\n", $key, $section->{$key});
}
}

