# dirvish-expire.PL
# 1.3.X series
# Copyright 2005 by the dirvish project
# http://www.dirvish.org
#
# Last Revision   : $Rev$
# Revision date   : $Date$
# Last Changed by : $Author$
# Stored as       : $HeadURL$

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

my
%CodeID = (
    Rev    => '$Rev$'     ,
    Date   => '$Date$'    ,
    Author => '$Author$'  ,
    URL    => '$HeadURL$' ,
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

sub usage
{
    my $message = shift(@_);

    length($message) and print STDERR $message, "\n\n";

    print STDERR <<EOUSAGE;
USAGE
	dirvish.expire OPTIONS
	
OPTIONS
	--time date_expression
	--[no]tree
	--vault vault_name
	--no-run
	--quiet
EOUSAGE

	exit 255;
}

reset_options();          # initialize the %$Options hash

load_master_config();

GetOptions($Options, qw(
    quiet!
    vault=s
    time=s
    tree!
    no-run|dry-run
    version
    help|?
    )) or usage;

ref($$Options{vault}) and $$Options{vault} = undef;

$$Options{time} and $expire_time = parsedate($$Options{time});
$expire_time ||= time;


if ($$Options{vault})
{
    my $b;
    my $bank;
    for $b (@{$$Options{bank}})
    {
       	if (-d "$b/$$Options{vault}")
        {
            $bank = $b;
            last;
        }
    }
    $bank or seppuku 252, "Cannot find vault $$Options{vault}";
    find(\&findop, join('/', $bank, $$Options{vault}));
} else {
    for $bank (@{$$Options{bank}})
    {
        find(\&findop, $bank);
    }
}

scalar(@expires) or exit 0;

if (!$$Options{quiet})
{
    printf "Expiring images as of %s\n",
        strftime('%Y-%m-%d %H:%M:%S', localtime($expire_time));
    $$Options{vault} and printf "Restricted to vault %s\n",
        $$Options{vault};
    print "\n";

    printf "%-15s %-15s %-16.16s  %s\n",
        qw(VAULT:BRANCH IMAGE CREATED EXPIRED);
}

for $expire (sort(imsort @expires))
{
    my ($created, $expired);
    ($created = $$expire{created}) =~ s/:\d\d$//;
    ($expired = $$expire{expire}) =~ s/:\d\d$//;
    
    if (!$unexpired{$$expire{vault}}{$$expire{branch}})
    {
        printf "cannot expire %s:%s:%s No unexpired good images\n",
            $$expire{vault},
            $$expire{branch},
            $$expire{image};
        $$expire{status} =~ /^success/
            and ++$unexpired{$$expire{vault}}{$$expire{branch}};

        # By virtue of the sort order this will be the newest 
        # image so that older ones can be expired.
        next;
    }
    $$Options{quiet} or printf "%-15s %-15s %-16.16s  %s\n",
        $$expire{vault} . ':' .  $$expire{branch},
        $$expire{image},
        $created,
        $expired;

    $$Options{'no-run'} and next;

##  This code MAY get replaced by the following code.  There may be
##  a portability issue.  This code was written by EricM,
##  to fix a file removal problem noticed by Michael T.    See the
##  Wiki for ChmodOnExpire

    system("rm -rf $$expire{path}/tree");
    $$Options{tree} and next;

    system("rm -rf $$expire{path}");

##	$exit = system("chmod u+rwX $$expire{path}/tree
##         && find $$expire{path}/tree -type d -exec chmod u+rwX \\{\\} \\;");
##	check_exitcode("Failed to chmod $$expire{path}/tree and subdirectories",
##            "chmod/find", $exit);
##
##      $exit = system("rm -rf $$expire{path}/tree");
##       check_exitcode("Failed to delete $$expire{path}/tree", "rm", $exit);
##
##      $$Options{tree} and next;
##
##	$exit = system("chmod u+rwX $$expire{path}
##         && find $$expire{path} -type d -exec chmod u+rwX \\{\\} \\;");
##	check_exitcode("Failed to chmod $$expire{path} and subdirectories",
##           "chmod/find", $exit);
##
##       $exit = system("rm -rf $$expire{path}");
##      check_exitcode("Failed to delete $$expire{path}", "rm", $exit);

}
exit 0;
