# Install or update thyself.
#
# On the server to be backed up, run:
#   curl https://github.com/abachman/backup-toolkit/raw/master/simple/install.sh | sh
# or
#   curl -k https://github.com/abachman/backup-toolkit/raw/master/simple/install.sh | sh
# if you get ssl certificate problems

mkdir -p ~/bin

echo 'getting backup-runner.sh'
curl -k https://github.com/abachman/backup-toolkit/raw/master/simple/backup-runner.sh > ~/bin/backup-runner.sh
echo 'getting tar-dump.sh'
curl -k https://github.com/abachman/backup-toolkit/raw/master/dist/tar-dump.sh > ~/bin/tar-dump.sh
echo 'getting mysql-dump.sh'
curl -k https://github.com/abachman/backup-toolkit/raw/master/dist/mysql-dump.sh > ~/bin/mysql-dump.sh

for f in backup-runner.sh tar-dump.sh mysql-dump.sh; do
  if [ -e ~/bin/$f ]; then
    chmod +x ~/bin/$f
  else
    echo "ERROR DOWNLOADING FILE ~/bin/$f"
  fi
done

if [ ! -e ~/MYPROJECT.backup-runner.conf ]; then
cat <<EOF > ~/MYPROJECT.backup-runner.conf
# backup-runner configuration values, all must be populated

# local mysql database needing backup
MYSQL_USERNAME=
MYSQL_PASSWORD=
MYSQL_DATABASE=

# path to directory needing backup
TAR_DIRECTORY=

# Remote backup hosting
REMOTE_USER=
REMOTE_HOST=
REMOTE_DIR=
EOF
fi

echo
echo "========================================================================"
echo "The files are in place, now you have to create a cron task. For example:"
echo
echo "  # example cronjob"
echo "  30 01 * * * /home/deploy/bin/backup-runner.sh /home/deploy/MYPROJECT.backup-runner.conf"
echo
echo "Or create a small script like this:"
echo
echo "  #!/bin/sh"
echo "  /home/deploy/bin/backup-runner.sh /home/deploy/MYPROJECT.backup-runner.conf"
echo
echo "and add it to /etc/cron.daily."
echo "========================================================================"
echo
