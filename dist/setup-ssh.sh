#!/bin/bash

function print_usage {
  printf "Usage: %s HOSTNAME\n" $(basename $0) >&2
}

if [ -z "$1" ]; then
  echo "Must give hostname to check for."
  print_usage
  exit 1
fi

touch ~/.ssh/known_hosts

if [ -z "$(grep $1 ~/.ssh/known_hosts)" ]; then
  # Add host to known_hosts file
  echo "... adding $1 to known_hosts"
  ssh-keyscan -t rsa,dsa $1 >> ~/.ssh/known_hosts
else
  echo "$1 already exists as known_host"
fi
