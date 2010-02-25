#!/usr/bin/env ruby
#
# Get backup settings files and run all scheduled backups.
#
# Expects only the master config file: backup-toolkit.conf 
#
# This script generates and executes command line commands based on 
# the config.backup files contained in $install_directory/backup-jobs
#

require 'yaml'
require 'fileutils'
require 'logger'

# how many times should we try to send the file?
MAX_RETRY = 3

# find master config
found = false
for filename in %w( backup-toolkit.conf ../backup-toolkit.conf ../backup-config/backup-toolkit.conf ../config/backup-toolkit.conf )
  puts "looking for config in #{ File.join(File.dirname(__FILE__), filename) }"
  filename = File.join(File.dirname(__FILE__), filename)
  if File.exist? filename
    MASTER_CONFIG = File.open(filename) { |yf| YAML::load( yf ) }
    found = true
    break
  end
end
if not found 
  puts "Failed to find config file! ABORT"
  raise "FAILED TO FIND CONFIG FILE"
else 
  puts "found config.... running"
end

BACKUP_JOBS_DIR = Dir.new(MASTER_CONFIG['jobs_directory'])
BACKUP_STAGING_DIR = Dir.new(MASTER_CONFIG['staging_directory'])
BACKUP_LOGGING_DIR = Dir.new(MASTER_CONFIG['logging_directory'])
BACKUP_BIN_DIR = Dir.new(MASTER_CONFIG['bin_directory'])
HOSTNAME = MASTER_CONFIG['local_hostname'] || `hostname`.chomp

# Setup logger
log_file = File.open(File.join(BACKUP_LOGGING_DIR.path, "run.log"), 
                     File::WRONLY | File::APPEND | File::CREAT | File::SYNC)
log = Logger.new(log_file, 10, 1024000)
log.level = Logger::DEBUG

log.info("starting backup of #{ HOSTNAME }")

BACKUP_SETTINGS = []
BACKUP_JOBS_DIR.each do |file|
  next unless /^.*\.backup$/ =~ file
  puts "loading file: #{ file }"
  log.debug("loading file: #{ file }")
  job = File.open(File.join(BACKUP_JOBS_DIR.path, file)) { |f| YAML::load( f ) }
  # job is {type => { setting => 'value', setting_two => 'value' }}
  # so we turn it into { type => 'type', setting => 'value', setting_two => 'value' }
  job['type'] = job.clone().shift().first
  job[job['type']].keys.each do |k|
    job[k] = job[job['type']][k]
  end
  job['file'] = file
  BACKUP_SETTINGS << job
end

# GENERATE BACKUP FILES
for config in BACKUP_SETTINGS
  # do all backups.
  case config['type']
  when 'directory'
    puts "doing directory backup of #{config['path']}"
    log.debug("doing directory backup of #{config['path']}")
    output = `#{BACKUP_BIN_DIR.path}/tar-dump.sh -d#{BACKUP_STAGING_DIR.path} #{config['path']}`
  when 'mysql'
    puts "doing mysql backup of #{config["database"]}"
    log.debug("doing mysql backup of #{config["database"]}")
    output = `#{BACKUP_BIN_DIR.path}/mysql-dump.sh -v -u#{config['username']} -p#{config['password']} -t#{BACKUP_STAGING_DIR.path} #{config['database']}`
  else
    puts "FAILURE! UNKNOWN BACKUP TYPE!" # FAIL
    next
  end
 
  # Store generated values in config hash
  # last line of output should return created filename.
  local_filename = output.split.last
  config['local_filename'] = local_filename
  config['count'] = 0
end

log.info("sending staged backups")
for config in BACKUP_SETTINGS
  # Make sure we know the host we'll be sending to.
  puts "confirming known host status"
  `#{BACKUP_BIN_DIR.path}/setup-ssh.sh #{config["backup_hostname"]}`

  type = config['type']
  unless config['local_filename'] # FAIL
    log.error("backup file creation failed for job: #{ config['file'] }")
    next
  end
  local_fullfilename = config['local_filename']
  local_filename = File.split(local_fullfilename).last
  puts "sending #{local_filename} to #{config["backup_hostname"]}:#{config["backup_destination"]}"
  log.debug("sending #{local_filename} to #{config["backup_hostname"]}:#{config["backup_destination"]}")
  begin
    # Copy file from local to remote, renaming to prepend the sender (this node's hostname).
    puts "SCP COMMAND: nice scp #{local_fullfilename} #{config["backup_username"]}@#{config["backup_hostname"]}:#{config["backup_destination"]}/#{ HOSTNAME }-#{local_filename}"
    `nice scp #{local_fullfilename} #{config["backup_username"]}@#{config["backup_hostname"]}:#{config["backup_destination"]}/#{ HOSTNAME }-#{local_filename}`
    puts "#{local_filename} sent to #{config["backup_hostname"]}:#{config["backup_destination"]}/#{ HOSTNAME }-#{local_filename}"
    log.info("#{local_filename} sent to #{config["backup_hostname"]}:#{config["backup_destination"]}/#{ HOSTNAME }-#{local_filename}")
  rescue
    log.error("ERROR SENDING #{ local_filename } to #{ config["backup_hostname"] }:#{ config["backup_destination"] }")
    if config['count'] < MAX_RETRY
      config['count'] = config['count'] + 1
      BACKUP_SETTINGS << config
    end
  end
end

log.info("cleaning up staged files")
BACKUP_STAGING_DIR.each do |staged_file|
  `rm -rf #{local_fullfilename}`
end

log.info("backup complete")
log.close()

