#!/usr/bin/perl -w

use strict;
use Mac::iTunes::Library;
use Mac::iTunes::Library::XML;
use List::Util qw(min sum);
use Data::Dumper;
use Getopt::Long;

my $file = shift @ARGV;

my $lib = Mac::iTunes::Library::XML->parse($file);

my %items = $lib->items;
my %albums;
my $i = 0;
OUTER: foreach my $artist (keys %items) {
#	print "$artist\n";
#	next unless ($artist eq "Baier/Box" || $artist =~ /Handsome/ || $artist =~ /^Ampfea/);
	foreach my $song (keys %{ $items{$artist} }) {
#		push @{ $items{$artist}{$song}}, $artist;
#		$items{$artist}{$song}{Artist} = $artist;
		
		foreach my $info (@{ $items{$artist}{$song} }) {
			next if $info->trackType ne "File";
			next if defined($info->{Podcast}) && $info->{Podcast};
			if (defined($info->album()) && (!defined($info->compilation()) || !$info->compilation())) {
				if (defined($info->albumArtist())) {
					$albums{$info->album()}{$info->albumArtist()} = 1;
				} else {
					$albums{$info->album()}{$artist} = 1;
				}
			}
		}
	}
}
foreach my $albumtitle (keys %albums) {
	if (scalar(keys %{$albums{$albumtitle}})>1) {
		print $albumtitle, map { "\n  $_" } keys %{$albums{$albumtitle}}, "\n";
	}
}
