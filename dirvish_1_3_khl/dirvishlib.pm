# dirvishlib.pl
# 1.3.X series
# Copyright 2005 by the dirvish project
# http://www.dirvish.org
#
# Last Revision   : $Rev: 29 $
# Revision date   : $Date: 2005-04-12 10:16:45 -0700 (Tue, 12 Apr 2005) $
# Last Changed by : $Author: keithl $
# Stored as       : $HeadURL: http://www.dirvish.org/svn/dirvish_1_3_khl/dirvishlib.pl $

$VERSION = "1.3khl";

#########################################################################
#                                                         		#
#	Licensed under the Open Software License version 2.0		#
#                                                         		#
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
    Rev    => '$Rev: 29 $'     ,
    Date   => '$Date: 2005-04-12 10:16:45 -0700 (Tue, 12 Apr 2005) $'    ,
    Author => '$Author: keithl $'  ,
    URL    => '$HeadURL: http://www.dirvish.org/svn/dirvish_1_3_khl/dirvishlib.pl $' ,
);

#----------------------------------------------------------------------------
#
#  similar to dirvish-locate.pl              refactored from dirvish-expire.pl

## WARNING:  don't mess with the sort order, it is needed so that if
## WARNING:  all images are expired the newest will be retained.

sub imsort
{
    $$a{vault} cmp $$b{vault}        # this line was NOT in dirvish-locate
    || $$a{branch} cmp $$b{branch}
    || $$b{created} cmp $$a{created};
}


#----------------------------------------------------------------------------
#
#
#                                           refactored from dirvish-expire.pl

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
        print STDERR
            "$File::Find::dir: invalid expiration time $$summary{expire}\n";
        return -1;
    }
    $etime > $expire_time and return 0;

    return 1;
}


#----------------------------------------------------------------------------
# findop -- is used by dirvish-expire to look for summary files in a bank.
#
#  findop is called with File::Find::find ( \&findop, $VAULT | $BANK )
#  
#  findop should be looking for files of the form:
#  ... /$BANK/$VAULT/$IMAGE/summary, then process those files.
#
#  findop will not look inside "tree" files, but it WILL look anywhere
#  else.  So a file ... /bank/nonvault/dir1/dir2/dir3/summary will be
#  considered a dirvish summary file, then get processed incorrectly.
#  Therefore, put ONLY vaults in banks.
#
#  For now, findop is used only by dirvish-expire, but in the future it will
#  also be used in testing routines, so it stays in the subroutine library.
#                                          refactored from dirvish-expire.pl

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
                vault   => $$summary{'vault'},
                branch  => $$summary{'branch'},
                client  => $$summary{'client'},
                tree    => $$summary{'tree'},
                image   => $$summary{'Image'},
                created => $$summary{'Backup-complete'},
                expire  => $$summary{'Expire'},
                status  => $$summary{'Status'},
                path    => $path,
            }
        ); #push
    } 
} 


#----------------------------------------------------------------------------
# seppuku -- Exit with code and message.
#                                               refactored from loadconfig.pl

sub seppuku
{
    my ($status, $message) = @_;

    chomp $message;
    if ($message)
    {
        $seppuku_prefix and print STDERR $seppuku_prefix, ': ';
        print STDERR $message, "\n";
    }
    exit $status;
}

#----------------------------------------------------------------------------
# config --
#
#                                               refactored from loadconfig.pl

sub config 
{
    loadconfig('f', $_[1], $Options);
}

#----------------------------------------------------------------------------
# client --
#

sub client
{
    $$Options{client} = $_[1];
    loadconfig('fog', "$CONFDIR/$_[1]", $Options);
}

#----------------------------------------------------------------------------
# branch --
#

sub branch
{
    if ($_[1] =~ /:/)
    {
        ($$Options{vault}, $$Options{branch}) = split(/:/, $_[1]);
    } else {
        $$Options{branch} = $_[1];
    }
    loadconfig('f', "$$Options{branch}", $Options);
}

#----------------------------------------------------------------------------
# vault --
#

sub vault
{
    if ($_[1] =~ /:/)
    {
        ($$Options{vault}, $$Options{branch})
            = split(/:/, $_[1]);
        loadconfig('f', "$$Options{branch}", $Options);
    } else {
        $$Options{vault} = $_[1];
        loadconfig('f', 'default.conf', $Options);
    }
}

#----------------------------------------------------------------------------
# reset_options --
#

sub reset_options 
{
    # retain original command arguments
    $CommandArgs or $CommandArgs=join(' ', @ARGV);

    $Options = {
 	'Command-Args'	=> $CommandArgs,
        'numeric-ids'	=> 1,
        'devices'	=> 1,
        'permissions'	=> 1,
        'stats'		=> 1,
        'checksum'	=> 0,
        'init'		=> 0,
        'sparse'	=> 0,
        'whole-file'	=> 0,
        'xdev'		=> 0,
        'zxfer'		=> 0,
        'no-run'        => 0,
        'exclude'	=> [ ],
        'expire-rule'	=> [ ],
        'rsync-option'	=> [ ],
        'bank'		=> [ ],
        'image-default'	=> '%Y%m%d%H%M%S',
        'rsh'		=> 'ssh'     ,
	'summary'	=> 'short'   ,
	'config'	=> undef     ,
        'client'	=> \&client  ,
        'branch'	=> \&branch  ,
        'vault'		=> \&vault   ,
        'reset'		=> \&reset   ,
        'version'	=> \&version ,
        'help'		=> \&usage   ,
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
} 

#----------------------------------------------------------------------------
# reset --
#

sub reset
{
    if ( $_[1] eq 'default' )
    {
        reset_options();
        print "$_[1] ,  reset_defaults\n";
    } else
    {
        $$Options{$_[1]} = ref($$Options{$_[1]}) eq 'ARRAY'
            ? [ ]
            : undef;
    }
} 

#----------------------------------------------------------------------------
# version --
#
#

sub version
{
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

sub errorscan
{
    my ($status, $err_file, $err_temp) = @_;

    my $err_this_loop = 0;
    my $action   ;
    my $pattern  ;
    my $severity ;
    my $message  ;

    #  determine severity for various actions, and generate a replacement
    #  error message if the rsync message (second entry) is unclear
    my @erraction = (
        [ 'fatal',   '^ssh:.*nection refused',                     ],
        [ 'fatal',   '^\S*sh: .* No such file',                    ],
        [ 'fatal',   '^ssh:.*No route to host',                    ],

        # KHL 2005 Mar 27  'file has vanished' changed from fatal to warning 
        [ 'warning', '^file has vanished: ',                       ],

        [ 'warning', 'readlink .*: no such file or directory',     ],
        [ 'fatal',   'failed to write \d+ bytes:',
                         'write error, filesystem probably full'   ],
        [ 'fatal',   'write failed',
                         'write error, filesystem probably full'   ],
        [ 'error',   'error: partial transfer',
                         'partial transfer'                        ],
        [ 'error',   'error writing .* exiting: Broken pipe',
                         'broken pipe'                             ],
    );

    open (ERR_FILE, ">>$err_file");
    open (ERR_TEMP, "<$err_temp");
    while (<ERR_TEMP>)
    {
        chomp;
        s/\s+$//;
        length or next;
        if (!$err_this_loop)
        {
            printf ERR_FILE "\n\n*** Execution cycle %d ***\n\n", $runloops;
            $err_this_loop++
        }
        print ERR_FILE $_, "\n";

        $$status{code} or next;
      
        for $action (@erraction)
        {
            ($severity, $pattern, $message) = @$action;
            /$pattern/ or next;

            # this is where we set status hash keys  fatal, error, warning  if
            # we locate one of the errors described in the @erraction table

            ++$$status{$severity};

            $msg = $message || $_;
            $$status{message}{$severity} ||= $msg;
            logappend($log_file, $msg);
            $severity eq 'fatal'
                and printf STDERR "dirvish %s:%s fatal error: %s\n",
                           $$Options{vault}, $$Options{branch}, $msg;
                last;
        }
        if (/No space left on device/)
        {
            $msg = 'filesystem full';
            $$status{message}{fatal} eq $msg and next;

            -f $fsb_file and unlink $fsb_file;
            ++$$status{fatal};
            $$status{message}{fatal} = $msg;
            logappend($log_file, $msg);
            printf STDERR "dirvish %s:%s fatal error: %s\n",
                   $$Options{vault}, $$Options{branch}, $msg;
        }
        if (/error: error in rsync protocol data stream/)
        {
            ++$$status{error};
            $msg = $message || $_;
            $$status{message}{error} ||= $msg;
            logappend($log_file, $msg);
        }
    }
    close ERR_TEMP;
    close ERR_FILE;
}

#----------------------------------------------------------------------------
# logappend --
#
#                                                refactored from loadconfig.pl

sub logappend
{
    my ($file, @messages) = @_;
    my $message;

    open (LOGFILE, '>>' . $file)
       or seppuku 20, "cannot open log file $file";

    for $message (@messages)
    {
        print LOGFILE $message, "\n";
    }
    close LOGFILE;
}

#----------------------------------------------------------------------------
# scriptrun --
#
#                                               refactored from dirvish.pl.pl

sub scriptrun
{
    my (%A) = @_;
    my ($cmd, $rcmd, $return);

    $A{now} ||= time;
    $A{log}      or  seppuku 229, "must specify logfile for scriptrun()";
    ref($A{cmd}) and seppuku 232, "$A{label} option specification error";

    $cmd = strftime($A{cmd}, localtime($A{now}));
    if ($A{dir} != /^:/)          # Eric M's BadShellCmd fix of 2004-09-04
    {
        $rcmd = sprintf ("%s 'cd %s; %s %s' >>%s",
             ("$A{shell}" || "/bin/sh -c"),
             $A{dir},
             $A{env},
             $cmd,
             $A{log}
        );
    } else {
        $rcmd = sprintf ("%s '%s %s' >>%s",
            ("$A{shell}" || "/bin/sh -c"),
            $A{env},
            $cmd,
            $A{log}
        );
    }

    $A{label} =~ /^Post/   and logappend($A{log}, "\n");

    logappend($A{log}, "$A{label}: $cmd");

    $return = system($rcmd);

    $A{label} =~ /^Pre/    and logappend($A{log}, "\n");

    return $return;
}

#----------------------------------------------------------------------------
# slurplist --
#
#                                               refactored from loadconfig.pl

sub slurplist
{
    my ($key, $filename, $Options) = @_;
    my $f;
    my $array;

    $filename =~ m(^/) and $f = $filename;
    if (!$f && ref($$Options{vault}) ne 'CODE')
    {
        $f = join('/', $$Options{Bank}, $$Options{vault},
                       'dirvish', $filename);
        -f $f or $f = undef;
    }
    $f or $f = "$CONFDIR/$filename";
    open(PATFILE, "<$f")
        or seppuku 229, "cannot open $filename for $key list";
    $array = $$Options{$key};
    while(<PATFILE>)
    {
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
#	
#   
#   LIMITATIONS
#   	Only way to tell whether an option should be a list
#   	or scalar is by the formatting in the config file.
#   
#   	Options reqiring special handling have to have that
#   	hardcoded in the function.
#
#                                               refactored from loadconfig.pl

sub loadconfig
{
    my ($mode, $configfile, $Options) = @_;
    my $confile = undef;
    my ($key, $val);
    my $CONFIG;
    ref($Options) or $Options = {};
    my %modes ;
    my $conf  ;
    my $bank  ;
    my $k     ;

    $modes{r} = 1;
    for $_ (split(//, $mode))
    {
        if (/[A-Z]/)
        {
            $_ =~ tr/A-Z/a-z/;
            $modes{$_} = 0;
        } else {
            $modes{$_} = 1;
        }
    }

    $CONFIG = 'CFILE' . scalar(@{$$Options{Configfiles}});
    $configfile =~ s/^.*\@//;

    if($configfile =~ m[/])
    {
        $confile = $configfile;
    }
    elsif($configfile ne '-')
    {
        if(!$modes{g} && $$Options{vault} && $$Options{vault} ne 'CODE')
        {
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
            }
            if ($$Options{Bank})
            {
                $confile = join('/', $$Options{Bank},
                    $$Options{vault}, 'dirvish',
                    $configfile);
                -f $confile || -f "$confile.conf"
                    or $confile = undef;
            }
        }
        $confile ||= "$CONFDIR/$configfile";
    }

    if($configfile eq '-')
    {
        open($CONFIG, $configfile) or seppuku 221, "cannot open STDIN";
    } else {
        ! -f $confile && -f "$confile.conf" and $confile .= '.conf';

        if (! -f "$confile")
        {
            $modes{o} and return undef;
            seppuku 222, "cannot open config file: $configfile";
        }

        grep(/^$confile$/, @{$$Options{Configfiles}})
            and seppuku 224, "ERROR: config file looping on $confile";

        open($CONFIG, $confile)
            or seppuku 225, "cannot open config file: $configfile";
    }
    push(@{$$Options{Configfiles}}, $confile);

    while(<$CONFIG>)
    {
        chomp;
        s/\s*#.*$//;
        s/\s+$//;
        /\S/ or next;
      
        if(/^\s/ && $key)
        {
            s/^\s*//;
            push @{$$Options{$key}}, $_;
        }
        elsif(/^SET\s+/)
        {
            s/^SET\s+//;
            for $k (split(/\s+/))
            {
                $$Options{$k} = 1;
            }
        }
        elsif(/^UNSET\s+/)
        {
            s/^UNSET\s+//;
            for $k (split(/\s+/))
            {
                $$Options{$k} = undef;
            }
        }
        elsif(/^RESET\s+/)
        {
            ($key = $_) =~ s/^RESET\s+//;
            $$Options{$key} = [ ];
        }
        ## f == ignore capitalized options in "dirvish" --- but why?
        elsif(/^[A-Z]/ && $modes{f})  
        {
            $key = undef;
        }
        elsif(/^\S+:/)
        {
            ($key, $val) = split(/:\s*/, $_, 2);
            length($val) or next;
            $k = $key; $key = undef;
 
            if ($k eq 'config')
            {
                $modes{r} and loadconfig($mode . 'O', $val, $Options);
                next;
            }
            if ($k eq 'client')
            {
                if ($modes{r} && ref ($$Options{$k}) eq 'CODE')
                {
                    loadconfig($mode .  'og', "$CONFDIR/$val", $Options);
                }
                $$Options{$k} = $val;
                next;
            }
            if ($k eq 'file-exclude')
            {
                $modes{r} or next;

                slurplist('exclude', $val, $Options);
                next;
            }
            if (ref ($$Options{$k}) eq 'ARRAY')
            {
                push @{$$Options{$k}}, $_;
            } else {
                $$Options{$k} = $val;
            }
        }
    }
    close $CONFIG;
    return $Options;
}


#----------------------------------------------------------------------------
#
#
#                                               refactored from dirvish.pl
# similar to      dirvish-runall.pl
# similar to      dirvish-expire.pl
# similar to      dirvish-locate.pl

sub  load_master_config
{
    my ($modes) = @_;

    # load master configuration file

    if ($CONFDIR =~ /dirvish$/ && -f "$CONFDIR.conf")
    {
        return loadconfig( $modes, "$CONFDIR.conf", $Options);
    }
    elsif (-f "$CONFDIR/master.conf")
    {
        return loadconfig( $modes, "$CONFDIR/master.conf", $Options);
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
        seppuku 251, "ERROR: no master configuration file";
    }
}

#----------------------------------------------------------------------------
#  This code was suggested as part of the ChmodOnExpire patch by 
#  Eric Mountain on 2005-01-29

sub check_exitcode
{
    my ($action, $command, $exit) = @_;
    my $msg = "WARNING: $action. $command ";

    # Code based on the documentation for the system() call
    # in Programming Perl, 2nd ed.

    $exit &= 0xffff;

    if ($exit == 0) {
        return 1;
    } elsif ($exit == 0xff00) {
        $msg .= " failed: $!";
    } elsif ($exit > 0x80) {
        $exit >>= 8;
        $msg .= "exited with status $exit.";
    } else {
        $msg .= "failed with ";
        if ($exit & 0x80) {
            $exit &= ~0x80;
            $msg .= "coredump from ";
        }
        $msg .= "signal $exit.";
    }

    print STDERR "$msg\n";

    return 0;
}
#----------------------------------------------------------------------------
# end of dirvishlib.pl
1;
