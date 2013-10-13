#!/usr/bin/perl -w
use FindBin;
use lib "$FindBin::RealBin";
use ecfr;
#$ecfr::debug=1;
my @titles = get_titles();
foreach my $t(@titles) {
printf("%s\n", $t->{name});
}

