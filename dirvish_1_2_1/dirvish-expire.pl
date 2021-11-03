

#       $Id: dirvish-expire.pl,v 12.0 2004/02/25 02:42:14 jw Exp $  $Name: Dirvish-1_2 $

$VERSION = ('$Name: Dirvish-1_2_1 $' =~ /Dirvish/i)
	? ('$Name: Dirvish-1_2_1 $' =~ m/^.*:\s+dirvish-(.*)\s*\$$/i)[0]
	: '1.1.2 patch' . ('$Id: dirvish-expire.pl,v 12.0 2004/02/25 02:42:14 jw Exp $'
		=~ m/^.*,v(.*:\d\d)\s.*$/)[0];
$VERSION =~ s/_/./g;


#########################################################################
#                                                         		#
#	Copyright 2002 and $Date: 2004/02/25 02:42:14 $
#                         Pegasystems Technologies and J.W. Schultz 	#
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

use Time::ParseDate;
use POSIX qw(strftime);
use File::Find;
use Getopt::Long;

sub loadconfig;
sub check_expire;
sub findop;
sub imsort;
sub seppuku;

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

$Options = 
{ 
	help		=> \&usage,
	version		=> sub {
			print STDERR "dirvish version $VERSION\n";
			exit(0);
		},
};

if ($CONFDIR =~ /dirvish$/ && -f "$CONFDIR.conf")
{
	loadconfig(undef, "$CONFDIR.conf", $Options);
}
elsif (-f "$CONFDIR/master.conf")
{
	loadconfig(undef, "$CONFDIR/master.conf", $Options);
}
elsif (-f "$CONFDIR/dirvish.conf")
{
	seppuku 250, <<EOERR;
ERROR: no master configuration file.
	An old $CONFDIR/dirvish.conf file found.
	Please read the dirvish release notes.
EOERR
}
else
{
	seppuku 251, "ERROR: no global configuration file";
}

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
	# Follow symlinks
	find( {wanted => \&findop, follow => 1}, join('/', $bank, $$Options{vault}));
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

	system("rm -rf $$expire{path}/tree");
	$$Options{tree} and next;

	system("rm -rf $$expire{path}");
}

exit 0;

sub check_expire
{
	my ($summary, $expire_time) = @_;

	my ($expire, $etime, $path);

	$expire = $$summary{Expire};
	$expire =~ s/^.*==\s+//;
	$expire or return 0;
	$expire =~ /never/i and return 0;

	$etime = parsedate($expire);

	if (!$etime)
	{
		print STDERR "$File::Find::dir: invalid expiration time $$summary{expire}\n";
		return -1;
	}
	$etime > $expire_time and return 0;

	return 1;
}

sub findop
{
	if ($_ eq 'tree')
	{
		$File::Find::prune = 1;
		return 0;
	}
	if ($_ eq 'summary')
	{
		my $summary;
		my ($etime, $path);

		$path = $File::Find::dir;

		$summary = loadconfig('R', $File::Find::name);
		$status = check_expire($summary, $expire_time);
		
		$status < 0 and return;

		$$summary{vault} && $$summary{branch} && $$summary{Image}
			or return;

		if ($status == 0)
		{
			$$summary{Status} =~ /^success/ && -d ($path . '/tree')
				and ++$unexpired{$$summary{vault}}{$$summary{branch}};
			return;
		}

		-d ($path . ($$Options{tree} ? '/tree': undef)) or return;

		push (@expires, {
				vault	=> $$summary{vault},
				branch	=> $$summary{branch},
				client	=> $$summary{client},
				tree	=> $$summary{tree},
				image	=> $$summary{Image},
				created	=> $$summary{'Backup-complete'},
				expire	=> $$summary{Expire},
				status	=> $$summary{Status},
				path	=> $path,
			}
		);
	}
}

## WARNING:  don't mess with the sort order, it is needed so that if
## WARNING:  all images are expired the newest will be retained.
sub imsort
{
	$$a{vault} cmp $$b{vault}
	|| $$a{branch} cmp $$b{branch}
	|| $$a{created} cmp $$b{created};
}

