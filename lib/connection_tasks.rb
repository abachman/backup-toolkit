# ConfigHandler

desc "create new connection config files"
namespace :connection do
  task :create do
    type = Capistrano::CLI.ui.ask("Which type of connection would you like to create (backup|node) ? ") do |q| 
      q.default = 'node'
    end
    case type
    when /no/
      node.create
    when /ba/
      backup.create
    end
  end

  task :list do
    all_servers.each_pair do |id, config|
      puts "==== #{ id } ===="
      puts "    " + ConfigHandler::dump_yaml( config ).split("\n").join("\n    ")
      puts 
    end
  end

  desc "create node connection"
  namespace :node do
    task :create do
      # create node connection config file.
      config = { 'type' => 'node' }.merge( _get_prelims('node') )
      config['install_directory'] = 
        Capistrano::CLI.ui.ask("[configure node] home directory on node") do |q|
          q.default = "~/backup-toolkit"
        end
      config['ssh_address'] = "#{ config['username'] }@#{ config['hostname'] }"
      if _validate_connection(config) 
        # Resolve installation directory
        if /~/ =~ config['install_directory']
          puts 'resolving install directory on remote server'
          inst = config['install_directory']
          rinst = capture("mkdir -p #{inst} && cd #{inst} && pwd" , :hosts => config['ssh_address'], :auth_methods => ['password']).chomp
          config['install_directory'] = rinst
        end
        ConfigHandler::create_new_connection_config(config)
                set :node, config['ssh_address']
        set :node_server, config
      else
        puts 'invalid connection, skipping...'
      end
    end
  end

  desc "create backup connection"
  namespace :backup do
    task :create do
      # create node connection config file.
      config = { 
        'type' => 'backup',
      }.merge( _get_prelims('backup') )
      config['backup_storage'] = Capistrano::CLI.ui.ask("[configure backup] storage directory on backup server (relative to ~/): ")
      if _validate_connection(config) 
        ConfigHandler::create_new_connection_config(config)
        set :backup, "#{ config['username'] }@#{ config['hostname'] }"
        set :backup_server, config
      else
        puts 'invalid connection, skipping...'
      end
    end
  end
end

def _get_prelims mode
  id = Capistrano::CLI.ui.ask("[configure #{mode}] id (used to identify the connection): ") { |q| q.answer_type = String; q.whitespace = :chomp_and_collapse }
  id = id.chomp.downcase.gsub(/ /, '-').gsub(/[^a-z-]/,'')
  hostname = Capistrano::CLI.ui.ask("[configure #{mode}] hostname: ") { |q| q.answer_type = String; q.whitespace = :chomp }
  username = Capistrano::CLI.ui.ask("[configure #{mode}] username: ") { |q| q.answer_type = String; q.whitespace = :chomp }
  {
    'id' => id,
    'hostname' => hostname,
    'username' => username
  }
end

def _validate_connection conn
  !(%w( id hostname username ).any? { |key| conn[key].strip.empty? })
end
