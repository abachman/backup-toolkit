#!/usr/bin/env ruby
require 'optparse'
require 'readline'
require 'rubygems'
require 'net/ssh'

OPTIONS = {}# {{{
OptionParser.new do |opts|
  opts.banner = "Usage: generate_backup [options]"

  opts.on("-v", "--verbose", "verbose output") do |v|
    OPTIONS[:verbose] = v
  end
  opts.on("-s", "--server ADDRESS", "set production server address") do |s|
    OPTIONS[:server] = s
  end
  opts.on("-b", "--backup ADDRESS", "set backup server address") do |s|
    OPTIONS[:backup] = s
  end
  targets = [:directory, :mysql]
  target_aliases = { 'dir' => :directory, 'ms' => :mysql }
  opts.on("-t", "--target TARGET", targets, target_aliases, "select backup target type") do |t|
    OPTIONS[:target] = t.to_sym
  end
end.parse!# }}}

# {{{ Global util functions
def log m 
  puts m if OPTIONS[:verbose]
end

def input prompt=nil, default=nil
  puts "#{prompt} [#{default}]" if prompt
  out = Readline::readline('> ').strip
  return out.empty? ? default : out
end# }}}

class Server# {{{
  attr_accessor :address, :username, :password
end# }}}

class MysqlBackupCommand
  attr_accessor :username, :database, :password, :remote_dir
  def initialize
    remote_dir= "~/"
  end
  def command
    "mysql-dump.sh -u #{username} -p #{password} -t#{remote_dir} #{database}"
  end
end

class BackupCommand
  attr_accessor :target
end

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
        log "creating key on remote server"
        ssh.open_channel do |channel|
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
          channel.wait
        end
        ssh.exec! "ls ~/.ssh/*.pub" do |channel, stream, data|
          keys << data if stream == :stdout
        end
      end
      key_choices << keys
    end
    keys = key_choices.split() 
    puts "Which key from production will you use? [0]"
    c = 0
    for key in keys
      puts "\t#{c}.\t#{key}"
      c += 1
    end
    return keys[input.to_i || 0]
  end

  def send_production_keyfile_remote keyfile
    log "adding production keyfile to backup"

    # bring production key down to local machine
    `scp #{@production_server.username}@#{@production_server.address}:#{keyfile} /tmp/production.keyfile`

    # add to backup server
    `cat /tmp/production.keyfile | ssh #{@backup_server.username}@#{@backup_server.address} "mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && cat - >> ~/.ssh/authorized_keys"`

    log "production machine can now log in to backup"
  end# }}}
  
  # {{{ Local Key File actions
  def get_keyfile    
    keys = `ls ~/.ssh/*.pub`.split()
    default = keys.empty? ? nil : keys[0]
    puts "[local] Which key are you uploading? [0]"
    c = 0
    for key in keys
      puts "\t#{c}.\t#{key}"
      c += 1
    end
    return keys[input.to_i || 0]
  end

  def send_local_keyfile addr, user
    kf = get_keyfile
    server = input("[local] To which server?", "#{user}@#{addr}")
    log "[local] Deploying #{kf} to #{server}"
    `cat #{kf} | ssh #{server} "mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && cat - >> ~/.ssh/authorized_keys"`
  end# }}}

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
