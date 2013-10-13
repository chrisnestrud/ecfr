#!/usr/bin/perl -w
use strict;
use FindBin;
use lib "$FindBin::RealBin";
use ecfr;
#$ecfr::debug=1;
printf("Current date is %s\n", get_current_date());
my @titles = ecfr::get_titles();
my $title = shift @titles;
print_keys("Title", $title);
my $title_number = $title->{number};
my @parts = ecfr::get_parts($title_number);
my $part = shift @parts;
print_keys("Part", $part);
my $part_number = $part->{part_begin};
my @sections = ecfr::get_sections($title_number, $part_number);
my $section = shift @sections;
print_keys("Section", $section);
my $section_base = $section->{base};
my @subsections = ecfr::get_subsections($title_number, $part_number, $section_base);
my $subsection = shift @subsections;
print_keys("Subsection", $subsection);
my $subsection_number = $subsection->{number};
my $content = ecfr::get_content($title_number, $part_number,
$section_base, $subsection_number);
print_keys("Content", $content);

sub print_keys {
my $thing = shift (@_);
my $href = shift(@_);
my @sortedkeys = sort { $a cmp $b } keys %$href;
printf("--Start keys for %s--\n", $thing);
foreach my $key(@sortedkeys) {
if (defined $href->{$key}) { printf("%s: %s\n", $key, $href->{$key}); }
else { printf("%s: not found in href\n", $key); }
}
printf("--End keys for %s--\n", $thing);
}

