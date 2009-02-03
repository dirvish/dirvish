#! /bin/sh
VAULT=/backups
MAILTO=root
CONFIG=/etc/dirvish/master.conf

YESTERDAY=`date -d "yesterday" +%Y%m%d`

cd $VAULT || (echo "$0: ERROR: Please set the VAULT variable"; exit 1)

tmpfile=/tmp/dirvish.status.$$

WARNINGS=""
for machine in `ls|grep -v lost+found`
do
  echo "================== $machine =================="

  cd $machine

  # Check for a summary or log file (at least one should be
  # present if a backup occurred
  if [ ! -f $YESTERDAY/log -o ! -f $YESTERDAY/summary ]
  then
    # If no backup last night, then warn.
    # Also, try to guess the last night a backup occurred.
    # (yes, it's crude.)
    echo "** WARNING: This machine not backed up!"
    last=`(ls -dt [0-9]* 2>/dev/null)|head -1`
    if [ "z$last" = "z" ]
    then
      last="NEVER"
    fi
    echo "             (last backup: $last)"
    WARNINGS="$WARNINGS $machine"
  else

    # Otherwise, we assume that if there is no Status: success, 
    # the backup wasn't successful. It could be that the backup is
    # still running, but is still worth a look.
    if [ `grep -c "Status: success" $YESTERDAY/summary` -eq "0" ]
    then
      echo "** WARNING: Backup not successful"
      echo
      # Keep a list of machines with warnings.
      WARNINGS="$WARNINGS $machine"
    fi

    # Copy the backup's summary file to the email, ignoring
    # any exclude: lines (to keep the email short, but useful.)
    (grep -v "^ "|grep -v "^exclude:"|grep -v "^$") < $YESTERDAY/summary
  fi
  echo

  cd ..

done > $tmpfile

# Include a [**] notation on the subject line if there were warnings. 
if [ "$WARNINGS" != "" ]
then
  WARNSUB="[**] "
else
  WARNSUB=""
fi

(
if [ "$WARNINGS" != "" ]
then
  echo
  echo "The following machines had warnings:"
  echo "    $WARNINGS"
fi
echo
echo "Disk usage:"
/bin/df -h
echo
cat $tmpfile
) | mail -s "${WARNSUB}Dirvish status (${YESTERDAY}@`hostname`)" $MAILTO

rm -f $tmpfile
