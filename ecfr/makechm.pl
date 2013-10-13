#!/usr/bin/perl -w
use strict;
use ecfr;
use Digest::MD5 qw(md5_hex);
$|=1;
my $dir = shift(@ARGV) || "chm";
if ( -d $dir) { printf("Using directory: $dir\n"); }
else {
printf("Creating directory: $dir\n");
mkdir($dir)
or die("Error: can't create directory $dir: $!\n");
}
my @files; # list of generated files
my ($hhc_title, $hhc_part, $hhc_section, $hhc_subsection);

my $date = ecfr::get_current_date()
or die("Error: can't get current date\n");
printf("ECFR Date: %s\n", $date);
#title 49, part 1845, section 172, subsection 172.101
my $title_number=49;
# title: name, number, url
my $title = undef;
my @titles = ecfr::get_titles();
foreach my $t(@titles) {
$title = $t if $t->{number} == $title_number;
}
die("Error: title not found\n") unless $title;
my $part_number=185;
# part: title, part_begin, part_end
my @parts = ecfr::get_parts($title_number);
my $part = undef;
foreach my $p(@parts) {
if (defined $p->{part_begin} and defined $p->{part_end}) {
$part = $p if $p->{part_begin} <= $part_number and $p->{part_end} >= $part_number;
}
}
die("Error: part not found\n") unless $part;
printf("Got title and part.\n");
# section: base, title
my @sections = ecfr::get_sections($title_number, $part_number);
printf("Got sections.\n");
foreach my $section(@sections) {
$section->{title} = "Untitled" unless $section->{title};
$section->{number} = "Unnumbered" unless $section->{number};
printf("Getting section: %s (%s)", $section->{title}, $section->{number});
# subsection: description, number
my @subsections = ecfr::get_subsections($title_number, $part_number, $section->{base});
foreach my $subsection(@subsections) {
printf("Getting subsection: %s (%s)\n", $subsection->{description}, $subsection->{number});
my $filename = "content_" . md5_hex($date . $title_number . $part_number .  $section->{base} . $subsection->{number}) . ".html";
push(@files, $filename);
unless (-f $dir . "/" . $filename) {
my $content = ecfr::get_content($title_number, $part_number, $section->{base}, $subsection->{number});
#printf("Writing file: %s\n", $filename);
#open(FOUT, ">", $dir . "/" . $filename)
#or die("Error: can't create " . $dir . "/" . $filename . ": $!\n");
#printf FOUT ("<html><head><title>%s</title></head><body>%s</body></html>", $subsection->{description}, $content->{html});
#close FOUT;
}
$hhc_subsection .= help_topic($subsection->{description} . " (" .  $subsection->{number} . ")", $filename);
}
$hhc_section .= help_folder($section->{title} . " (" . $section->{number} . ")", "", $hhc_subsection);
}
$hhc_part .= help_folder($part->{title}, "", $hhc_section);
$hhc_title .= help_folder($title->{name}, "", $hhc_part);
my $hhc_filename = $dir . "/project.hhc";
printf("Writing HHC: %s\n", $hhc_filename);
my $hhc = <<EOT;
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<HTML>
<HEAD>
<meta name="GENERATOR" content="Microsoftreg; HTML Help Workshop 4.1" >
<!-- Sitemap 1.0 -->
</HEAD><BODY>
<UL>
<UL>
$hhc_title
</BODY></HEAD></HTML>
EOT
open(FOUT, ">", $hhc_filename)
or die("Error: can't open $hhc_filename for writing: $!\n");
print FOUT $hhc;
close FOUT;
my $hhp_filename = $dir . "/project.hhp";
printf("Writing HHP: %s\n", $hhp_filename);
my $hhp = <<EOT;
[OPTIONS]
Auto Index=Yes
Compatibility=1.1 or later
Compiled file=ECFR_$date.chm
Contents file=project.hhc
Display compile progress=No
Full-text search=Yes
Language=0x809 English (United Kingdom)
Title=ECFR as of $date
Default topic=main.html

[FILES]
EOT
foreach(@files) { $hhp .= $_ . "\n"; }
open(FOUT, ">", $hhp_filename)
or die("Error: can't open $hhp_filename for writing: $!\n");
print FOUT $hhp;
close FOUT;

sub help_folder {
    my ($name, $url, $contents) = @_;
        my $url_ref = "";
	$url_ref = qq[ <param name="Local" value="$url">  \n] if $url;
	    return <<HELP_FOLDER;
	        <LI> <OBJECT type="text/sitemap">
		        <param name="Name" value="$name">
			        $url_ref
				        <param name="ImageNumber" value="1">
					        </OBJECT>
						        <UL>
							            $contents
								            </UL>
HELP_FOLDER
									    }

sub help_topic {
    my ($name, $url) = @_;
        return <<HELP_TOPIC;
	    <LI> <OBJECT type="text/sitemap">
	            <param name="Name" value="$name">
		            <param name="Local" value="$url">
			        </OBJECT>

HELP_TOPIC
}

