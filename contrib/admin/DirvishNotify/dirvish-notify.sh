#!/bin/sh
# dirvish-notify.sh by RTCG  June 15, 2005

DATE=`date +%Y-%m-%d`
FILE=/tmp/backup-$DATE.txt
TO='netadmin@example.com'

echo "----Disk space in use by the dirvish banks----" >> $FILE
echo "                      Total Used  Free %Full  Bank-name" >> $FILE

df -h | grep banks >> $FILE

echo ----------------------------------------------- >> $FILE
echo "" >> $FILE
echo "" >> $FILE

for location in /banks/bugsbunny /banks/daffyduck /banks/duckoffline \
  /banks/bunnyoffline ; do
  for x in $location/* ; do
    echo '-------------'$x'-------------' >> $FILE
    egrep -i '^(Bank|Vault|Status|Backup-complete):' \
      $x/$DATE/summary >> $FILE 2>&1
  done
done

smtp=smtp mail -s "Dirvish backup report $DATE" $TO < $FILE
rm $FILE

