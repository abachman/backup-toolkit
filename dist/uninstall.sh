#!/usr/bin/env bash
#
# Uninstalls backup toolkit for $USER

function print_usage {
  printf "Usage: %s installdir\n" $(basename $0) >&2
}

INSTALL=$1

if [ -z "$INSTALL" ]; then
  echo "Must include install directory"
  print_usage
  exit 1
fi

if [ -e $INSTALL ]; then
  INSTALL=$(cd $INSTALL && pwd)
else
  echo "Invalid install directory: $INSTALL" >&2
  exit 1
fi

filelog=$INSTALL/backup-log/install-files.log
if [ ! -e $filelog ]; then
  echo "NO $filelog, nothing to uninstall."
  exit 1
fi

for filename in $(cat $filelog); do
  echo "removing $filename"
  rm -rf $filename
done

cronfile=.tmp-cronfile
# preserve existing cronjobs, remove backup-runner job.
crontab -u $USER -l | grep -v backup-runner.rb > $cronfile
# update cronjobs
crontab -u $USER $cronfile

rm -rf $INSTALL
