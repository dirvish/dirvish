#/bin/sh
# dirvish-prune.sh by RTCG June 16, 2005

if [ -z "$2" ]
then
 echo
 echo
 echo Correct usage is:
 echo
 echo "        dirvish-prune path_to_vault file_or_directory_to_delete"
 echo
 echo " Example:  dirvish-prune /banks/server1-home /user/keithl/extra"
 echo
 exit 65
fi

TARGET=$2
if [ `echo $1 | rev | cut -c 1` = "/" ]
then
 VAULT=`echo $1 | rev | cut -c 2- | rev`
else
  VAULT=$1
fi

cd  $VAULT

if [ "$VAULT" != "$PWD" ]
then
 echo Aborting. Unable to verify that the current directory was set to $VAULT
 echo verify the path to ensure that it exists
 exit 66
fi

for INSTANCE in * ;do
 if [ -a $INSTANCE/tree/$TARGET ]
 then
  ls -ld $INSTANCE/tree/$TARGET
 fi 
done

echo These are the files that will be deleted.  
echo Press CTRL-C to abort or press enter to continue.
read
for INSTANCE in * ;do
 if [ -a $INSTANCE/tree/$TARGET ]
  then
  echo   rm -r $INSTANCE/tree/$TARGET
 fi    
done
