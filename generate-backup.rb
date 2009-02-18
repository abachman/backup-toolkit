#!/usr/bin/env ruby
require 'my_utils'
require 'rubygems'
require 'key-exchange'

class Server# {{{
  attr_accessor :address, :username, :password
end# }}}

module BackupToolkit
  class CreateBackupScript
    def initialize
    end

    def run
      get_backup_info
      get_production_info

      # send my key to production and backup
      send_local_keyfile @backup_server.address, @backup_server.username
      send_local_keyfile @production_server.address, @production_server.username

      # send production key to backup
      prod_key = setup_production_keyfile
      send_production_keyfile_remote prod_key

      # add backup scripts to production
      send_backup_scripts_to_production

      # get backup command params
      @backup_params = []
      get_backup_command_params
      for cmd in @backup_params
        puts cmd.command
      end
  #    create_dump_command
    end

    def get_backup_command_params
      looop = true
      while looop == true 
        case input("[production] Which backup command would you like to generate? [mysql|directory]", nil)
        when /my/
          msparms = MysqlBackupCommand.new 
          msparms.database = input("enter database name:", nil)
          msparms.username = input('enter username:', nil)
          msparms.password = input('enter password:', nil)
          unless msparms.database && msparms.username && msparms.password 
            puts "Must enter all values"
          else 
            @backup_params << msparms
          end
        when /dir/
          # TODO: add parms
        else
          looop = false
        end
      end
    end

    # {{{ Get Server Info
    def get_backup_info
      @backup_server = Server.new
      @backup_server.address = input("Which backup server will the script use?", 'backup.dreamhost.com')
      @backup_server.username = input("Which username will the script use?", 'b112819')
      @backup_server.password = input("Which password will the script use?", nil)
    end

    def get_production_info
      @production_server = Server.new
      @production_server.address = input("Which production server will the script run from?", 'gen')
      @production_server.username = input("Which username accesses the production server?", 'adam')
      @production_server.password = input("Which password accesses the production server?", 'adam')
    end# }}}

    def send_backup_scripts_to_production
      log "[production] create ~/bin"
      `ssh #{@production_server.username}@#{@production_server.address} "mkdir -p ~/bin"`
      log "[production] copy scripts up"
      `scp mysql-dump.sh #{@production_server.username}@#{@production_server.address}:~/bin/`
      `scp tar-dump.sh #{@production_server.username}@#{@production_server.address}:~/bin/`
    end
end

creator = CreateBackupScript.new
creator.run
