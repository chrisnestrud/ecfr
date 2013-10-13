#!/usr/bin/perl -w
use strict;
use ecfr;
my $title = shift(@ARGV) || die("Usage: $0 title_number\n");
my @parts = ecfr::get_parts($title);
foreach my $part(@parts) {
my @keys = qw/part_begin part_end entity /;
foreach my $key(@keys) {
printf("%s: %s\n", $key, $part->{$key});
}
}

