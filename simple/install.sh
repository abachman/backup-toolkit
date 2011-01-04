# Install thyself.
#
# On the server to be backed up, run:
#   curl https://github.com/abachman/backup-toolkit/raw/master/simple/install.sh | sh
# or
#   curl -k https://github.com/abachman/backup-toolkit/raw/master/simple/install.sh | sh
# if you get ssl certificate problems

mkdir -p ~/bin
curl -k https://github.com/abachman/backup-toolkit/raw/master/simple/backup-runner.sh > ~/bin/backup-runner.sh
curl -k https://github.com/abachman/backup-toolkit/raw/master/dist/tar-dump.sh > ~/bin/tar-dump.sh
curl -k https://github.com/abachman/backup-toolkit/raw/master/dist/mysql-dump.sh > ~/bin/mysql-dump.sh

for f in backup-runner.sh tar-dump.sh mysql-dump.sh; do
  if [ -e ~/bin/$f ]; then
    chmod +x ~/bin/$f
  else
    echo "ERROR DOWNLOADING FILE ~/bin/$f"
  fi
done

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

printf "The files are in place, now you have to create a cron task. For example:\n\n"
printf "  # example cronjob\n  30 01 * * * /home/deploy/bin/backup-runner /home/deploy/MYPROJECT.backup-runner.conf\n\n" >&2
printf "Or, you can add a small script to /etc/cron.daily. For example: \n\n" >&2
printf "  sudo echo -n '#!/bin/sh\\n/home/deploy/bin/backup-runner.sh /home/deploy/MYPROJECT.backup-runner.conf' > /etc/cron.daily/backup-runner\n" >&2
printf "  sudo chmod +x /etc/cron.daily/backup-runner\n\n" >&2
