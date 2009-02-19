#!/usr/bin/env ruby
#
# Deploy a backup-runner config file to a production server.
#
# Make sure you run key-exchange.rb first.
#

require 'lib/my_utils'
require 'rubygems'
#require 'key-exchange' # uncomment this line to force key exchange

class Server
  attr_accessor :hostname, :username, :password, :name
  def ssh_address
    "#{username}@#{hostname}"
  end
end

module BackupToolkit
  class CreateBackupScript
    def initialize
    end

    def run
      @backup_server = BackupToolkit::get_server_info("backup")
      @production_server = BackupToolkit::get_server_info("production")

      # get backup command params
      @backup_params = get_backup_command_params
      conf_files = []
      for cmd in @backup_params
        conf_files << write_config_file(cmd)
      end
      
      # do install
      puts `ssh #{@production_server.ssh_address} "ls /home/#{@production_server.username}/.backup-config"`
      if $? != 0
        puts "MUST INSTALL ON PRODUCTION, copying files."
        install_dir = "/home/#{@production_server.username}/.backup-install"
        `ssh #{@production_server.ssh_address} "mkdir -p #{install_dir}"`
        install_files = []
        for file in Dir.new("dist/")
          next unless File.file?(File.join('dist', file))
          # local, remote
          install_files << [File.join('dist', file), "#{install_dir}/#{File.split(file).last}"]  
        end
        puts install_files.inspect
        BackupToolkit::send_files(@production_server, *install_files)
        Net::SSH.start(@production_server.hostname, 
                       @production_server.username,
                       :password => @production_server.password) do |ssh|
          ssh.open_channel do |channel|
            ################## TODO: figure out this pty crap
            channel.request_pty do |ch, success|
              if success
                puts "pty successfully obtained, run 'sudo ~/.backup-install/install.sh #{@production_server.username}' "
                ch.send_data "sudo ~/.backup-install/install.sh #{@production_server.username}"
              else
                puts "could not obtain pty, quitting"
                exit 1
              end
            end
         end
         ssh.loop
       end
      end

      for file in conf_files 
        BackupToolkit::send_files(@production_server, [file, "/home/#{@production_server.username}/.backup-config/#{file}"] )
      end
    end

    def get_backup_command_params
      backup_settings = {
        'backup-destination' => "/home/#{@backup_server.username}/backups",
        'backup-hostname' => @backup_server.hostname,
        'backup-username' => @backup_server.username,
        'backup-password' => @backup_server.password
      }
      params = []
      looop = true
      while looop == true 
        case input("[production] Which backup command would you like to generate? [mysql|directory|quit|] ", nil).downcase
        when /^my/
          database = input("\t[mysql] enter database name:", nil)
          username = input("\t[mysql] enter username:", nil)
          password = input("\t[mysql] enter password:", nil)
          unless database && username && password 
            puts "!! Must enter all values."
          else 
            params << {'mysql' => { 'database' => database,
                                   'username' => username,
                                   'password' => password}.merge(backup_settings) }
          end
        when /^dir/
          # TODO: add parms
          path = input("\t[dir] enter path to backup", nil)
          unless path
            puts "!! Must enter all values."
          else 
            params << {'directory' => { 'path' => path }.merge(backup_settings)}
          end
        when /^q/
          looop = false
        end
      end
      return params
    end
    
    def write_config_file cmd
      datestamp = Time.now.strftime("%Y_%m_%d-%H_%M_%S")
      type = cmd.keys.first
      case cmd.keys.first
      when 'mysql'
        filename = "mysql-#{cmd[type]['database']}-#{datestamp}.backup"
      when 'directory'
        filename = "directory-#{cmd[type]['path'].gsub(/\/|\\/,"_")}-#{datestamp}.backup"
      end
            
      File.open(filename, 'w') { |f| f.write(BackupToolkit::generate_config(cmd)) }
      return filename
    end

    def send_backup_scripts_to_production
      log "[production] copy configs up"
      # SCP install package to production
    end
  end
end

creator = BackupToolkit::CreateBackupScript.new
creator.run
