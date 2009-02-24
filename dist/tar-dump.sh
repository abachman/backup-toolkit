#!/usr/bin/env bash
#
# Generate timestamped, gzipped directory dump with sensible defaults.
VERBOPT=
HAS_DEST=0
DESTINATION=.
EXCLUDE=
while getopts 'd:e:cvlh' OPTION
do
  case $OPTION in
  d) HAS_DEST=1; DESTINATION=$OPTARG
    ;;
  v) VERBOPT=v
    ;;
  e) EXCLUDE="$EXCLUDE --exclude=$OPTARG"
    ;;
  c) EXCLUDE="--exclude-vcs $EXCLUDE"
    ;;
  h|?)
    printf "Backs up SOURCE to DESTINATION.  By default will backup . to .\n\n" >&2
    printf "Usage: %s: [-vhn] [-d destination] [-e PATTERN] /path/to/source\n" $(basename $0) >&2
    printf "\t-h\tShow this help screen and exit\n" >&2
    printf "\t-v\tVerbose output\n" >&2
    printf "\t-e\ttar --exclude PATTERN, 'man tar' for details. NOTE: to ignore\n" >&2
    printf "\t\tmultiple patterns, you must list the -e arg multiple times.\n" >&2
    printf "\t-c\ttar --exclude-vcs, ignore version control. 'man tar' for details. \n" >&2
    printf "\t-d\tDestination: should be a path somewhere on the\n" >&2 
    printf "\t\tlocal server, defaults to .\n\n" >&2
    exit 2
    ;;
  esac
done
shift $(($OPTIND - 1))

if [ -z "$1" ]; then
  SOURCE=.
else
  SOURCE=$1
fi

# Backups are specific to the day.
tstamp=`date +%Y_%m_%d`
dirname=`echo $SOURCE | awk '{sub(/\//,"",$0); gsub(/\//,"-",$0); print $0}'`
FILENAME=$tstamp-$dirname.tar.gz

if [ "$VERBOPT"="v" ]; then
  printf "Generating directory backup for $SOURCE\n"
  printf "\ttarget\t$DESTINATION/$FILENAME\n"
fi

# Only create a new dump if one doesn't exist. This prevents duplication of effort in the case that 
# we have multiple tasks backing up the same directory at the same time.
[ ! -e $DESTINATION/$FILENAME ] && (nice tar zc${VERBOPT}f $DESTINATION/$FILENAME $SOURCE $EXCLUDE)

echo $DESTINATION/$FILENAME
