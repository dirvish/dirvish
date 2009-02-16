#!/usr/bin/perl
# dirvish
# 1.3.X series
# Copyright 2009 by the dirvish project
# http://www.dirvish.org
#
# Last Revision   : $Rev: 622 $
# Revision date   : $Date: 2009-01-26 22:27:17 +0100 (Mo, 26 Jan 2009) $
# Last Changed by : $Author: tex $
# Stored as       : $HeadURL: https://secure.id-schulz.info/svn/tex/priv/dirvish_1_3_1/contrib/dirvish-setup.pl $
#
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
# This is a curses based setup script for dirivsh. It is meant to create
# a base configuration once dirvish is installed.
#

use warnings;
use strict;
use Curses::UI;

my $master_conf = <<EOCONF;
bank:
        BANKDIR
xdev: 1
index: gzip
image-default: %Y%m%d-%H:%M
nice: 19
ionice: 7

exclude:
        lost+found/
        core
        .nfs*
        *.log
        EXCLUDE

Runall:
RUNALL

expire-default: +DAILY_DAYS days
expire-rule:
# MIN HR DOM MON DOW STRFTIME_FMT
   *  *   *   *   1  +WEEKLY_MONTHS months
EOCONF

my $vault_conf = <<EOCONF;
client: HOSTNAME
tree: VAULT
ionice: 7
nice: 19
exclude:
        *.bak
        .mozilla/firefox/*.default/Cache/*
EOCONF

my $hostname = `hostname`;
chomp($hostname);

my $cmd;

my @vaults = ();

my $cui = new Curses::UI(
	-color_support => 1,
);

$cui->dialog(
	-message	=> "Welcome to the Dirivsh Setup",
	-buttons	=> ['ok'],
	-values		=> [1],
	-title		=> 'Welcome',	
);

my $bank = $cui->dirbrowser(
	-title		=> "Where do you want to store your Backups?",
);

my $days = $cui->question(
	-question	=> "How long do you want to store your daily backups? Please specify in days.",
);

my $months = $cui->question(
	-question	=> "How long do you want to store your monthly backups? Please specify in months.",
);

my $yes = $cui->dialog(
	-message	=> "Create directory $bank, subdirectories and /etc/dirvish/master.conf?",
	-buttons	=> ['yes','no'],
	-values		=> [1,0],
	-title		=> 'Continue?',
);

if($yes) {
	my $runall = "";
	foreach my $mount (`mount`) {
		$mount !~ m#^(/dev/.*) on (.*) type# and next;
		my $dev = $1;
		my $mp = $2;
		my $vault = $mp;
		$vault =~ s#^/##; # remove first /
		$vault =~ s#[/ ]#_#; # replace other / by _
		$vault = "root" if !$vault;
		my $config = $vault_conf;
		$config =~ s/HOSTNAME/$hostname/;
		$config =~ s/VAULT/$mp/;
		$runall .= "\t$vault\n";
		push(@vaults, $vault);
		$cmd = "mkdir -p $bank/$vault/dirvish/";
		system($cmd);
		my $conf_path = "$bank/$vault/dirvish/default.conf";
		if(-f $conf_path) {
			$conf_path .= ".setup"; # do not overwrite existing config
		}
		open(CONF, ">$conf_path");
		print CONF $config;
		close(CONF);
	}
	$master_conf =~ s/BANKDIR/$bank/;
	$master_conf =~ s/EXCLUDE/$bank/;
	$master_conf =~ s/RUNALL/$runall/;
	$master_conf =~ s/DAILY_DAYS/$days/;
	$master_conf =~ s/WEEKLY_MONTHS/$months/;
	my $conf_path = "/etc/dirivsh/master.conf";
	if(-f $conf_path) {
		$conf_path .= ".setup";
	}
	open(CONF, ">$conf_path");
	print CONF $master_conf;
	close(CONF);
} else {
	print "User aborted.\n";
	exit 255;
}

$yes = $cui->dialog(
	-message	=> "Initalize the vaults?",
	-buttons	=> ['yes','no'],
	-values		=> [1,0],
	-title		=> 'Continue?',
);

if($yes) {
	foreach my $vault (@vaults) {
		$cmd = "dirivsh --init --vault $vault &";
		system($cmd);
	}
}
exit 0;