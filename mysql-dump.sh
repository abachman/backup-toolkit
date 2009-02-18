#!/usr/bin/env bash
#
# Generate timestamped, gzipped mysql dump with sensible defaults.

USER=root
# if no password is given, it will prompt
PASSWORD=
HOST=localhost
DATABASE=information_schema
TIMESTAMP=`date +%Y_%m_%d-%H_%M_%S`
SPEC_FILENAME=0
VFLAG=0
LIST_DBS=0
HAS_TARG=0
TARGET=.
while getopts 'u:p:s:f:t:vlh' OPTION
do
  case $OPTION in
  u) USER=$OPTARG
    ;;
  p) PASSWORD=$OPTARG
    ;;
  s) HOST=$OPTARG
    ;;
  f) SPEC_FILENAME=1; FILENAME=$TIMESTAMP-$OPTARG.sql.gz
    ;;
  t) HAS_TARG=1; TARGET=$OPTARG
    ;;
  v) VFLAG=1
    ;;
  l) LIST_DBS=1
    ;;
  h|?)
    printf "Usage: %s [-vhl] [-u username] [-p password] " $(basename $0) >&2
    printf "[-s host] [-f filename] [-t /destination/directory] database\n" >&2
    printf "\t-l\tList databases and exit\n" >&2
    printf "\t-h\tShow this help screen and exit\n" >&2
    printf "\t-v\tVerbose output\n" >&2
    printf "\t-t\tDestination: should be a path somewhere on local server\n\n" >&2
    exit 2
    ;;
  esac
done
shift $(($OPTIND - 1))

if [ -z "$1" ]; then
  DATABASE=information_schema
else
  DATABASE=$1
fi

if [ $LIST_DBS -eq 1 ]; then
  mysql -u $USER -p$PASSWORD -Bse 'show databases'
  exit
fi

if [ $SPEC_FILENAME -eq 0 ]; then
  FILENAME=$TIMESTAMP-$DATABASE.sql.gz
fi

if [ $HAS_TARG -eq 1 ]; then
  TARGET=$TARGET/$FILENAME
fi

if [ $VFLAG -eq 1 ]; then
  echo "Generating Mysql backup for $DATABASE on $HOST and move to $TARGET"
  echo "\tuser\t$USER"
  echo "\tpassword\t$PASSWORD"
  echo "\tfilename\t$FILENAME"
  echo "\ttarget\t$TARGET"
fi

nice mysqldump -u $USER -h $HOST -p$PASSWORD $DATABASE | gzip -9 > $FILENAME
if [ $HAS_TARG -eq 1 ]; then
  nice mv $FILENAME $TARGET
fi

echo $TARGET
