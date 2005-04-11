# dirvish-runall
# 1.3.X series
# Copyright 2005 by the dirvish project
# http://www.dirvish.org
#
# Last Revision   : $Rev: 22 $
# Revision date   : $Date: 2005-03-27 22:13:42 -0800 (Sun, 27 Mar 2005) $
# Last Changed by : $Author: keithl $
# Stored as       : $HeadURL: http://www.dirvish.org/svn/dirvish_1_3_khl/dirvish-runall $

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
    URL    => '$HeadURL: http://www.dirvish.org/svn/dirvish_1_3_khl/dirvish-runall $' ,
);

$VERSION =   $CodeID{URL};
$VERSION =~  s#^.*dirvish_##;  # strip off the front
$VERSION =~  s#\/.*##;         # strip off the rear after the last /
$VERSION =~  s#[_-]#.#g;       # _ or - to "."

use Time::ParseDate;
use POSIX qw(strftime);
use Getopt::Long;

### require "dirvishlib.pl";

sub usage
{
    my $message = shift(@_);

    length($message) and print STDERR $message, "\n\n";

    $! and exit(255); # because getopt seems to send us here for death

    print STDERR <<EOUSAGE;
USAGE
	dirvish-runall OPTIONS
OPTIONS
	--config configfile
	--no-run
	--quiet
	--version
EOUSAGE

	exit 255;
}

reset_options();                 # initialize the %$Options hash

GetOptions($Options, qw(
        config=s
        quiet no-run|dry-run
        version help
    )) or usage;

if ($$Options{config})
{
    $Config = loadconfig(undef, $$Options{config})
}
else
{
    load_master_config() ;
}


$$Config{Dirvish} ||= 'dirvish';

$$Options{'no-run'} and $$Options{quiet} = 0;

$errors = 0;

for $sched (@{$$Config{Runall}})
{
    ($vault, $itime) = split(/\s+/, $sched);
    $cmd = "$$Config{Dirvish} --vault $vault";
    $itime and $cmd .= qq[ --image-time "$itime"];
    $$Options{quiet}
        or printf "%s %s\n", strftime('%H:%M:%S', localtime), $cmd;
    $$Options{'no-run'} and next;
    $status = system($cmd);
    $status < 0 || $status / 256 and ++$errors;

}
$$Options{quiet}
    or printf "%s %s\n", strftime('%H:%M:%S', localtime), 'done';


exit ($errors < 200 ? $errors : 199);
