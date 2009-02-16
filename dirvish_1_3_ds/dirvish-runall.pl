#!/usr/bin/perl
# dirvish-runall
# 1.3.X series
# Copyright 2005 by the dirvish project
# http://www.dirvish.org
#
# Last Revision   : $Rev: 658 $
# Revision date   : $Date: 2009-02-09 20:38:02 +0100 (Mo, 09 Feb 2009) $
# Last Changed by : $Author: tex $
# Stored as       : $HeadURL: https://secure.id-schulz.info/svn/tex/priv/dirvish_1_3_1/dirvish-runall.pl $

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

#----------------------------------------------------------------------------
# Revision information
my %CodeID = (
    Rev    => '$Rev: 658 $'     ,
    Date   => '$Date: 2009-02-09 20:38:02 +0100 (Mo, 09 Feb 2009) $'    ,
    Author => '$Author: tex $'  ,
    URL    => '$HeadURL: https://secure.id-schulz.info/svn/tex/priv/dirvish_1_3_1/dirvish-runall.pl $' ,
);

$VERSION =   $CodeID{URL};
$VERSION =~  s#^.*dirvish_##;  # strip off the front
$VERSION =~  s#\/.*##;         # strip off the rear after the last /
$VERSION =~  s#[_-]#.#g;       # _ or - to "."

#----------------------------------------------------------------------------
# Modules and includes
#----------------------------------------------------------------------------
use strict;
use warnings;
use v5.8.0;	# for ithreads

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
our $VERSION;

my $Options = {
        version         => sub {
                        print STDERR "dirvish version $VERSION\n";
                        exit(0);
                },
        help            => \&usage,
};

$Options = reset_options( \&usage, @ARGV);	# initialize the %$Options hash
load_master_config(undef, $Options);		# load master config into $Options

GetOptions($Options, qw(
        config=s
        pidfile=s
        quiet no-run|dry-run
        version help
    )) or &usage();

$$Options{Dirvish} ||= 'dirvish';

$$Options{'no-run'} and $$Options{quiet} = 0;

my $errors = 0;

if(!check_pidfile($$Options{pidfile})) {
	print "$0 already running. Aborting at ".strftime('%H:%M:%S', localtime)." - PID: ".$$."\n";
	exit 255; # Abort
}

my $thmutex = undef;						# Thread mutex
my @threads = undef;						# List of running threads
if($$Options{'Threads'}) {
	#use Thread qw(async);
	use threads; # use ithreads, requires Perl 5.6+
	use Thread::Semaphore;
	$thmutex = Thread::Semaphore->new($$Options{'Threads'});	# Limit the number of running threads
	@threads = ();
}

for my $sched (@{$$Options{Runall}})
{
	my ($vault, $itime) = split(/\s+/, $sched);
	print "runall - vault: $vault\n";
	my $cmd = "$$Options{Dirvish} --vault $vault";
	$itime and $cmd .= qq[ --image-time "$itime"];
	$$Options{quiet}
		or printf "%s %s\n", strftime('%H:%M:%S', localtime), $cmd;
	if($$Options{'Threads'}) {
		#my $t = async {
		#	$thmutex->down();			# Semaphore will block until we have a free slot
		#	$$Options{'no-run'} and $cmd .= " --no-run";	# Actually execute dirvish, even when running
		#	# in no-run mode, but make it also run in no-run mode
		#	print "Thread ".Thread->self->tid()." running cmd: $cmd\n" unless $$Options{quiet};
		#    my $status = system($cmd);
		#    $thmutex->up();				# Release semaphore lock so another thread can run
	    #	return $status;
	    #};
	    my $t = threads->create(sub {
			$thmutex->down();			# Semaphore will block until we have a free slot
			$$Options{'no-run'} and $cmd .= " --no-run";	# Actually execute dirvish, even when running
			# in no-run mode, but make it also run in no-run mode
			print "Thread ".threads->tid()." running cmd: $cmd\n" unless $$Options{quiet};
			sleep (15 * rand(2));
		    my $status = system($cmd);
		    $thmutex->up();				# Release semaphore lock so another thread can run
	    	return $status;
	    });
	    push(@threads,$t);
    } else {
    	# Without threads, everything is done sequential
    	my $status = system($cmd) unless $$Options{'no-run'};
	    $status < 0 || $status / 256 and ++$errors;
    }
}

if($$Options{'Threads'}) {
	# Wait for the threads to finish
	for my $th (@threads) {
		my $status = $th->join();
		$status < 0 || $status / 256 and ++$errors;
	}
}

remove_pidfile($$Options{pidfile});

$$Options{quiet}
    or printf "%s %s\n", strftime('%H:%M:%S', localtime), 'done';


exit ($errors < 200 ? $errors : 199);
#----------------------------------------------------------------------------
# Subs
#----------------------------------------------------------------------------
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
# Remove the pidfile on exit
END {
	# remove the pidfile on exit
	remove_pidfile($$Options{pidfile});
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
