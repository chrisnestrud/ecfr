#!/usr/bin/perl -w
use strict;
use ecfr;
my $title = shift(@ARGV) || 49;
my $part = shift(@ARGV) || 185;
my $section = shift(@ARGV) || 172;
my $subsection = shift(@ARGV) || "172.101";
my $content = ecfr::get_content($title, $part, $section, $subsection);
printf("Title: %s\n", $content->{title});

