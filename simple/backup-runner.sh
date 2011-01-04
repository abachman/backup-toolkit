# Backup Script
#
# Requires:
#   https://github.com/abachman/backup-toolkit/raw/master/dist/mysql-dump.sh
#   https://github.com/abachman/backup-toolkit/raw/master/dist/tar-dump.sh
#
# From https://github.com/abachman/backup-toolkit
#
# On the server to be backed up, run:
#   curl https://github.com/abachman/backup-toolkit/raw/master/simple/install.sh | sh
# or
#   curl -k https://github.com/abachman/backup-toolkit/raw/master/simple/install.sh | sh
# if you get ssl certificate problems
#
# Update with:
#   curl -k https://github.com/abachman/backup-toolkit/raw/master/simple/backup-runner.sh > ~/bin/backup-runner.sh

set -e
set -u

# important local variables
ROOT=/home/deploy
BACKUP_STAGING_DIR=$ROOT/backup-staging
mkdir -p $BACKUP_STAGING_DIR

logfile=$ROOT/logs/backup.log
function log {
  echo "[$(date +"%Y/%m/%d %H:%M:%S")] $1" >> $logfile
}

# More important variables, config filename is passed in when script is called
if [ -e $1 ]; then
  # include the config file
  . $1
else
  log "You must include a config file"
  exit 1
fi

# catalog by year/month
REMOTE_DIR=${REMOTE_DIR}/$(date +%Y)/$(date +%m)

# LOCKFILE
lockfile=$ROOT/.backup-runner.pid
if [ -e $lockfile ]; then
  log "lockfile '$lockfile' already exists"
  log "held by process $(cat $lockfile)"
  exit 1
fi
echo $$ > $lockfile
trap 'rm -f "$lockfile"; exit' INT TERM EXIT

########
# Backup

# clean backups older than 30 days if we have at least 10 more recent ones.
# this will prevent the deletion of old backups if we have no current ones.
if [ $(find $BACKUP_STAGING_DIR/*.tar.gz -mtime -30 -exec echo {} \; | wc -l) -gt 5 ]; then
  find $BACKUP_STAGING_DIR/*.tar.gz -mtime +30 -exec rm {} \;
fi

# directory backup
tarout=$ROOT/.backup-runner.tar.out
/home/deploy/bin/tar-dump.sh -d${BACKUP_STAGING_DIR} $TAR_DIRECTORY > $tarout
if [ $? ]; then
  TAR_FILE=$(tail -n1 $tarout)
  log "NEW TAR FILE AT $TAR_FILE"
else
  TAR_FILE=''
  log "bad tar-dump.sh exit status"
fi

# mysql backup
mysqlout=$ROOT/.backup-runner.mysql.out
/home/deploy/bin/mysql-dump.sh -v -u$MYSQL_USERNAME -p$MYSQL_PASSWORD -t$BACKUP_STAGING_DIR $MYSQL_DATABASE > $mysqlout
if [ $? ]; then
  MYSQL_FILE=$(tail -n1 $mysqlout)
  log "NEW MYSQL FILE AT $MYSQL_FILE"
else
  MYSQL_FILE=''
  log "bad mysql-dump.sh exit status"
fi

######
# Send

ssh $REMOTE_USER@$REMOTE_HOST "mkdir -p $REMOTE_DIR"

if [ -e $TAR_FILE ]; then
  nice rsync $TAR_FILE $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR >> $logfile
fi

if [ -e $MYSQL_FILE ]; then
  nice rsync $MYSQL_FILE $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR >> $logfile
fi

log "done"
exit

