#!/usr/bin/env ruby
#
# Get backup settings files and run all scheduled backups.
#
# Expects directories on localhost:
#   ~/.backup-config
#   ~/.backup-staging
#   ~/.backup-log
#
require 'yaml'
require 'fileutils'

# how many times should we try to send the file?
MAX_RETRY = 3

BACKUP_SETTINGS_DIR = Dir.new("/home/adam/.backup-config")
BACKUP_STAGING_DIR = Dir.new("/home/adam/.backup-staging") rescue FileUtils.mkdir_p("/home/adam/.backup-staging")
BACKUP_SETTINGS = []
BACKUP_SETTINGS_DIR.each do |file|
  next unless /^.*\.yml$/ =~ file
  BACKUP_SETTINGS << File.open(File.join(BACKUP_SETTINGS_DIR.path, file)) { |f| YAML::load( f ) }
end

# GENERATE BACKUP FILES
for config in BACKUP_SETTINGS
  # do all backups.
  temp = File.join(BACKUP_STAGING_DIR.path, '.out')
  if config['directory']
    s = config['directory']
    puts "doing dir back of #{s['path']}"
    output = `tar-dump -d/home/adam/.backup-staging #{s['path']}`
  elsif config['mysql']
    s = config['mysql']
    puts "doing mysql back of #{s["database"]}"
    output = `mysql-dump -u#{s['username']} -p#{s['password']} -t/home/adam/.backup-staging #{s['database']}`
  end
  
  # Store generated values in config hash
  local_filename = output.split.last
  s['local-filename'] = local_filename
  s['count'] = 0
end

for config in BACKUP_SETTINGS
  s = config['directory'] || config['mysql']
  local_filename = s['local-filename']
  puts "sending #{local_filename} to #{s["backup-hostname"]}:#{s["backup-destination"]}"
  begin
    copy_out = `nice scp #{local_filename} #{s["backup-username"]}@#{s["backup-hostname"]}:#{s["backup-destination"]}`
    if $? != 0
      raise "MAJOR ERROR!"
    end
    FileUtils.rm local_filename
    # Log transfer
    `echo "[$(date)] #{local_filename} sent to #{s["backup-hostname"]}:#{s["backup-destination"]}" >> /home/adam/.backup-log/backup-toolkit.log`
  rescue
    if s['count'] < MAX_RETRY
      s['count'] = s['count'] + 1
      BACKUP_SETTINGS << config
    end
  end
end



