#!/usr/bin/env bash
#
# Usage: 
#  sudo ./install.sh
#
# Run from production machine

if [ -z "$1" ]; then
  echo "Usage: install.sh USER"
  exit 1
else
  username=$1
fi

if [ ! "root" == "$(id | sed 's/uid=[0-9][0-9]*(\([^)]*\)).*/\1/')" ]; then
  echo "install.sh must be run as root."
  exit 1
fi

if [ ! -x "/home/$1" ]; then 
  echo "User $1 has no /home/$1 directory, please give valid username" 
  exit 1
fi


mkdir -p /home/$username/.backup-staging
mkdir -p /home/$username/.backup-log
touch /home/$username/.backup-log/run.log
touch /home/$username/.backup-log/error.log
install_log=/home/$username/.backup-log/install.log
touch $install_log
mkdir -p /home/$username/.backup-config
master=/home/$username/.backup-config/master.config
touch $master
echo "---" >> $master
echo "config-directory: /home/$username/.backup-config" >> $master
echo "staging-directory: /home/$username/.backup-staging" >> $master
echo "logging-directory: /home/$username/.backup-staging" >> $master

echo "[$(date)] installing mysql-dump" >> $install_log
chmod +x mysql-dump.sh 
cp mysql-dump.sh /usr/local/bin/mysql-dump
echo "[$(date)] installing tar-dump" >> $install_log
chmod +x tar-dump.sh
cp tar-dump.sh /usr/local/bin/tar-dump 
echo "[$(date)] installing backup-runner" >> $install_log
chmod +x backup-runner.rb
cp backup-runner.rb /usr/local/bin/backup-runner

echo "[$(date)] installing /etc/cron.d/backup-runner" >> $install_log

## insert cronjob
# m h dom mon dow user	command

# run at random time
minutes=60
hours=4
hour=1
minute=1
let "hour = $RANDOM % $hours +1"
let "minute = $RANDOM % $minutes"

cronfile=/etc/cron.d/backup-runner
touch $cronfile
chmod +x $cronfile
echo "# cron entry for backup-runner (SLS Internal)" >  $cronfile
echo "SHELL=/bin/sh" >> $cronfile
echo "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" >> $cronfile
echo "$minute $hour * * * $username /usr/local/bin/backup-runner" >> $cronfile

echo "[$(date)] finished installing backup-toolkit" >> $install_log
