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

# who are we running as?
begin
  MASTER_CONFIG = File.open("/etc/backup-toolkit.conf") { |yf| YAML::load( yf ) }
rescue 
  `echo "[$(date)] FAILED TO START, NO MASTER CONFIG FILE" >> /tmp/fail.log`
  puts "Failed to find config file! ABORT"
  raise
end

BACKUP_SETTINGS_DIR = Dir.new(MASTER_CONFIG['config_directory'])
BACKUP_STAGING_DIR = Dir.new(MASTER_CONFIG['staging_directory'])
BACKUP_LOGGING_DIR = Dir.new(MASTER_CONFIG['logging_directory'])
HOSTNAME = MASTER_CONFIG['local_hostname'] || `hostname`.chomp
BACKUP_SETTINGS = []
BACKUP_SETTINGS_DIR.each do |file|
  next unless /^.*\.backup$/ =~ file
  BACKUP_SETTINGS << File.open(File.join(BACKUP_SETTINGS_DIR.path, file)) { |f| YAML::load( f ) }
end

`echo "starting backup of #{ HOSTNAME }" >> #{File.join(BACKUP_LOGGING_DIR.path, "run.log")}`

# GENERATE BACKUP FILES
for config in BACKUP_SETTINGS
  # do all backups.
  temp = File.join(BACKUP_STAGING_DIR.path, '.out')
  if config['directory']
    s = config['directory']
    puts "doing directory backup of #{s['path']}"
    output = `tar-dump -d#{BACKUP_STAGING_DIR.path} #{s['path']}`
  elsif config['mysql']
    s = config['mysql']
    puts "doing mysql backup of #{s["database"]}"
    output = `mysql-dump -v -u#{s['username']} -p#{s['password']} -t#{BACKUP_STAGING_DIR.path} #{s['database']}`
  end
  
  # Store generated values in config hash
  # last line of output should return created filename.
  local_filename = output.split.last
  s['local_filename'] = local_filename
  s['count'] = 0
end

for config in BACKUP_SETTINGS
  s = config['directory'] || config['mysql']
  local_fullfilename = s['local_filename']
  local_filename = File.split(local_fullfilename).last
  puts "sending #{local_filename} to #{s["backup_hostname"]}:#{s["backup_destination"]}"
  begin
    # Copy file from local to remote, renaming to prepend the sender (this node's hostname).
    `nice scp #{local_fullfilename} #{s["backup_username"]}@#{s["backup_hostname"]}:#{s["backup_destination"]}/#{ HOSTNAME }-#{local_filename}`
    `echo "[$(date)] #{local_filename} sent to #{s["backup_hostname"]}:#{s["backup_destination"]}/#{ HOSTNAME }-#{local_filename}" >> #{File.join(BACKUP_LOGGING_DIR.path, "run.log")}`
    `rm -rf #{local_fullfilename}`
  rescue
    `echo "[$(date)] ERROR SENDING #{local_filename} to #{s["backup_hostname"]}:#{s["backup_destination"]}" >> #{File.join(BACKUP_LOGGING_DIR.path, "error.log")}`
    if s['count'] < MAX_RETRY
      s['count'] = s['count'] + 1
      BACKUP_SETTINGS << config
    end
  end
end

`echo "finished backup of #{ HOSTNAME }" >> #{File.join(BACKUP_LOGGING_DIR.path, "run.log")}`
