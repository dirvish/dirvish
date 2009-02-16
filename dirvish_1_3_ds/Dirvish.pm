package Dirvish;

# 1.3.X series
# Copyright 2006 by the dirvish project
# http://www.dirvish.org
#
#   This is tuned to work with dirvish 1.3.1 .  Please do not use
#   for other applications until dirvish 1.3.X stabilizes.  This
#   will eat your babies.
#
# Last Revision   : $Rev: 652 $
# Revision date   : $Date: 2009-02-04 19:34:29 +0100 (Mi, 04 Feb 2009) $
# Last Changed by : $Author: tex $
# Stored as       : $HeadURL: https://secure.id-schulz.info/svn/tex/priv/dirvish_1_3_1/Dirvish.pm $
#

use 5.006;
use strict;
no strict 'refs';
use warnings;
require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(branch check_exitcode check_expire check_ionice check_nice
	check_pidfile client confdir config dump_config errorscan expire_time
	expires find fsb_file loadconfig load_master_config logappend log_file
	remove_pidfile reset reset_options scriptrun seppuku seppuku_prefix
	slurplist unexpires vault version);

use POSIX qw(strftime);
use Getopt::Long;
use Time::ParseDate;
use Time::Period;

our $VERSION = "1.3.2";

our $CONFDIR = "##CONFDIR##";    # this may get replaced by ModuleBuild
$CONFDIR = "/etc/dirvish" if ( $CONFDIR =~ /##/ );

#########################################################################
#                                                         				#
#	Licensed under the Open Software License version 2.0				#
#                                                         				#
#       This program is free software; you can redistribute it          #
#       and/or modify it under the terms of the Open Software           #
#       License, version 2.0 by Lauwrence E. Rosen.                     #
#                                                                       #
#       This program is distributed in the hope that it will be         #
#       useful, but WITHOUT ANY WARRANTY; without even the implied      #
#       warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR         #
#       PURPOSE.  See the Open Software License for details.            #
#                                                                       #
#########################################################################

my %CodeID = (
	Rev    => '$Rev: 652 $',
	Date   => '$Date: 2009-02-04 19:34:29 +0100 (Mi, 04 Feb 2009) $',
	Author => '$Author: tex $',
	URL    =>
'$HeadURL: https://secure.id-schulz.info/svn/tex/priv/dirvish_1_3_1/Dirvish.pm $',
);

my $CommandArgs = 0;

#----------------------------------------------------------------------------
#
sub confdir {
	return $CONFDIR;
}

#----------------------------------------------------------------------------
# Set the logfiles
#

our $log_file = 0;
sub log_file {
	($log_file) = @_;
}
our $fsb_file = 0;

sub fsb_file {
	($fsb_file) = @_;
}

#----------------------------------------------------------------------------
# check_expire - called from dirvish-expire.
# Tests if a given image ($summary) is past the $expire_time.
#                                           refactored from dirvish-expire.pl

sub check_expire {
	my ( $summary, $expire_time, $path ) = @_;

	my ( $expire, $etime );

	$expire = $$summary{Expire};
	$expire =~ s/^.*==\s+//;
	$expire or return 0;
	$expire =~ /never/i and return 0;

	$etime = parsedate($expire);

	if ( !$etime ) {
		print STDERR
		  "$path: invalid expiration time $$summary{expire}\n";
		return -1;
	}
	$etime > $expire_time and return 0;

	return 1;
}

#----------------------------------------------------------------------------
# find -- is used by dirvish-expire to look for summary files in a bank.
#
#  find should be looking for files of the form:
#  ... /$BANK/$VAULT/$IMAGE/summary, then process those files.
#
#  find will not look inside "tree" files, but it WILL look into
#  any directory of the form /$BANK/$VAULT/*/ for summary files.
#  So take care what you put in your banks.
#
#  For now, find is used only by dirvish-expire, but in the future it will
#  also be used in testing routines, so it stays in the subroutine library.
#                                          refactored from dirvish-expire.pl

sub find {
	my $rpath    = shift;			# root path, i.e. the start path
	my $expire_time = shift;		# when to expire
	my $Options = shift;			# $Options hash
	my $expires = shift;			# A list of expires
	my $unexpired = shift;			# A list of unexpired images
	$rpath =~ s#/*$#/#; 			# make sure path has a trailing slash
	foreach my $file ( glob("$rpath*") ) {
		if ( -d $file ) {
			foreach my $path ( glob("$file/*") ) {
				if ( -d $path && -e "$path/summary" && !-l $path ) {

					my $summary;
					my $etime;

					my $name = "$path/summary";

					$summary = loadconfig( 'R', $name );
					my $status = check_expire( $summary, $expire_time, $path );

					$status < 0 and next;

					$$summary{vault} && $$summary{branch} && $$summary{Image}
					  or next;

					if ( $status == 0 ) {
						(defined($$summary{Status}) && $$summary{Status} =~ /^success/ && -d ( $path . '/tree' ))
							and ++$$unexpired{ $$summary{vault} }{ $$summary{branch} };
						next;
					}

					# Skip this if it was already expired with the tree option, i.e. the tree was removed
					-d ( $path . ( $$Options{tree} ? '/tree' : "") )
						or next;

					push(
						@{$expires},
						{
							vault   => $$summary{vault},
							branch  => $$summary{branch},
							client  => $$summary{client},
							tree    => $$summary{tree},
							image   => $$summary{Image},
							created => $$summary{'Backup-complete'},
							expire  => $$summary{Expire},
							status  => $$summary{Status},
							path    => $path,
						}
					);
				}
			}
		}
	}
}

#----------------------------------------------------------------------------
# seppuku -- Exit with code and message.
#                                               refactored from loadconfig.pl

my $seppuku_prefix = 0;

sub seppuku {
	my ( $status, $message ) = @_;

	chomp $message;
	if ($message) {
		$seppuku_prefix and print STDERR $seppuku_prefix, ': ';
		print STDERR $message, "\n";
	}
	exit $status;
}

sub seppuku_prefix {
	($seppuku_prefix) = @_;
}

#----------------------------------------------------------------------------
# config -- called by $$Options{config}
#
#                                               refactored from loadconfig.pl

sub config {
	my $Options = shift;
	loadconfig( 'f', $_[1], $Options );
}

#----------------------------------------------------------------------------
# client -- called by $$Options{client}
#

sub client {
	my $Options = shift;
	$$Options{client} = $_[1];
	loadconfig( 'fog', "$CONFDIR/$_[1]", $Options );
}

#----------------------------------------------------------------------------
# branch --
#

sub branch {

	my $Options = shift;
	
	if ( $_[1] =~ /:/ ) {
		( $$Options{vault}, $$Options{branch} ) = split( /:/, $_[1] );
	}
	else {
		$$Options{branch} = $_[1];
	}
	loadconfig( 'f', "$$Options{branch}", $Options );
}

#----------------------------------------------------------------------------
# vault -- called by $$Options{vault}
#

sub vault {

	my $Options = shift;

	if ( $_[1] =~ /:/ ) {
		( $$Options{vault}, $$Options{branch} ) = split( /:/, $_[1] );
		loadconfig( 'f', "$$Options{branch}", $Options );
	}
	else {
		$$Options{vault} = $_[1];
		loadconfig( 'f', 'default.conf', $Options );
	}
}

#----------------------------------------------------------------------------
# reset_options --
#

sub reset_options {
	my $usage = shift;

	# retain original command arguments (from where. KHL?)
	$CommandArgs or $CommandArgs = join( ' ', @_ );
	
	my $Options;

	$Options = {
		'Command-Args'  => $CommandArgs,
		'numeric-ids'   => 1,
		'devices'       => 1,
		'permissions'   => 1,
		'stats'         => 1,
		'nice'          => 19,								# nice priority
		'ionice'        => 7,								# ionice priority
		'pidfile'       => '/var/run/dirvish.pid',			# pidfile location
		'checksum'      => 0,
		'init'          => 0,								# initalize the vault
		'sparse'        => 0,
		'whole-file'    => 0,
		'xdev'          => 0,								# cross device boundaries
		'zxfer'         => 0,								# compressed transfer
		'no-run'        => 0,								# test run, no backup made
		'exclude'       => [],
		'expire-rule'   => [],
		'rsync-option'  => [],
		'bank'          => [],								# a list of our banks
		'image-default' => '%Y%m%d%H%M%S',					# image timestamp
		'rsh'           => 'ssh',
		'summary'       => 'short',
		'config'        => sub { &config($Options,@_); },	# call Dirvish::config, pass ref to $Options hash
		'client'        => sub { &client($Options,@_); },	# call Dirvish::client, pass ref to $Options hash
		'branch'        => sub { &branch($Options,@_); },	# call Dirvish::branch, pass ref to $Options hash
		'vault'         => sub { &vault($Options,@_); },	# call Dirvish::vault, pass ref to $Options hash
		'reset'         => sub { &reset($Options,@_); },	# uhm, undocumented
		'version'       => \&version,
		'help'          => $usage,

		#  the following option keys are defined elsewhere in dirvish
		#	'tree'          => undef     ,
		# 'Server'	=> undef     ,
		# 'Image'		=> undef     ,
		# 'Image-now'	=> undef     ,
		# 'Bank'		=> undef     ,
		# 'Reference'	=> undef     ,
		# 'Expire'	=> undef     ,
		# 'image'         => undef     ,
		# 'image-time'    => undef     ,
		# 'image-temp'    => undef     ,
		# 'expire'	=> undef     ,
		# 'reference'	=> undef     ,
		# 'speed-limit'	=> undef     ,
		# 'file-exclude'	=> undef     ,
		# 'index'		=> undef     ,
		# 'pre-server'	=> undef     ,
		# 'pre-client'	=> undef     ,
		# 'post-server'	=> undef     ,
		# 'post-client'	=> undef     ,
		# 'Configfiles'	=> [ ]       ,
		# RSYNC_POPT
		# 'password-file'	=> undef     ,
		# 'rsync-client'	=> undef     ,
	};

	return $Options;
}

#----------------------------------------------------------------------------
# reset -- Reset options to the defaults.
# 

sub reset {
	my $Options = shift;
	if ( $_[1] eq 'default' ) {
		$Options = reset_options();
		print "$_[1] ,  reset_defaults\n";
	}
	else {
		$$Options{ $_[1] } =
		  ref( $$Options{ $_[1] } ) eq 'ARRAY'
		  ? []
		  : undef;
	}
}

#----------------------------------------------------------------------------
# version --
# Print the version information.
#

sub version {
	print STDERR "dirvish version $VERSION\n";
	exit(0);
}

#----------------------------------------------------------------------------
# errorscan -- This looks through the rsync STDERR output
#
#  $status    is a reference to the status hash, with potential keys of
#                   pre-server  pre-client  post-server  post-client
#                   code  warning  error  fatal  message
#  $err_file  is bank/vault/image/rsync_error
#  $err_temp  is bank/vault/image/rsync_error.tmp, which is STDERR from rsync
#
#                                               refactored from loadconfig.pl

sub errorscan {
	my ( $status, $err_file, $err_temp, $runloops, $Options ) = @_;

	my $err_this_loop = 0;
	my $action;
	my $pattern;
	my $severity;
	my $message;

	#  determine severity for various actions, and generate a replacement
	#  error message if the rsync message (second entry) is unclear
	my @erraction = (
		[ 'fatal', '^ssh:.*nection refused', ],
		[ 'fatal', '^\S*sh: .* No such file', ],
		[ 'fatal', '^ssh:.*No route to host', ],

		# KHL 2005 Mar 27  'file has vanished' changed from fatal to warning
		[ 'warning', '^file has vanished: ', ],

		[ 'warning', 'readlink .*: no such file or directory', ],
		[
			'fatal',
			'failed to write \d+ bytes:',
			'write error, filesystem probably full'
		],
		[ 'fatal', 'write failed', 'write error, filesystem probably full' ],
		[ 'error', 'error: partial transfer', 'partial transfer' ],
		[ 'error', 'error writing .* exiting: Broken pipe', 'broken pipe' ],
	);

	open( ERR_FILE, ">>", $err_file );
	open( ERR_TEMP, "<",  $err_temp );
	while (<ERR_TEMP>) {
		chomp;
		s/\s+$//;
		length or next;
		if ( !$err_this_loop ) {
			printf ERR_FILE "\n\n*** Execution cycle %d ***\n\n", $runloops;
			$err_this_loop++;
		}
		print ERR_FILE $_, "\n";

		$$status{code} or next;

		for $action (@erraction) {
			( $severity, $pattern, $message ) = @$action;
			/$pattern/ or next;

			# this is where we set status hash keys  fatal, error, warning  if
			# we locate one of the errors described in the @erraction table

			++$$status{$severity};

			my $msg = $message || $_;
			$$status{message}{$severity} ||= $msg;
			logappend( $log_file, $msg );
			$severity eq 'fatal'
			  and printf STDERR "dirvish %s:%s fatal error: %s\n",
			  $$Options{vault}, $$Options{branch}, $msg;
			last;
		}
		if (/No space left on device/) {
			my $msg = 'filesystem full';
			$$status{message}{fatal} eq $msg and next;

			-f $fsb_file and unlink $fsb_file;
			++$$status{fatal};
			$$status{message}{fatal} = $msg;
			logappend( $log_file, $msg );
			printf STDERR "dirvish %s:%s fatal error: %s\n", $$Options{vault},
			  $$Options{branch}, $msg;
		}
		if (/error: error in rsync protocol data stream/) {
			++$$status{error};
			my $msg = $message || $_;
			$$status{message}{error} ||= $msg;
			logappend( $log_file, $msg );
		}
	}
	close ERR_TEMP;
	close ERR_FILE;
}

#----------------------------------------------------------------------------
# logappend -- Add a message to the given logfile.
# Will open the logfile in append mode, write the message and close it.
#                                                refactored from loadconfig.pl

sub logappend {
	my ( $file, @messages ) = @_;
	my $message;

	open( LOGFILE, '>>' . $file )
	  or seppuku 20, "cannot open log file $file";

	for $message (@messages) {
		print LOGFILE $message, "\n";
	}
	close LOGFILE;
}

#----------------------------------------------------------------------------
# scriptrun --
# Execute an external script
#                                               refactored from dirvish.pl

sub scriptrun {
	my (%A) = @_;
	my ( $cmd, $rcmd, $return );

	$A{now} ||= time;
	$A{log} or seppuku 229, "must specify logfile for scriptrun()";
	ref( $A{cmd} ) and seppuku 232, "$A{label} option specification error";

	$cmd = strftime( $A{cmd}, localtime( $A{now} ) );
	if ( $A{dir} != /^:/ )    # Eric M's BadShellCmd fix of 2004-09-04
	{
		$rcmd = sprintf(
			"%s 'cd %s; %s %s' >>%s",
			( "$A{shell}" || "/bin/sh -c" ),
			$A{dir}, $A{env}, $cmd, $A{log}
		);
	}
	else {
		$rcmd = sprintf( "%s '%s %s' >>%s",
			( "$A{shell}" || "/bin/sh -c" ),
			$A{env}, $cmd, $A{log} );
	}

	$A{label} =~ /^Post/ and logappend( $A{log}, "\n" );

	logappend( $A{log}, "$A{label}: $cmd" );

	$return = system($rcmd);

	$A{label} =~ /^Pre/ and logappend( $A{log}, "\n" );

	return $return;
}

#----------------------------------------------------------------------------
# slurplist --
# ???
#                                               refactored from loadconfig.pl

sub slurplist {
	my ( $key, $filename, $Options ) = @_;
	my $f;
	my $array;

	$filename =~ m(^/) and $f = $filename;
	if ( !$f && ref( $$Options{vault} ) ne 'CODE' ) {
		$f =
		  join( '/', $$Options{Bank}, $$Options{vault}, 'dirvish', $filename );
		-f $f or $f = undef;
	}
	$f or $f = "$CONFDIR/$filename";
	open( PATFILE, "<", $f )
	  or seppuku 229, "cannot open $filename for $key list";
	$array = $$Options{$key};
	while (<PATFILE>) {
		chomp;
		length or next;
		push @{$array}, $_;
	}
	close PATFILE;
}

#----------------------------------------------------------------------------
# loadconfig -- load configuration file
#   SYNOPSYS
#     	loadconfig($opts, $filename, \%data)
#
#   DESCRIPTION
#   	load and parse a configuration file into the data
#   	hash.  If the filename does not contain / it will be
#   	looked for in the vault if defined.  If the filename
#   	does not exist but filename.conf does that will
#   	be read.
#
#   OPTIONS
#	Options are case sensitive, upper case has the
#	opposite effect of lower case.  If conflicting
#	options are given only the last will have effect.
#
#   	f	Ignore fields in config file that are
#   		capitalized.
#
#   	o	Config file is optional, return undef if missing.
#
#   	R	Do not allow recoursion.
#
#   	g	Only load from global directory.
#
#   LIMITATIONS
#   	Only way to tell whether an option should be a list
#   	or scalar is by the formatting in the config file.
#
#   	Options reqiring special handling have to have that
#   	hardcoded in the function.
#
#                                               refactored from loadconfig.pl

sub loadconfig {
	my ( $mode, $configfile, $Options ) = @_;
	my $confile = undef;
	my ( $key, $val );
	my $CONFIG;
	ref($Options) or $Options = {};
	my %modes;
	my $conf;
	my $bank;
	my $k;

	$mode ||= "";    # set (empty) default value

	$modes{r} = 1;
	for $_ ( split( //, $mode ) ) {
		if (/[A-Z]/) {
			$_ =~ tr/A-Z/a-z/;
			$modes{$_} = 0;
		}
		else {
			$modes{$_} = 1;
		}
	}

	$CONFIG = 'CFILE'
	  . (
		defined( $$Options{Configfiles} )
		? scalar( @{ $$Options{Configfiles} } )
		: "0" );

	$configfile =~ s/^.*\@//;

	if ( $configfile =~ m[/] ) {
		$confile = $configfile;
	}
	elsif ( $configfile ne '-' ) {
		if ( !$modes{g} && $$Options{vault} && $$Options{vault} ne 'CODE' ) {
			if ( !$$Options{Bank} ) {
				my $bank;
				for $bank ( @{ $$Options{bank} } ) {
					if ( -d "$bank/$$Options{vault}" ) {
						$$Options{Bank} = $bank;
						last;
					}
				}
			}
			if ( $$Options{Bank} ) {
				$confile = join( '/',
					$$Options{Bank}, $$Options{vault},
					'dirvish',       $configfile );
				-f $confile || -f "$confile.conf"
				  or $confile = undef;
			}
		}
		$confile ||= "$CONFDIR/$configfile";
	}

	if ( $configfile eq '-' ) {
		open( $CONFIG, "<", $configfile ) or seppuku 221, "cannot open STDIN";
	}
	else {
		!-f $confile && -f "$confile.conf" and $confile .= '.conf';

		if ( !-f "$confile" ) {
			$modes{o} and return undef;

			# seppuku 222, "cannot open config file: $configfile";
			seppuku 222, "cannot open config file: $confile";
		}

		grep( /^$confile$/, @{ $$Options{Configfiles} } )
		  and seppuku 224, "ERROR: config file looping on $confile";

		open( $CONFIG, "<", $confile )

		  # or seppuku 225, "cannot open config file: $configfile";
		  or seppuku 225, "cannot open config file: $confile";
	}
	push( @{ $$Options{Configfiles} }, $confile );

	#print "loadconfig - reading config from $confile\n";

	while (<$CONFIG>) {
		chomp;

		#       s/\s*#.*$//;     This line replaced with the three following
		#                        suggested by Dave Howorth on 2005 Oct 27
		s/^#.*$//;
		s/\s*[^\\]#.*$//;
		s/\\#/#/g;
		s/\s+$//;
		/\S/ or next;

		if ( /^\s/ && $key ) {
			s/^\s*//;
			push @{ $$Options{$key} }, $_;
		}
		elsif (/^SET\s+/) {
			s/^SET\s+//;
			for $k ( split(/\s+/) ) {
				$$Options{$k} = 1;
			}
		}
		elsif (/^UNSET\s+/) {
			s/^UNSET\s+//;
			for $k ( split(/\s+/) ) {
				$$Options{$k} = undef;
			}
		}
		elsif (/^RESET\s+/) {
			( $key = $_ ) =~ s/^RESET\s+//;
			$$Options{$key} = [];
		}
		elsif ( /^[A-Z]/ && $modes{f} ) {
			$key = undef;
		}
		elsif (/^\S+:/) {
			( $key, $val ) = split( /:\s*/, $_, 2 );
			length($val) or next;
			$k   = $key;
			$key = undef;

			if ( $k eq 'config' ) {
				$modes{r} and loadconfig( $mode . 'O', $val, $Options );
				next;
			}
			if ( $k eq 'client' ) {
				if ( $modes{r} && ref( $$Options{$k} ) eq 'CODE' ) {
					loadconfig( $mode . 'og', "$CONFDIR/$val", $Options );
				}
				$$Options{$k} = $val;
				next;
			}
			if ( $k eq 'file-exclude' ) {
				$modes{r} or next;

				slurplist( 'exclude', $val, $Options );
				next;
			}
			if ( ref( $$Options{$k} ) eq 'ARRAY' ) {
				push @{ $$Options{$k} }, $_;
			}
			else {
				# TextBooleans - ds 2009
				$val =~ s/^\s*(false|f|no|n|off)\s*$/0/;
				$val =~ s/^\s*(true|t|yes|y|on)\s*$/1/;
				$$Options{$k} = $val;
			}
		}
	}
	close $CONFIG;

	return $Options;
}

#----------------------------------------------------------------------------
# Load the master configuration (usually /etc/dirvish/master.conf)
#
#                                               refactored from dirvish.pl
# similar to      dirvish-runall.pl
# similar to      dirvish-expire.pl
# similar to      dirvish-runall.pl
# mode is passed to loadconfig

sub load_master_config {
	my $mode    = shift;	# mode is passed on to loadconfig, see there
	my $Options = shift;	# this is where the options are stored
	my $Config  = 0;		# placeholder

	# load master configuration file
	if ( $CONFDIR =~ /dirvish$/ && -f "$CONFDIR.conf" ) {
		$Config = loadconfig( $mode, "$CONFDIR.conf", $Options );
	}
	elsif ( -f "$CONFDIR/master.conf" ) {
		$Config = loadconfig( $mode, "$CONFDIR/master.conf", $Options );
	}
	elsif ( -f "$CONFDIR/dirvish.conf" ) {
		seppuku 250, <<EOERR;
ERROR: no master configuration file.
	An old $CONFDIR/dirvish.conf file found.
	Please read the dirvish release notes.
EOERR
	}
	else {
		seppuku 251, "ERROR: no master configuration file";
	}
}

#----------------------------------------------------------------------------
#  This code was suggested as part of the ChmodOnExpire patch by
#  Eric Mountain on 2005-01-29

sub check_exitcode {
	my ( $action, $command, $exit ) = @_;
	my $msg = "WARNING: $action. $command ";

	# Code based on the documentation for the system() call
	# in Programming Perl, 2nd ed.

	$exit &= 0xffff;

	if ( $exit == 0 ) {
		return 1;
	}
	elsif ( $exit == 0xff00 ) {
		$msg .= " failed: $!";
	}
	elsif ( $exit > 0x80 ) {
		$exit >>= 8;
		$msg .= "exited with status $exit.";
	}
	else {
		$msg .= "failed with ";
		if ( $exit & 0x80 ) {
			$exit &= ~0x80;
			$msg .= "coredump from ";
		}
		$msg .= "signal $exit.";
	}

	print STDERR "$msg\n";

	return 0;
}

#----------------------------------------------------------------------------
#  Check if ionice is available
#
# ionice_ok - test if ionice is available and return path to ionice binary
# check kernel version
# ionice need a linux kernel >2.6.13
# with CFQ scheduler to work
#
sub check_ionice() {
	my $out = `uname -r`;
	chomp($out);
	my $ionicebin = `which ionice`;
	chomp($ionicebin);
	$out =~ m/(\d)\.(\d)\.(\d\d).*/;
	if (   $^O eq "linux"
		&& -x $ionicebin
		&& ( $1 > 2 || ( $1 == 2 && ( $2 > 6 || $2 == 6 && $3 >= 13 ) ) ) )
	{
		return $ionicebin;
	}
	else {
		return 0;
	}
}

#----------------------------------------------------------------------------
#  Check if ionice is available
#
# nice_ok - test if nice is available and return path to ionice binary
# needs a linux system and a executable
#
sub check_nice() {
	my $nicebin = `which nice`;
	chomp($nicebin);
	if ( $^O ne "windows" && -x $nicebin ) {
		return $nicebin;
	}
	else {
		return 0;
	}
}

#----------------------------------------------------------------------------
# Write a pidfile containig this process pid
# and return false if the file exists and a process
# with the name of this script and this pid (i.e. this script)
# is already running.
#
sub check_pidfile {
	my $pidfile = shift;

	# Check if this script is already running.
	if ( -f $pidfile ) {
		my $pid = qx(cat $pidfile);
		my $psx = qx(ps x | grep $pid);
		if ( $psx =~ /$pid.*$0/i ) {

			# Check if the script is running too long.
			if ( -M $pidfile >= 1 ) {
				my $runtime = -M $pidfile;
				print
				  "Script is running too long, running since $runtime days.\n";
			}

			# Abort - script is already running
			return 0;
		}
		else {
			print "Stale Pidfile. Previous run exited abnormaly.\n";
			unlink($pidfile);
		}
	}

	# Write this scripts pid.
	open( PIDFILE, ">", $pidfile )
	  || die("Can not write Pidfile to $pidfile: $!");
	print PIDFILE $$;
	close(PIDFILE);
	return 1;
}

#----------------------------------------------------------------------------
sub remove_pidfile {
	my $pidfile = shift;
	
	if ( $pidfile && -e $pidfile ) {
		unlink($pidfile);
	}
}

#----------------------------------------------------------------------------
# Print the content of the configuration hash to STDOUT
sub dump_config {
	my $Config = shift;
	my $name   = shift;
	
	$name ||= "default";
	print "Dumping Config ($name)\n";
	foreach my $key ( sort keys %$Config ) {
		print "Config - Key: $key - Value: $$Config{$key}"
		  . ( ( ref( $$Config{$key} ) eq "ARRAY" )
			? " - Type: "
			  . ref( $$Config{$key} )
			  . " - Size: "
			  . scalar( @{ $$Config{$key} } )
			: "" )
		  . "\n";
		if ( ref( $$Config{$key} ) eq "ARRAY" ) {
			foreach my $e ( @{ $$Config{$key} } ) {
				print "\t ARRAY: $e\n";
			}
		}
	}
	print "Dumping Config ($name) End\n";
}

#----------------------------------------------------------------------------
# end of Dirvish.pm
1;
