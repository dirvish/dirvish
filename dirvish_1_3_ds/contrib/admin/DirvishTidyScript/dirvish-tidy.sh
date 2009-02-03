#!/bin/sh
# Syntax:
#   dirvish-tidy [-q]
#   dirvish-tidy -l
#
#  -q  Be quiet; Do not output information.
#  -l  Do not actually remove the images, only list them
#  -h
BANK=/backup
AGE=7  # Don't delete partials newer than this many days

# Make sure no dirvish job is running
x=`ps -ef | grep dirvish | wc -l`
if [ $x -gt 3 ] ; then
       echo "Error: Dirvish is running. Stop."
       exit 2
fi

while [ "z$1" != "z" ]; do
       if [ "$1" == '-l' ]; then
               LIST="Y"
       else
               LIST="N"
       fi

       if [ "$1" == '-q' ]; then
               QUIET="Y"
       else
               QUIET="N"
       fi
       if [ $1 == -h ]; then
               echo 'dirvish-tidy.sh: Prune partial backup images'
               echo 'USAGE: dirvish-tidy [-q -l -h]'
               echo '      -q: quite'
               echo '      -l: list images only, don''t prune'
               echo '      -h: help line'
               exit 0
       fi
       shift
done

cd $BANK || (echo "Warning: Cannot cd into $BANK"; exit 1)

for f in *; do
       if [ -d $f ]; then
       xx=`cd $f; find * -maxdepth 0 -type d -mtime +$AGE -not -name dirvish 2>/dev/null`
       for g in $xx; do
               # echo image: $f/$g
               if [ -f $f/dirvish/daily.hist ]; then
                       if [ `grep -c "^$g" $f/dirvish/daily.hist` -eq 0 ]; then
                               if [ "$LIST" = "Y" ]; then
                                       echo "$f/$g"
                               else
                                       if [ "$QUIET" = "N" ]; then
                                               echo "$f/$g is not logged in the history file"
                                       fi
                                       rm -rf $f/$g
                               fi
                       fi
               fi
       done
       fi
done
