#!/usr/bin/env bash

if [ -z "$1" ]; then
  echo "Usage: uninstall.sh USER"
  exit 1
else
  username=$1
fi

if [ ! "root" == "$(id | sed 's/uid=[0-9][0-9]*(\([^)]*\)).*/\1/')" ]; then
  echo "uninstall.sh must be run as root."
  exit 1
fi

if [ ! -x "/home/$1" ]; then 
  echo "User $1 has no /home/$1 directory, please give valid username" 
  exit 1
fi

echo "removing /home/$username/.backup-staging "
rm -rf /home/$username/.backup-staging 
echo "removing /home/$username/.backup-log "
rm -rf /home/$username/.backup-log
echo "removing /home/$username/.backup-config "
rm -rf /home/$username/.backup-config

echo "removing mysql-dump"
rm -f /usr/local/bin/mysql-dump
echo "removing tar-dump"
rm -f /usr/local/bin/tar-dump 
echo "removing backup-runner"
rm -f /usr/local/bin/backup-runner

echo "removing /etc/cron.d/backup-runner"
rm -f /etc/cron.d/backup-runner

echo "finished removing backup-toolkit"

