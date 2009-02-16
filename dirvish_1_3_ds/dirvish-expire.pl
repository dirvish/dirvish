#!/usr/bin/perl
# dirvish-expire
# 1.3.X series
# Copyright 2005 by the dirvish project
# http://www.dirvish.org
#
# Last Revision   : $Rev: 651 $
# Revision date   : $Date: 2009-02-04 16:18:18 +0100 (Mi, 04 Feb 2009) $
# Last Changed by : $Author: tex $
# Stored as       : $HeadURL: https://secure.id-schulz.info/svn/tex/priv/dirvish_1_3_1/dirvish-expire.pl $

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
    Rev    => '$Rev: 651 $'     ,
    Date   => '$Date: 2009-02-04 16:18:18 +0100 (Mi, 04 Feb 2009) $'    ,
    Author => '$Author: tex $'  ,
    URL    => '$HeadURL: https://secure.id-schulz.info/svn/tex/priv/dirvish_1_3_1/dirvish-expire.pl $' ,
);

$VERSION =   $CodeID{URL};
$VERSION =~  s#^.*dirvish_##;  # strip off the front
$VERSION =~  s#\/.*##;         # strip off the rear after the last /
$VERSION =~  s#[_-]#.#g;       # _ or - to "."

#----------------------------------------------------------------------------
# Modules and includes
#----------------------------------------------------------------------------
use strict;
no strict qw(refs);
use warnings;

use Time::ParseDate;
use POSIX qw(strftime);
use Getopt::Long;
use Dirvish;

#----------------------------------------------------------------------------
# SIG Handler
#----------------------------------------------------------------------------
$SIG{TERM} = \&sigterm; # handles "kill <PID>"
$SIG{INT} = \&sigterm; # handles Ctrl+C or "kill -2 <PID>"

#----------------------------------------------------------------------------
# Initialisation
#----------------------------------------------------------------------------
my $Options = reset_options(\&usage, @ARGV);     # initialize the %$Options hash
load_master_config('f', $Options);

GetOptions($Options, qw(
    quiet!
    vault=s
    time=s
    pidfile=s
    tree!
    no-run|dry-run
    version
    help|?
    )) or &usage();

ref($$Options{vault}) and $$Options{vault} = undef;

my $expire_time = undef;
$$Options{time} and $expire_time = parsedate($$Options{time});
$expire_time ||= time;

my $pidfile = $$Options{pidfile};
$pidfile =~ s/\/dirvish[.]pid/\/dirvish-expire.pid/;

if(!check_pidfile($pidfile)) {
	print "$0 already running. Aborting at ".strftime('%H:%M:%S', localtime)." - PID: ".$$."\n";
	exit 255; # Abort
}

my @expires = ();
my %unexpired = ();

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
    Dirvish::find(join('/', $bank, $$Options{vault}), $expire_time, $Options, \@expires, \%unexpired);
} else {
    for my $bank (@{$$Options{bank}})
    {
        Dirvish::find(join('/', $bank), $expire_time, $Options, \@expires, \%unexpired);
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

# add nice and ionice to rm execution
my $basecmd = (($$Options{nice} && $$Options{nice} > -1 && &check_nice()) ? &check_nice()." -".$$Options{nice} : '');
$basecmd .= (($$Options{ionice} && $$Options{ionice} > -1 && &check_ionice()) ? &check_ionice()." -n".$$Options{ionice} : '');

# Iterate over the expired images and remove them
for my $expire (sort imsort @expires)
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

	print($basecmd." rm -rf $$expire{path}/tree\n") if($$Options{'no-run'} && !$$Options{quiet});
    system($basecmd." rm -rf $$expire{path}/tree") unless $$Options{'no-run'};
    
    $$Options{tree} and next;

	print($basecmd." rm -rf $$expire{path}\n") if($$Options{'no-run'} && !$$Options{quiet});
    system($basecmd." rm -rf $$expire{path}") unless $$Options{'no-run'};

}
exit 0;
#----------------------------------------------------------------------------
# Subs
#----------------------------------------------------------------------------
# Sort images
sub imsort {
	## WARNING:  don't mess with the sort order, it is needed so that if
	## WARNING:  all images are expired the newest will be retained.
	$$a{vault} cmp $$b{vault}
	  || $$a{branch} cmp $$b{branch}
	  || $$a{created} cmp $$b{created};
}
# Show usage information
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
# Remove the pidfile on exit
END {
	# remove the pidfile on exit
	remove_pidfile($pidfile);
}
# Handle SIGTERM (SIG-15)
sub sigterm
{
	print STDERR "Received SIGTERM. Aborting running backup ...";
	# kill childs - kill(TERM, -$$):
	use POSIX;
	my $cnt = kill(SIGTERM, -$$);
	no POSIX;
	print STDERR "Signaled $cnt processes in current processgroup";
	# quit
	exit;
}
#----------------------------------------------------------------------------
# EOF
#----------------------------------------------------------------------------
