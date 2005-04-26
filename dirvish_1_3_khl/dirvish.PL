# dirvish.PL
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

my %CodeID =
    ( Rev    => '$Rev$'     ,
      Date   => '$Date$'    ,
      Author => '$Author$'  ,
      URL    => '$HeadURL$' ,
    );

$VERSION =   $CodeID{URL};
$VERSION =~  s#^.*dirvish_##;  # strip off the front
$VERSION =~  s#\/.*##;         # strip off the rear after the last /
$VERSION =~  s#[_-]#.#g;       # _ or - to "."

#########################################################
#
#   EXIT CODES
#
#   0        success
#   1-19     warnings
#   20-39    finalization error
#   40-49    post-* error
#   50-59    post-client error code % 10forwarded
#   60-69    post-server error code % 10forwarded
#   70-79    pre-* error
#   80-89    pre-server error code % 10 forwarded
#   90-99    pre-client error code % 10 forwarded
#   100-149  non-fatal error
#   150-199  fatal error
#   200-219  loadconfig error.
#   220-254  configuration error
#   255      usage error
#

use POSIX qw(strftime);
use Getopt::Long;
use Time::ParseDate;
use Time::Period;

### require "dirvishlib.pl";

@rsyncargs = qw(-vrltH --delete);

%RSYNC_CODES = (
      0 => [ 'success',	"No errors" ],
      1 => [ 'fatal',	"syntax or usage error" ],
      2 => [ 'fatal',	"protocol incompatibility" ],
      3 => [ 'fatal',	"errors selecting input/output files, dirs" ],
      4 => [ 'fatal',	"requested action not supported" ],
      5 => [ 'fatal',	"error starting client-server protocol" ],

     10 => [ 'error',	"error in socket IO" ],
     11 => [ 'error',	"error in file IO" ],
     12 => [ 'check',	"error in rsync protocol data stream" ],
     13 => [ 'check',	"errors with program diagnostics" ],
     14 => [ 'error',	"error in IPC code" ],

     20 => [ 'error',	"status returned when sent SIGUSR1, SIGINT" ],
     21 => [ 'error',	"some error returned by waitpid()" ],
     22 => [ 'error',	"error allocating core memory buffers" ],
     23 => [ 'error',	"partial transfer" ],

     # 24 changed from error to warning.  This keeps dirvish from failing
     # if the client deletes a file between list creation and the file
     # movement  KHL  (from note on 2004-08-07 )

     24 => [ 'warning',	"file vanished on sender" ],

     30 => [ 'error',	"timeout in data send/receive" ],

    124 => [ 'fatal',	"remote shell failed" ],
    125 => [ 'error',	"remote shell killed" ],
    126 => [ 'fatal',	"command could not be run" ],
    127 => [ 'fatal',	"command not found" ],
);

@BOOLEAN_FIELDS = qw(
    permissions
    checksum
    devices
    init
    numeric-ids
    sparse
    stats
    whole-file
    xdev
    zxfer
);

%RSYNC_OPT = (      	# simple options
    permissions   	=> '-pgo',
    devices		=> '-D',
    sparse		=> '-S',
    checksum     	=> '-c',
    'whole-file'	=> '-W',
    xdev		=> '-x',
    zxfer		=> '-z',
    stats		=> '--stats',
    'numeric-ids'	=> '--numeric-ids',
);

%RSYNC_POPT = (		# parametered options
    'password-file'	=> '--password-file',
    'rsync-client'	=> '--rsync-path',
);

#----------------------------------------------
#
#

sub usage
{
    my $message = shift(@_);

    length($message) and print STDERR $message, "\n\n";
    $! and exit(255); # because getopt seems to send us here for death

    print STDERR <<EOUSAGE;
USAGE
	dirvish --vault vault OPTIONS [ file_list ]
	
OPTIONS
	--image image_name
	--config configfile
	--branch branch_name
	--reference branch_name|image_name
	--expire expire_date
	--init
	--reset option
	--summary short|long
	--no-run
EOUSAGE

	exit 255;
}

#------------------------------------------------------------------------

reset_options();            # initialize the %$Options hash

$$Options{'config'} = \&config;  # dirvish is different than other apps

load_master_config('f');    # 'f' = ignore capitalized options, but why?

# The capitalized options are "Runall" and "Dirvish" - if these options
# aren't used by this program, why bother to suppress them?

#---------------------------------------------------------------
# Read the command line.  This puts data into the %$Options hash,
# defined in dirvish.pm .  Some of the Options hash entries call
# subroutines, and the result of some of the subroutines is to
# change the subroutine reference to the resulting scalar.
# 
# These options call subroutines:
#    config          load a configuration file
#    client          load a client machine configuration file 
#    reset={option}  set {option} to empty array, or undef scalar
#                    if reset=default, initialize the %$Options hash
#    version         Print version and exit
#    help            Print usage and exit
#
# These options call subroutines, load config files, then replace the
# routine with a scalar:
#    branch          replace branch, and maybe vault too if ":"
#    vault           replace vault, and maybe branch too if ":"

GetOptions($Options, qw(
    config=s
    vault=s
    client=s
    tree=s
    image=s
    image-time=s
    expire=s
    branch=s
    reference=s
    exclude=s@
    sparse!
    zxfer!
    checksum!
    whole-file!
    xdev!
    speed-limit=s
    file-exclude|fexclude=s
    reset=s
    index=s
    init!
    summary=s
    no-run|dry-run
    help|?
    version
    )) or usage;

chomp($$Options{Server} = `hostname`);

if ($$Options{image})
{
    $image = $$Options{Image} = $$Options{image};
}
elsif ($$Options{'image-temp'})
{
    $image = $$Options{'image-temp'};
    $$Options{Image} = $$Options{'image-default'};
}
else
{
    $image = $$Options{Image} = $$Options{'image-default'};
}

$$Options{branch} =~ /:/
    and ($$Options{vault}, $$Options{branch})
        = split(/:/, $Options{branch});

$$Options{vault} =~ /:/
    and ($$Options{vault}, $$Options{branch})
        = split(/:/, $Options{vault});

for $key (qw(vault Image client tree))
{
    length($$Options{$key}) or usage("$key undefined");
    ref($$Options{$key}) eq 'CODE'
        and usage("$key undefined");
}

if(!$$Options{Bank})
{
    my $bank;
    for $bank (@{$$Options{bank}})
    {
        if (-d "$bank/$$Options{vault}")
        {
            $$Options{Bank} = $bank;
            last;
        }
    }
    $$Options{Bank} or seppuku 220, "ERROR: cannot find vault $$Options{vault}";
}

$vault = join('/', $$Options{Bank}, $$Options{vault});
-d $vault or seppuku 221, "ERROR: cannot find vault $$Options{vault}";

my $now = time;

if ($$Options{'image-time'})
{
    my $n = $now;

    $now = parsedate($$Options{'image-time'},
        DATE_REQUIRED => 1, NOW => $n);
    if (!$now)
    {
        $now = parsedate($$Options{'image-time'}, NOW => $n);
        $now > $n && $$Options{'image-time'} !~ /\+/ and $now -= 24*60*60;
    }
    $now or seppuku 222, "ERROR: image-time unparseable: $$Options{'image-time'}";
}
$$Options{'Image-now'} = strftime('%Y-%m-%d %H:%M:%S', localtime($now));

$$Options{Image} =~ /%/
    and $$Options{Image} = strftime($$Options{Image}, localtime($now));
$image =~ /%/
    and $image = strftime($image, localtime($now));

!$$Options{branch} || ref($$Options{branch})
    and $$Options{branch} = $$Options{'branch-default'} || 'default';

$seppuku_prefix = join(':', $$Options{vault}, $$Options{branch}, $image);

if (-d "$vault/$$Options{'image-temp'}" && $image eq $$Options{'image-temp'})
{
    my $iinfo;
    $iinfo = loadconfig('R', "$vault/$image/summary");
    $$iinfo{Image} or seppuku 223, "cannot cope with existing $image";

    if ($$Options{'no-run'})
    {
        print "ACTION: rename $vault/$image $vault/$$iinfo{Image}\n\n";
        $have_temp = 1;
    } else {
        rename ("$vault/$image", "$vault/$$iinfo{Image}");
    }
}

-d "$vault/$$Options{Image}"
    and seppuku 224, "ERROR: image $$Options{Image} already exists in $vault";
-d "$vault/$image" && !$have_temp
    and seppuku 225, "ERROR: image $image already exists in $vault";

$$Options{Reference} = $$Options{reference} || $$Options{branch};
if (!$$Options{init} && -f "$vault/dirvish/$$Options{Reference}.hist")
{
    my (@images, $i, $s);
    open(IMAGES, "$vault/dirvish/$$Options{Reference}.hist");
    @images = <IMAGES>;
    close IMAGES;
    while ($i = pop(@images))
    {
        $i =~ s/\s.*$//s;
        -d "$vault/$i/tree" or next;

        $$Options{Reference} = $i;
        last;
    }
}
$$Options{init} || -d "$vault/$$Options{Reference}"
    or seppuku 227, "ERROR: no images for branch $$Options{branch} found";

if(!$$Options{expire} && $$Options{expire} !~ /never/i
    && scalar(@{$$Options{'expire-rule'}}))
{
    my ($rule, $p, $t, $e);
    my @cron;
    my @pnames = qw(min hr md mo wd);

    for $rule (reverse(@{$$Options{'expire-rule'}}))
    {
        if ($rule =~ /\{.*\}/)
        {
            ($p, $e) = $rule =~ m/^(.*\175)\s*([^\175]*)$/;
        } else {
            @cron = split(/\s+/, $rule, 6);
            $e = $cron[5] || '';
            $p = '';
            for ($t = 0; $t < @pnames; $t++)
            {
                $cron[$t] eq '*' and next;
                ($p .= "$pnames[$t] { $cron[$t] } ")
                =~ tr/,/ /;
            }
        }
        if (!$p)
        {
            $$Options{'Expire-rule'} = $rule;
            $$Options{Expire} = $e;
            last;
        }
        $t = inPeriod($now, $p);
        if ($t == 1)
        {
            $e ||= 'Never';
            $$Options{'Expire-rule'} = $rule;
            $$Options{Expire} = $e;
            last;
        }
        $t == -1 and printf STDERR "WARNING: invalid expire rule %s\n", $rule;
        next;
    }
} else {
    $$Options{Expire} = $$Options{expire};
}

$$Options{Expire} ||= $$Options{'expire-default'};

if ($$Options{Expire} && $$Options{Expire} !~ /Never/i)
{
    $$Options{Expire} .= strftime(' == %Y-%m-%d %H:%M:%S',
        localtime(parsedate($$Options{Expire}, NOW => $now)));
} else {
    $$Options{Expire} = 'Never';
}

# logic updated on 2004-09-04 by EricM to handle spaces in directories on
# windows boxen. 
($srctree, $aliastree) = split(/[^\\]\s+/, $$Options{tree})   # esm 2004-09-04
    or seppuku 228, "ERROR: no source tree defined";
$srctree =~ s(\\ )( )g;                                       # esm 2004-09-04
$srctree =~ s(/+$)();
$aliastree =~ s(/+$)();
$aliastree ||= $srctree;

$destree  = join("/", $vault, $image, 'tree');
$reftree  = join('/', $vault, $$Options{Reference}, 'tree');
$err_temp = join("/", $vault, $image, 'rsync_error.tmp');
$err_file = join("/", $vault, $image, 'rsync_error');
$log_file = join("/", $vault, $image, 'log');
$log_temp = join("/", $vault, $image, 'log.tmp');
$exl_file = join("/", $vault, $image, 'exclude');
$fsb_file = join("/", $vault, $image, 'fsbuffer');

while (($k, $v) = each %RSYNC_OPT)
{
    $$Options{$k} and push @rsyncargs, $v;
}

while (($k, $v) = each %RSYNC_POPT)
{
    $$Options{$k} and push @rsyncargs, $v . '=' . $$Options{$k};
}

$$Options{'speed-limit'}
    and push @rsyncargs, '--bwlimit=' . $$Options{'speed-limit'} * 100;

scalar @{$$Options{'rsync-option'}}
    and push @rsyncargs, @{$$Options{'rsync-option'}};

scalar @{$$Options{exclude}}
    and push @rsyncargs, '--exclude-from=' . $exl_file;

if (!$$Options{'no-run'})
{
    mkdir "$vault/$image", 0700
        or seppuku 230, "mkdir $vault/$image failed";
    mkdir $destree, 0755;

    open(SUMMARY, ">$vault/$image/summary")
        or seppuku 231, "cannot create $vault/$image/summary"; 
} else {
    open(SUMMARY, ">-");
}

$Set = $Unset = '';
for (@BOOLEAN_FIELDS)
{
    $$Options{$_}
        and $Set .= $_ . ' '
        or $Unset .= $_ . ' ';
}

@summary_fields = qw(
    client tree rsh
    Server Bank vault branch
           Image image-temp Reference
    Image-now Expire Expire-rule
    exclude
    rsync-option
    Enabled
);
$summary_reset = 0;
for $key (@summary_fields, 'RESET', sort(keys(%$Options)))
{
    if ($key eq 'RESET')
           {
        $summary_reset++;
        $Set and print SUMMARY "SET $Set\n";
        $Unset and print SUMMARY "UNSET $Unset\n";
        print SUMMARY "\n";
        $$Options{summary} ne 'long' && !$$Options{'no-run'} and last;
        next;
    }
    grep(/^$key$/, @BOOLEAN_FIELDS) and next;
    $summary_reset && grep(/^$key$/, @summary_fields) and next;

    $val = $$Options{$key};
    if(ref($val) eq 'ARRAY')
    {
        my $v;
        scalar(@$val) or next;
        print SUMMARY "$key:\n";
        for $v (@$val)
        {
            printf SUMMARY "\t%s\n", $v;
        }
    }
    ref($val) and next;
    $val or next;
    printf SUMMARY "%s: %s\n", $key, $val;
}

$$Options{init} or push @rsyncargs, "--link-dest=$reftree";

$rclient = undef;
$$Options{client} ne $$Options{Server}
    and $rclient = $$Options{client} . ':';

$ENV{RSYNC_RSH} = $$Options{rsh};


# Define the rsync command.  This is an array, consisting of:
# 1) The command to use for rsync itself (typically 'rsync', but optionally
#    the path and  program name set by the "rsync" option in a config file.  
# 2) all the rsync arguments incl. the --exclude-from=$exl_file and the 
#    --link-dest=$reftree if not init
# 3) the source: if client=server this is  source_tree/,
#    otherwise it is client:source_tree/ 
# 4) the destination: bank/vault/image/tree
#

@cmd = (
    ($$Options{rsync} ? $$Options{rsync} : 'rsync'),
    @rsyncargs,
    $rclient . $srctree . '/',
    $destree
    );

# summary example:
# ACTION: rsync -vrltDH -pgo --numeric-ids --stats -x \
# --exclude-from=/backup/dirvish/gate/var/2004-0327-0300/exclude \
# --link-dest=/backup/dirvish/gate/var/2004-0326-0300/tree gate:/var/ \
#  /backup/dirvish/gate/var/2004-0327-0300/tree

printf SUMMARY "\n%s: %s\n", 'ACTION', join (' ', @cmd);

$$Options{'no-run'} and exit 0;

printf SUMMARY "%s: %s\n", 'Backup-begin',
    strftime('%Y-%m-%d %H:%M:%S', localtime);

# logic updated on 2004-09-04 by EricM to handle spaces in directories on
# windows boxen. 
$env_srctree = $srctree;                                      # esm 2004-09-04
$env_srctree =~ s/ /\\ /g;                                    # esm 2004-09-04

$WRAPPER_ENV = sprintf (" %s=%s" x 5,
    'DIRVISH_SERVER', $$Options{Server},
    'DIRVISH_CLIENT', $$Options{client},
    'DIRVISH_SRC', $env_srctree,                              # esm 2004-09-04
    'DIRVISH_DEST', $destree,
    'DIRVISH_IMAGE', join(':',
        $$Options{vault},
        $$Options{branch},
        $$Options{Image}),
);

if(scalar @{$$Options{exclude}})
{
    open(EXCLUDE, ">$exl_file");
    for (@{$$Options{exclude}})
    {
        print EXCLUDE $_, "\n";
    }    
    close(EXCLUDE);
    $ENV{DIRVISH_EXCLUDE} = $exl_file;
}

if ($$Options{'pre-server'})
{
    $status{'pre-server'} = scriptrun(
        label    => 'Pre-Server',
        cmd    => $$Options{'pre-server'},
        now    => $now,
        log    => $log_file,
        dir    => $destree,
        env    => $WRAPPER_ENV,
    );

    if ($status{'pre-server'})
    {
        my $s = $status{'pre-server'} >> 8;
        printf SUMMARY "pre-server failed (%d)\n", $s;
        printf STDERR "%s:%s pre-server failed (%d)\n",
            $$Options{vault}, $$Options{branch},
            $s;
        exit 80 + ($s % 10);
    }
}

if ($$Options{'pre-client'})
{
    $status{'pre-client'} = scriptrun(
        label    => 'Pre-Client',
        cmd    => $$Options{'pre-client'},
        now    => $now,
        log    => $log_file,
        dir    => $srctree,
        env    => $WRAPPER_ENV,
        shell    => (($$Options{client} eq $$Options{Server})
            ?  undef
            : "$$Options{rsh} $$Options{client}"),
    );
    if ($status{'pre-client'})
    {
        my $s = $status{'pre-client'};
        printf SUMMARY "pre-client failed (%d)\n", $s;
        printf STDERR "%s:%s pre-client failed (%d)\n",
            $$Options{vault}, $$Options{branch},
            $s;

        ($$Options{'pre-server'}) && scriptrun(
            label    => 'Post-Server',
            cmd    => $$Options{'post-server'},
            now    => $now,
            log    => $log_file,
            dir    => $destree,
            env    => $WRAPPER_ENV . ' DIRVISH_STATUS=fail',
        );
        exit 90 + ($s % 10);
    }
}

# create a buffer to allow logging to work after full fileystem
open (FSBUF, ">$fsb_file");
print FSBUF "         \n" x 6553;
close FSBUF;

for ($runloops = 0; $runloops < 5; ++$runloops)
{
    logappend($log_file, sprintf("\n%s: %s\n", 'ACTION', join(' ', @cmd)));


    # create error file and connect rsync STDERR to it.
    # preallocate 64KB so there will be space if rsync
    # fills the filesystem.

    open (INHOLD, "<&STDIN");
    open (ERRHOLD, ">&STDERR");
    open (STDERR, ">$err_temp");
    print STDERR "         \n" x 6553;
    seek STDERR, 0, 0;

    open (OUTHOLD, ">&STDOUT");
    open (STDOUT, ">$log_temp");

    $status{code} = (system(@cmd) >> 8) & 255;

    open (STDERR, ">&ERRHOLD");
    open (STDOUT, ">&OUTHOLD");
    open (STDIN, "<&INHOLD");

    open (LOG_FILE, ">>$log_file");
    open (LOG_TEMP, "<$log_temp");
    while (<LOG_TEMP>)
    {
        chomp;
        m(/$) and next;
        m( [-=]> ) and next;
        print LOG_FILE $_, "\n";
    }
    close (LOG_TEMP);
    close (LOG_FILE);
    unlink $log_temp;

    $status{code} and errorscan(\%status, $err_file, $err_temp);

    $status{warning} || $status{error}
               and logappend($log_file, sprintf(
            "RESULTS: warnings = %d, errors = %d",
            $status{warning}, $status{error}
            )
        );

    # end loop if fatal or no error, otherwise loop again
    if ($RSYNC_CODES{$status{code}}[0] eq 'check')
    {
        $status{fatal} and last;
        $status{error} or  last;
    } else {
        $RSYNC_CODES{$status{code}}[0] eq 'fatal' and last;
        $RSYNC_CODES{$status{code}}[0] eq 'error' or  last;
    }
}

scalar @{$$Options{exclude}} && unlink $exl_file;
-f $fsb_file and unlink $fsb_file;

if ($status{code})
{
    if ($RSYNC_CODES{$status{code}}[0] eq 'check')
    {
        if ($status{fatal})        { $Status = 'fatal'; }
        elsif ($status{error})     { $Status = 'error'; }
        elsif ($status{warning})   { $Status = 'warning'; }
        $Status_msg = sprintf "%s (%d) -- %s",
            ($Status eq 'fatal' ? 'fatal error' : $Status),
            $status{code},
            $status{message}{$Status};
    } elsif ($RSYNC_CODES{$status{code}}[0] eq 'fatal')
    {
        $Status_msg = sprintf "fatal error (%d) -- %s",
            $status{code},
            $RSYNC_CODES{$status{code}}[1];
    }

    if (!$Status_msg)
    {
        $RSYNC_CODES{$status{code}}[0] eq 'fatal' and $Status = 'fatal';
        $RSYNC_CODES{$status{code}}[0] eq 'error' and $Status = 'error';
        $RSYNC_CODES{$status{code}}[0] eq 'warning' and    $Status = 'warning';
        $RSYNC_CODES{$status{code}}[0] eq 'check' and $Status = 'unknown';
        exists $RSYNC_CODES{$status{code}} or $Status = 'unknown';
        $Status_msg = sprintf "%s (%d) -- %s",
            ($Status eq 'fatal' ? 'fatal error' : $Status),
            $status{code},
            $RSYNC_CODES{$status{code}}[1];
    }
    if ($Status eq 'fatal' || $Status eq 'error' || $status eq 'unknown')
    {
        printf STDERR "dirvish %s:%s %s\n",
            $$Options{vault}, $$Options{branch},
            $Status_msg;
    }
} else {
    $Status = $Status_msg = 'success';
}

$WRAPPER_ENV .= ' DIRVISH_STATUS=' .  $Status;

if ($$Options{'post-client'})
{
    $status{'post-client'} = scriptrun(
        label    => 'Post-Client',
        cmd    => $$Options{'post-client'},
        now    => $now,
        log    => $log_file,
        dir    => $srctree,
        env    => $WRAPPER_ENV,
        shell    => (($$Options{client} eq $$Options{Server})
            ?  undef
            : "$$Options{rsh} $$Options{client}"),
    );
    if ($status{'post-client'})
    {
        my $s = $status{'post-client'} >> 8;
        printf SUMMARY "post-client failed (%d)\n", $s;
        printf STDERR "%s:%s post-client failed (%d)\n",
            $$Options{vault}, $$Options{branch},
            $s;
    }
}

if ($$Options{'post-server'})
{
    $status{'post-server'} = scriptrun(
        label    => 'Post-Server',
        cmd    => $$Options{'post-server'},
        now    => $now,
        log    => $log_file,
        dir    => $destree,
        env    => $WRAPPER_ENV,
    );
    if ($status{'post-server'})
    {
        my $s = $status{'post-server'} >> 8;
        printf SUMMARY "post-server failed (%d)\n", $s;
        printf STDERR "%s:%s post-server failed (%d)\n",
            $$Options{vault}, $$Options{branch},
            $s;
    }
}

if($status{fatal})
{
    system ("rm -rf $destree");
    unlink $err_temp;
    printf SUMMARY "%s: %s\n", 'Status', $Status_msg;
    exit 199;
} else {
    unlink $err_temp;
    -z $err_file and unlink $err_file;
}

printf SUMMARY "%s: %s\n",
    'Backup-complete', strftime('%Y-%m-%d %H:%M:%S', localtime);

printf SUMMARY "%s: %s\n", 'Status', $Status_msg;

# We assume warning and unknown produce useful results
$Status eq 'warning' || $Status eq 'unknown' and $Status = 'success';

if ($Status eq 'success')
{
    -s "$vault/dirvish/$$Options{branch}.hist" or $newhist = 1;
    if (open(HIST, ">>$vault/dirvish/$$Options{branch}.hist"))
    {
        $newhist == 1 and printf HIST ("#%s\t%s\t%s\t%s\n",
                qw(IMAGE CREATED REFERECE EXPIRES));
        printf HIST ("%s\t%s\t%s\t%s\n",
                $$Options{Image},
                strftime('%Y-%m-%d %H:%M:%S', localtime),
                $$Options{Reference} || '-',
                $$Options{Expire}
            );
        close (HIST);
    }
} else {
    printf STDERR "dirvish error: branch %s:%s image %s failed\n",
        $vault, $$Options{branch}, $$Options{Image};
}

length($$Options{'meta-perm'})
    and chmod oct($$Options{'meta-perm'}),
        "$vault/$image/summary",
        "$vault/$image/rsync_error",
        "$vault/$image/log";

$Status eq 'success' or exit 149;

$$Options{log} =~ /.*(gzip)|(bzip2)/
    and system "$$Options{log} $vault/$image/log";

if ($$Options{index} && $$Options{index} !~/^no/i)
{
    
    open(INDEX, ">$vault/$image/index");
    open(FIND, "find $destree -ls|")
        or seppuku 21, "dirvish $vault:$image cannot build index";

    while (<FIND>)
    {
        s/ $destree\// $aliastree\//g;
        print INDEX $_
           or seppuku 22, "dirvish $vault:$image error writing index";
    }
    close FIND;
    close INDEX;

    length($$Options{'meta-perm'})
        and chmod oct($$Options{'meta-perm'}), "$vault/$image/index";
    $$Options{index} =~ /.*(gzip)|(bzip2)/
        and system "$$Options{index} $vault/$image/index";
}

chmod oct($$Options{'image-perm'}) || 0755, "$vault/$image";

exit 0;
