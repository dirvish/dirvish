# dirvish-locate
# 1.3.X series
# Copyright 2005 by the dirvish project
# http://www.dirvish.org
#
# Last Revision   : $Rev: 22 $
# Revision date   : $Date: 2005-03-27 22:13:42 -0800 (Sun, 27 Mar 2005) $
# Last Changed by : $Author: keithl $
# Stored as       : $HeadURL: http://www.dirvish.org/svn/dirvish_1_3_1/dirvish-locate $

#########################################################################
#                                                         		#
#	Licensed under the Open Software License version 2.0		#
#                                                         		#
#	This program is free software; you can redistribute it		#
#	and/or modify it under the terms of the Open Software		#
#	License, version 2.0 by Lauwrence E. Rosen.			#
#                                                         		#
#	This program is distributed in the hope that it will be		#
#	useful, but WITHOUT ANY WARRANTY; without even the implied	#
#	warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR		#
#	PURPOSE.  See the Open Software License for details.		#
#                                                         		#
#########################################################################

my %CodeID = (
    Rev    => '$Rev: 22 $'     ,
    Date   => '$Date: 2005-03-27 22:13:42 -0800 (Sun, 27 Mar 2005) $'    ,
    Author => '$Author: keithl $'  ,
    URL    => '$HeadURL: http://www.dirvish.org/svn/dirvish_1_3_1/dirvish-locate $' ,
);

$VERSION =   $CodeID{URL};
$VERSION =~  s#^.*dirvish_##;  # strip off the front
$VERSION =~  s#\/.*##;         # strip off the rear after the last /
$VERSION =~  s#[_-]#.#g;       # _ or - to "."

use Time::ParseDate;
use POSIX qw(strftime);
use File::Find;
use Getopt::Long;

### require "dirvishlib.pl";

$KILLCOUNT = 1000;
$MAXCOUNT = 100;

sub usage
{
    my $message = shift(@_);

    length($message) and print STDERR $message, "\n\n";

    print STDERR <<EOUSAGE;
USAGE
	dirvish-locate vault[:branch] pattern
	
EOUSAGE

	exit 255;
}

reset_options();          # initialize the %$Options hash

load_master_config();


GetOptions($Options, qw(
    version
    help|?
    )) or usage;

$Vault = shift;
$Vault =~ /:/ and ($Vault, $Branch) = split(/:/, $Vault);
$Pattern = shift;

$Vault && length($Pattern) or usage;

$fullpattern = $Pattern;
$fullpattern =~ /\$$/ or $fullpattern .= '[^/]*$';
($partpattern = $fullpattern) =~ s/^\^//;

for $b (@{$$Options{bank}})
{
    -d "$b/$Vault" and $bank = $b;
}
$bank or seppuku 220, "No such vault: $Vault";

opendir VAULT, "$bank/$Vault" or seppuku 221, "cannot open vault: $Vault";
@invault = readdir(VAULT);
closedir VAULT;

for $image (@invault)
{
    $image eq 'dirvish' and next;
    $imdir = "$bank/$Vault/$image";
    -f "$imdir/summary" or next;
    $conf = loadconfig('R', "$imdir/summary") or next;
    $$conf{Status} eq 'success' || $$conf{Status} =~ /^warn/
        or next;
    $$conf{'Backup-complete'} or next;
    $Branch && $$conf{branch} ne $Branch and next;

    unshift @images, {
        imdir   => $imdir,
        image   => $$conf{Image},
        branch  => $$conf{branch},
        created => $$conf{'Backup-complete'},
    }
}

for $image (sort(imsort @images))
{
    $imdir = $$image{imdir};

    $index = undef;
    -f "$imdir/index.bz2" and $index = "bzip2 -d -c $imdir/index.bz2|";
    -f "$imdir/index.gz" and $index = "gzip -d -c $imdir/index|";
    -f "$imdir/index" and $index = "<$imdir/index";
    $index or next;

    ++$imagecount;

    open INDEX, $index or next;
    while (<INDEX>)
    {
        chomp;

        m($partpattern) or next;

# this parse operation is too slow.  It might be faster as a
# split with trimmed leading whitespace and remerged modtime
        $f = { image => $image };
        (
             $$f{inode},
            $$f{blocks},
            $$f{perms},
            $$f{links},
            $$f{owner},
            $$f{group},
            $$f{bytes},
            $$f{mtime},
            $path
        ) = m<^
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
        $path =~ m($fullpattern) or next;

        exists($match{$path}) or ++$pathcount;
        push @{$match{$path}}, $f;
    }
    if ($pathcount >= $KILLCOUNT)
    {
        print "dirvish-locate: too many paths match pattern, interrupting search\n";
        last;
    }
}

printf "%d matches in %d images\n", $pathcount, $imagecount;

$pathcount >= $MAXCOUNT
    and printf "Pattern '%s' too vague, listing paths only.\n", $Pattern;

for $path (sort(keys(%match)))
{
    $last = undef;
    print $path;

    if ($pathcount >= $MAXCOUNT)
    {
        print "\n";
               next;
    }

    for $hit (@{$match{$path}})
    {
        $inode = $$hit{inode};
        $mtime = $$hit{mtime};
        $image = $$hit{image}{image};
        if ($inode ne $last)
        {
            $linesize = 5 + length($mtime) + length($image);
            printf "\n    %s %s", $mtime, $image;
        } else {
            $linesize += length($image) + 2;
            if ($linesize > 78)
            {
                $linesize = 5 + length($mtime) + length($image);
                print "\n",
                    " " x (5 + length($mtime)),
                    $image;
            } else {
                printf ", %s", $$hit{image}{image};
            }
        }
        $last = $inode;
    }
    print "\n\n";
}

exit 0;

