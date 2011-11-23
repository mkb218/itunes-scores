#!/usr/bin/perl -w

use strict;
use Mac::iTunes::Library;
use Mac::iTunes::Library::XML;
use List::Util qw(min sum);
use Data::Dumper;
use Getopt::Long;

my $limit = 3000000000;
GetOptions( "limit=s", \$limit ) || die "couldn't get options $!";
my $mixlimit = $limit / 10;
my $singlelimit = $limit / 10;

my $file = shift @ARGV;

my $lib = Mac::iTunes::Library::XML->parse($file);

my @randchset = qw(a b c d e f g h i j k l m n o p q r s t u v w x y z Q W E R T Y U I O P A S D F G H J K L Z X C V B N M 1 2 3 4 5 6 7 8 9 0);
sub randstr {
	my $out = "";
	for (my $i = 0; $i < 6; ++$i) {
		$out .= $randchset[int(rand(@randchset))];
	}
	return $out;
}

sub add_album_key {
	my ($track) = @_;
	$track->{albumkey} = "";
	
	if (!defined($track->compilation()) || !$track->compilation()) {
		if (defined($track->albumArtist())) {
			$track->{albumkey} .= $track->albumArtist();
		} elsif (defined($track->artist())) {
			$track->{albumkey} .= $track->artist();
		} else {
			$track->{albumkey} .= randstr();
		}
	} else {
		$track->{albumkey} .= "Compilation";
	}	
	if (defined($track->album())) {
		$track->{albumkey} .= $track->album();
	} else {
		$track->{albumkey} .= randstr();
	}
	
	if (exists($track->{"Disc Number"})) {
		$track->{albumkey} .= $track->{"Disc Number"};
	}
}

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
			add_album_key($info);
			if (defined($info->trackNumber)) {
				$albums{$info->{albumkey}}{tracks}[$info->trackNumber-1] = $info;
			} else {
				push @{$albums{$info->{albumkey}}{tracks}}, $info;
			}
#			print "  $song: ".($info->{albumkey})." ".(defined($info->trackNumber)?($info->trackNumber):"")."\n";
			if (!(--$i)) {
				last OUTER;
			}
		}
	}
}

#print Dumper(\%albums);
my $now = time;
$now += 2082826800;
my $maxscore = 0;
my $minscore;
sub fillscore {
	my ($album) = @_;
	if (!exists($album->{score})) {
		$album->{tracks} = [grep {defined $_} @{$album->{tracks}}];
		my @tracks = @{$album->{tracks}};
#		print Dumper(@tracks);
		my $recency = int((sum( map { $now - (defined($_->playDate)?$_->playDate:0) } @tracks )) / 86400 / scalar(@tracks));
		my $adj = 0;
		$album->{avgrating} = sum(map {defined($_->rating)?$_->rating:0} @tracks)/scalar(@tracks);
		$album->{sumsize} = sum(map {(defined($_->size)?$_->size:0)} @tracks);
		$album->{score} = $recency * $album->{avgrating};
		if ($album->{score} > $maxscore) {
			$maxscore = $album->{score};
		}
		if (!defined($minscore) || $album->{score} < $minscore) {
			$minscore = $album->{score};
		}
#		warn $album->{score};
	}
}

sub jitterscore {
	my ($album) = @_;
	my $maxjit = ($maxscore - $minscore) / scalar(keys %albums) * 5;
	$album->{score} *= (rand(0.1) - 0.05) + 1;
}

#print Dumper(\%albums);

foreach my $s (values %albums) {
	fillscore($s);
}

foreach my $s (values %albums) {
	jitterscore($s);
}

my @sortedalbums = sort {$b->{score} <=> $a->{score}} values %albums;
warn scalar(@sortedalbums);
my @tracks;
while ($limit > 0 && scalar(@sortedalbums)) {
	my $album = shift @sortedalbums;
	if (defined($album->{tracks}[0]->grouping) && $album->{tracks}[0]->grouping eq 'Mixes') {
		if ($mixlimit <= $album->{sumsize}) {
			next;
		} else {
			$mixlimit -= $album->{sumsize};
#			warn "m",$mixlimit;
		}
	} elsif (scalar(@{$album->{tracks}}) == 1) {
		if ($singlelimit <= $album->{sumsize}) {
			next;
		} else {
			$singlelimit -= $album->{sumsize};
#			warn "s",$singlelimit;
		}
	}
	last if $limit <= $album->{sumsize};
	$limit -= $album->{sumsize};
#	warn "l$limit";
	push @tracks, @{$album->{tracks}};
		
}

#foreach  (@tracks) {
#	warn $_->{albumkey},$_->name;
#}

print <<EOT;
tell application "iTunes"
	set pname to "iPod Tracks"
	if not exists (some user playlist whose name is pname) then	make user playlist with properties {name:pname}
	set pl to user playlist pname
	delete every track of pl
EOT
foreach (map {$_->trackID}@tracks) {
print <<EOT;
	set t to (first file track of library playlist 1 whose database ID is $_)
	duplicate t to pl
EOT
}
print "end tell";

# my @sorted  = sort {  } map {} values(%{$lib->items})
# foreach () {
# 	@sorted = sort { 
# 		if ( $a->rating() == $b->rating() ) {
# 			return $a->playDate() <=> $b->playDate()
# 		} else {
# 			return $a->rating() == $b->rating();
# 		}
# 	} (@sorted, @$_);
# }
# 
