#!/usr/bin/perl
# dirvish-locate
# 1.3.X series
# Copyright 2005 by the dirvish project
# http://www.dirvish.org
#
# Last Revision   : $Rev: 656 $
# Revision date   : $Date: 2009-02-08 00:23:29 +0100 (So, 08 Feb 2009) $
# Last Changed by : $Author: tex $
# Stored as       : $HeadURL: https://secure.id-schulz.info/svn/tex/priv/dirvish_1_3_1/dirvish-restore.pl $
# Reference		  : http://wiki.dirvish.org/index.cgi?RestoreSomeFiles
#########################################################################
#                                                         				#
#	Licensed under the Open Software License version 2.0				#
#                                                         				#
#	This program is free software; you can redistribute it				#
#	and/or modify it under the terms of the Open Software				#
#	License, version 2.0 by Lauwrence E. Rosen.							#
#                                                         				#
#	This program is distributed in the hope that it will be				#
#	useful, but WITHOUT ANY WARRANTY; without even the implied			#
#	warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR				#
#	PURPOSE.  See the Open Software License for details.				#
#                                                         				#
#########################################################################
#
#----------------------------------------------------------------------------
# Revision information
#----------------------------------------------------------------------------
my %CodeID = (
	Rev    => '$Rev: 656 $',
	Date   => '$Date: 2009-02-08 00:23:29 +0100 (So, 08 Feb 2009) $',
	Author => '$Author: tex $',
	URL    =>
'$HeadURL: https://secure.id-schulz.info/svn/tex/priv/dirvish_1_3_1/dirvish-restore.pl $',
);

$VERSION = $CodeID{URL};
$VERSION =~ s#^.*dirvish_##;    # strip off the front
$VERSION =~ s#\/.*##;           # strip off the rear after the last /
$VERSION =~ s#[_-]#.#g;         # _ or - to "."

#----------------------------------------------------------------------------
# Modules and includes
#----------------------------------------------------------------------------

use Time::ParseDate;
use POSIX qw(strftime);
use File::Find;
use Getopt::Long;
use strict;
use warnings;
use Dirvish;

#----------------------------------------------------------------------------
# Initialisation
#----------------------------------------------------------------------------
$SIG{TERM} = \&sigterm;    # handles "kill <PID>"
$SIG{INT}  = \&sigterm;    # handles Ctrl+C or "kill -2 <PID>"

my $KILLCOUNT = 1000;
my $MAXCOUNT  = 100;

my $Options = reset_options( \&usage, @ARGV );   # initialize the %$Options hash
load_master_config( 'f', $Options );

GetOptions(
	$Options, qw(
	  version
	  dry-run|no-run
	  help|?
	  )
  )
  or &usage();

my $Vault  = shift;
my $Branch = "default";
$Vault =~ /:/ and ( $Vault, $Branch ) = split( /:/, $Vault );
my $Pattern = shift;
my $Image   = shift;

$Vault && length($Pattern) or &usage();
if ( $Pattern =~ m/^(\*|\?)/ ) {
	$Pattern = "." . $Pattern;    # prepend dot if asterisk or question mark is
	     # the first character. Make rsync-like patterns like *.xml work.
}

my $fullpattern = $Pattern;
my $partpattern = undef;
$fullpattern =~ /\$$/ or $fullpattern .= '[^/]*$';
( $partpattern = $fullpattern ) =~ s/^\^//;

my $bank = undef;
for $b ( @{ $$Options{bank} } ) {
	-d "$b/$Vault" and $bank = $b;
}
$bank or seppuku 220, "No such vault: $Vault";

my @invault = ();
if ($Image) {
	push( @invault, $Image );
}
else {
	opendir VAULT, "$bank/$Vault" or seppuku 221, "cannot open vault: $Vault";
	@invault = readdir(VAULT);
	closedir VAULT;
}

# Load vault specific configuration, we need access to the tree value
loadconfig('f', "$bank/$Vault/dirvish/$Branch.conf", $Options);

# build a list of avilable images
my @images = ();
for my $image (@invault) {
	$image eq 'dirvish' and next;
	my $imdir = "$bank/$Vault/$image";
	-f "$imdir/summary" or next;
	( -l $imdir && $imdir =~ /current/ ) and next;    # skip 'current'-symlink
	my $conf = loadconfig( 'R', "$imdir/summary", $Options ) or next;
	$$conf{Status} eq 'success' || $$conf{Status} =~ /^warn/
	  or next;
	$$conf{'Backup-complete'} or next;
	$Branch && $$conf{branch} ne $Branch and next;

	unshift @images,
	  {
		imdir   => $imdir,
		image   => $$conf{Image},
		branch  => $$conf{branch},
		created => $$conf{'Backup-complete'},
	  };
}

my $imagecount = 0;
my $pathcount  = 0;
my $path       = undef;
my %match      = ();

# search the images
foreach my $image ( sort( imsort_locate @images ) ) {
	my $imdir = $$image{imdir};

	my $index = undef;
	-f "$imdir/index.bz2" and $index = "bzip2 -d -c $imdir/index.bz2|";
	-f "$imdir/index.gz"  and $index = "gzip -d -c $imdir/index|";
	-f "$imdir/index"     and $index = "<$imdir/index";
	$index or next;

	++$imagecount;

	# can't use three-fold open here, see above
	open( INDEX, $index ) or next;
	while (<INDEX>) {
		chomp;

		m($partpattern) or next;

		# this parse operation is too slow.  It might be faster as a
		# split with trimmed leading whitespace and remerged modtime
		my $f = { image => $image };
		(
			$$f{inode}, $$f{blocks}, $$f{perms}, $$f{links}, $$f{owner},
			$$f{group}, $$f{bytes},  $$f{mtime}, $$f{path}
		  )
		  = m<^
            \s*(\S+)        # inode
            \s+(\S+)        # block count
            \s+(\S+)        # perms
            \s+(\S+)        # link count
            \s+(\S+)        # owner
            \s+(\S+)        # group
            \s+(\S+)        # byte count
            \s+(\S+\s+\S+\s+\S+)    # date
            \s+(\S.*)        # path
        $>x;
		$$f{perms} =~ /^[dl]/ and next;
		$$f{path} =~ m($fullpattern) or next;

		exists( $match{ $$image{image} } ) or ++$imagecount;
		++$pathcount;
		push @{ $match{ $$image{image} } }, $f;
	}
	if ( $pathcount >= $KILLCOUNT ) {
		print "dirvish-restore: too many paths match pattern, interrupting search\n";
		last;
	}
}

printf "Found %d matches in %d images\n", $pathcount, $imagecount;

$pathcount >= $MAXCOUNT
  and printf "Pattern '%s' too vague, listing paths only.\n", $Pattern;

my $last     = undef;
my $linesize = 0;

# Print results
print "Select an image to restore from:\n" unless $Image;
my $num = 0;
@images = ();
for my $image ( sort keys %match ) {
	$last = undef;
	print "[$num] - $image\n";
	$num++;
	push( @images, $image );

	if ( scalar( @{ $match{$image} } ) > 10 ) {
		print "\t" . scalar( @{ $match{$image} } ) . " files.\n";
	}
	else {
		for my $hit ( @{ $match{$image} } ) {
			print "\tFile: $$hit{path}\n";
		}
	}
}
if ($num) {
	print "Please select an image to restore from: ";
	my $sel = <STDIN>;
	chomp($sel);
	if ( $sel < scalar(@images) ) {
		print "You chose to restore from image: [$sel] - $images[$sel]\n";
		print "These files will be restored:\n";
		my $image = $images[$sel];
		if(scalar( @{ $match{$image} } ) > 10) {
			# open pipe to PAGER (or less)
			my $pager = $ENV{PAGER} || "less";
			$pager = `which $pager`;
			chomp($pager);
			if(-x $pager) {
				open(PAGER, "|$pager");
				print PAGER "dirvish-restore: Will restore these files:\n";
				print PAGER "Note: Present files will be moved to <filename>.orig.\n\n";
				for my $hit ( @{ $match{$image} } ) {
					print PAGER "File: $$hit{path}\n";
				}
				close(PAGER);
			} else {
				print "\t" . scalar( @{ $match{$image} } ) . " files.\n";
			}
		} else {
			for my $hit ( @{ $match{$image} } ) {
				print "\tFile: $$hit{path}\n";
			}
		}
		print "Do you really want to restore these files into their former location? [y/N] ";
		$sel = <STDIN>;
		chomp($sel);
		if ( $sel =~ m/y/i ) {
			print "Restoring the files ...\n";
			my $ostatus = 0;
			for my $hit ( @{ $match{$image} } ) {
				print "\tFile: $$hit{path}\n" unless $$Options{quiet};
				my $srcpath = $$hit{path};
				$srcpath =~ s/$$Options{tree}//;
				my $src = "$bank/$Vault/$image/tree".$srcpath;
				my $dest = $$hit{path};
				my $cmd = "rsync -qrltHpgoDx --numeric-ids --backup --suffix=orig \"$src\" \"$dest\"";
				#print "$cmd\n" unless $$Options{quiet};
				my $status = (system($cmd) >> 8) unless $$Options{'dry-run'};
				$ostatus = $status if (!$$Options{'dry-run'} && $status != 0);
			}
			print "Done.\n";
			exit $ostatus;
		}
		else {
			print "Aborting.\n";
			exit 255;
		}
	}
	else {
		print "Invalid selection.\n";
		exit 255;
	}
}

exit 0;

#----------------------------------------------------------------------------
# Subs
#----------------------------------------------------------------------------
# Sort images
sub imsort_locate {
	## WARNING:  don't mess with the sort order, it is needed so that if
	## WARNING:  all images are expired the newest will be retained.
	$$a{branch} cmp $$b{branch}
	  || $$a{created} cmp $$b{created};
}

sub usage {
	my $message = shift(@_);

	length($message) and print STDERR $message, "\n\n";

	print STDERR <<EOUSAGE;
USAGE
	dirvish-restorn vault[:branch] pattern [image]
	
	Pattern can be any PCRE.
	
EOUSAGE
	exit 255;
}

# Handle SIGTERM (SIG-15)
sub sigterm {
	print STDERR "Received SIGTERM. Aborting running backup ...";

	# kill childs - kill(TERM, -$$):
	use POSIX;
	my $cnt = kill( SIGTERM, -$$ );
	no POSIX;
	print STDERR "Signaled $cnt processes in current processgroup";

	# quit
	exit;
}

#----------------------------------------------------------------------------
# EOF
#----------------------------------------------------------------------------
