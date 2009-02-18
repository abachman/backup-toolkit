#!/usr/bin/env ruby
# 
# Deploy your public key to two servers, then deploy PRODUCTION key to BACKUP.
#
# If PRODUCTION doesn't already have a public key to give to BACKUP, one will 
# be created.  Use -v (verbose mode) if you want to see what's happening.
#
# config/backup.yml and config/production.yml are used to hold login info
# for their respective servers.
#

require 'my_utils'
require 'rubygems'
require 'net/ssh'
require "yaml"

class Server
  attr_accessor :address, :username, :password
end

class KeyExchange
  def initialize
  end

  def run
    get_backup_info
    get_production_info

    # send my key to production and backup
    send_local_keyfile @backup_server.address, @backup_server.username, 'backup'
    send_local_keyfile @production_server.address, @production_server.username, 'production'

    # send production key to backup
    prod_key = setup_production_keyfile
    send_production_keyfile_remote prod_key
  end
  
  # {{{ Setup production keyfiles
  def setup_production_keyfile
    key_choices = ''
    Net::SSH.start(@production_server.address, @production_server.username, :password => @production_server.password) do |ssh|
      keys = ""
      do_create = false
      ssh.exec! "ls ~/.ssh/*.pub" do |channel, stream, data|
        if stream == :stderr
          if /No such file or directory/ =~ data
            do_create = true
          end
        else
          keys << data
        end
      end
      if do_create
        log "[on production] creating key on remote server"
        chn = ssh.open_channel do |channel|
          channel.exec("ssh-keygen -q -t rsa") do |ch, success|
            abort "could not execute ssh-keygen on #{@production_server.address}" unless success

            channel.on_data do |ch, data|
              log "got stdin: #{data}"
            end

            channel.on_extended_data do |ch, type, data|
              case data
              when /Enter /
                ch.send_data "\n"
              else
                log "got stderr: #{data}"
              end
            end

            channel.on_close do |ch|
              log "created key on #{@production_server.address}"
            end
          end
        end
        chn.wait
        ssh.exec! "ls ~/.ssh/*.pub" do |channel, stream, data|
          keys << data if stream == :stdout
        end
      end
      key_choices << keys
    end
    keys = key_choices.split() 
    puts "[production to backup] Which key from production will you use? [0]"
    c = 0
    for key in keys
      puts "\t#{c}.\t#{key}"
      c += 1
    end
    return keys[input.to_i || 0]
  end

  def send_production_keyfile_remote keyfile
    log "adding production keyfile to backup"
    
    # bring production key down to local machine'
    log "bringing down key from production"
    pserver = "#{@production_server.username}@#{@production_server.address}"
    `scp #{pserver}:#{keyfile} /tmp/production.keyfile`

    log "sending production's key to backup"
    bserver = "#{@backup_server.username}@#{@backup_server.address}"
    deploy_and_apply_keyfile bserver, '/tmp/production.keyfile', "backup (production key)"

    log "production machine can now log in to backup"
  end
  # }}}
  
  # {{{ Local Key File actions
  def choose_keyfile    
    keys = `ls ~/.ssh/*.pub`.split()
    default = keys.empty? ? nil : keys[0]
    puts "[local] Which personal key do you want to deploy? [0]"
    c = 0
    for key in keys
      puts "\t#{c}.\t#{key}"
      c += 1
    end
    return keys[input.to_i || 0]
  end

  def send_local_keyfile addr, user, dest
    @kf ||= choose_keyfile
    server = (addr && user) ? "#{user}@#{addr}" : input("[local to #{dest}] To which server?", "#{user}@#{addr}")
    log "[local to #{dest}] Deploying #{@kf} to #{server}"
    deploy_and_apply_keyfile server, @kf, dest
  end

  # params 
  #   server: user@address
  #   keyfile: /path/to/local/keyfile
  def deploy_and_apply_keyfile server, keyfile, dest
    tk, ts = generate_key_application_script
    # COPY OVER
    log "copying keyfile to #{dest}"
    `scp #{keyfile} #{server}:~/#{tk}`
    log "copying script to #{dest}"
    `scp #{ts} #{server}:~/#{ts}`
    # EXCUTE KEY APPLICATION
    log "executing script on #{dest}"
    `ssh #{server} "~/#{ts}"`
    # CLEANUP
    log "removing remote files from #{dest}"
    `ssh #{server} "rm ~/#{tk} ~/#{ts}"`
    log "removing local temp file"
    `rm -f #{ts}`
  end
  
  def generate_key_application_script
    # generates script to be executed on remote machine that adds a given key 
    # to the remote machine's .ssh/authorized_keys file only if it hasn't already
    # been added.
    #
    # expects to be executed from the remote user's ~/ directory:
    #   `ssh #{server} "~/#{ts}"`
    tk = ".temp_key_#{rand(5000)}"
    ts = ".temp_script_#{rand(5000)}"
    FileUtils.touch(ts)
    FileUtils.chmod(0755, ts)
    File.open(ts, 'w') do |f| 
      f.write "mkdir -p ~/.ssh && "
      f.write "touch ~/.ssh/authorized_keys && "
      f.write "if [ -z \"$(grep -f#{tk} ~/.ssh/authorized_keys)\" ]; then cat #{tk} >> ~/.ssh/authorized_keys; fi"
    end
    [tk, ts]
  end
  # }}}
 
  # {{{ Get Server Info
  def get_backup_info
    @backup_server = Server.new
    opts = {}
    if File.exist? File.join(File.dirname(__FILE__), 'config','backup.yml')
      opts = File.open(File.join(File.dirname(__FILE__), 'config','backup.yml')) { |yf| YAML::load( yf ) }
      log "[backup] Using config file for settings #{opts.inspect}"
    end
    
    @backup_server.address = opts['address'] || input("Which backup server will the script use?", 'backup.dreamhost.com')
    @backup_server.username = opts['username'] || input("Which username will the script use?", 'b112819')
    @backup_server.password = opts['password'] || input("Which password will the script use?", nil)
  end

  def get_production_info
    @production_server = Server.new
    opts = {}
    if File.exist? File.join(File.dirname(__FILE__), 'config','production.yml')
      opts = File.open(File.join(File.dirname(__FILE__), 'config','production.yml')) { |yf| YAML::load( yf ) }
      log "[production] Using config file for settings #{opts.inspect}"
    end
    @production_server.address = opts['address'] || input("Which production server will the script run from?", 'gen')
    @production_server.username = opts['username'] || input("Which username accesses the production server?", 'adam')
    @production_server.password = opts['password'] || input("Which password accesses the production server?", 'adam')
  end 
  # }}}
end

creator = KeyExchange.new
creator.run
