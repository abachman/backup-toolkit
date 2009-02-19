#!/usr/bin/env bash
#
# Generate timestamped, gzipped directory dump with sensible defaults.

TIMESTAMP=`date +%Y_%m_%d-%H_%M_%S`
SPEC_FILENAME=0
VFLAG=0
VERBOPT=
HAS_DEST=0
DESTINATION=.
EXCLUDE=
while getopts 'f:d:e:cvlh' OPTION
do
  case $OPTION in
  f) SPEC_FILENAME=1; FILENAME=$TIMESTAMP-$OPTARG.tar.gz
    ;;
  d) HAS_DEST=1; DESTINATION=$OPTARG
    ;;
  v) VFLAG=1; VERBOPT=v
    ;;
  e) EXCLUDE="$EXCLUDE --exclude=$OPTARG"
    ;;
  c) EXCLUDE="--exclude-vcs $EXCLUDE"
    ;;
  h|?)
    printf "Backs up SOURCE to DESTINATION.  By default will backup . to .\n\n" >&2
    printf "Usage: %s: [-vhn] [-f filename] [-d destination] [-e PATTERN] source\n" $(basename $0) >&2
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

if [ $SPEC_FILENAME -eq 0 ]; then
  FILENAME=$TIMESTAMP-`pwd | awk '{sub(/\//,"",$0); gsub(/\//,"-",$0); print $0}'`.tar.gz
fi

if [ $VFLAG -eq 1 ]; then
  printf "Generating directory backup for $SOURCE\n"
  printf "\ttarget\t$DESTINATION/$FILENAME\n"
fi

nice tar zc${VERBOPT}f $DESTINATION/$FILENAME $SOURCE $EXCLUDE

echo $DESTINATION/$FILENAME
