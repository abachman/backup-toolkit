#!/usr/bin/env bash
#
# Run from node.
#
# Installs:
#   mysql-dump.sh
#   tar-dump.sh
#   backup-runner.rb
#   backup-runner.cron
#
# Creates:
#   backup-staging/
#   backup-log/
#   backup-jobs/
#   backup-toolkit.conf
#
# Sets up crontab entry for backup-runner.rb

function print_usage {
  printf "Usage: %s [-h hour] [-m minute] /path/to/install/to\n" $(basename $0) >&2
}

while getopts 'h:m:d:' OPTION
do
  case $OPTION in
  h) hour=$OPTARG
    ;;
  m) minute=$OPTARG
    ;;
  *) 
    print_usage
    exit 2
    ;;
  esac
done
shift $(($OPTIND - 1))

if [ -z "$1" ]; then
  echo "Must include install directory"
  print_usage
  exit 1
fi

# make sure install dir is fully specified
mkdir -p $1
INSTALL=$(cd $1 && pwd)
echo "installing to $INSTALL as $USER"

install_files=$INSTALL/backup-log/install-files.log
mkdir -p $(dirname $install_files)
function add_file { 
  touch $1 
  echo $1 >> $install_files 
}
function add_dir {
  mkdir -p $1
  echo $1 >> $install_files
}

add_dir $INSTALL
add_dir $INSTALL/backup-staging
add_dir $INSTALL/backup-log
add_dir $INSTALL/backup-jobs

echo -n > $install_files

add_file $INSTALL/backup-log/run.log
add_file $INSTALL/backup-log/error.log
install_log=$INSTALL/backup-log/install.log
add_file $install_log

echo "--- $(date)" > $install_log
datenow=$(date)
function log { 
  echo "[$datenow] $1" >> $install_log 
}

log "installing as $USER"

master=$INSTALL/backup-toolkit.conf
echo "---" > $master
echo "jobs_directory: $INSTALL/backup-jobs" >> $master
echo "staging_directory: $INSTALL/backup-staging" >> $master
echo "logging_directory: $INSTALL/backup-log" >> $master
echo "local_hostname: $(hostname)" >> $master
echo "bin_directory: $INSTALL" >> $master

chown -R $USER:$USER $INSTALL/backup-log
chown -R $USER:$USER $INSTALL/backup-jobs
chown -R $USER:$USER $INSTALL/backup-staging

# get the name of the current directory
dist=$PWD/$(dirname $0)

for script in mysql-dump.sh tar-dump.sh backup-runner.rb; do
  log "installing $script"
  add_file $INSTALL/$script 
  mv $dist/$script $INSTALL/$script
done

# Setup cronjob
if [ -z "$hour" -o -z "$minute" ]; then
  ## insert cronjob to run at random time before 4 AM
  # m h dom mon dow user command
  minutes=60
  hours=4
  hour=1
  minute=1
  let "hour = $RANDOM % $hours +1"
  let "minute = $RANDOM % $minutes"
fi

log "installing backup-runner cronjob for runtime $hour:$minute and user $USER"
cronfile=$INSTALL/backup-toolkit.cron
add_file $cronfile
# preserve existing cronjobs, replace backup-runner job.
crontab -u $USER -l | grep -v backup-runner.rb > $cronfile
# add new cronfile
echo "$minute $hour * * * $INSTALL/backup-runner.rb" >> $cronfile
# update cronjobs
crontab -u $USER $cronfile

log "finished installing backup-toolkit"

echo cat $install_log
