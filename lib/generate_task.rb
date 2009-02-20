require 'fileutils'

namespace :backup do
  desc "Create new mysql or directory backup task"
  task :create, :roles => :production do
    remote_config_dir = "/home/#{production_server['username']}/.backup-config"
    begin
      run("ls #{remote_config_dir}")
      puts "remote config directory exists"
    rescue 
      puts "remote config directory doesn't exist, please run 'cap dist:install' before running 'cap backup:create'"
      exit (1)
    end

    parms = get_backup_command_params 
    config_yaml = YAML::dump( parms )
    config_file = File.join("tmp", create_config_name(parms))
    FileUtils.mkdir_p 'tmp' unless File.exist?('tmp')
    File.open(config_file, 'w') { |f| f.write(config_yaml) }
    upload config_file, "#{remote_config_dir}/#{create_config_name(parms)}"
    FileUtils.rm_rf 'tmp'
  end
end

def get_backup_command_params
  backup_settings = {
    'backup_destination' => "/home/#{backup_server['username']}/backups",
    'backup_hostname' => backup_server['hostname'],
    'backup_username' => backup_server['username']
  }
  looop = true
  while looop == true 
    case Capistrano::CLI.ui.ask("[production] Which backup command would you like to generate? [mysql|directory] ").downcase
    when /^my/
      database = Capistrano::CLI.ui.ask("\t[mysql] enter database name:")
      username = Capistrano::CLI.ui.ask("\t[mysql] enter username:")
      password = Capistrano::CLI.ui.ask("\t[mysql] enter password:")
      unless database && username && password 
        puts "!! Must enter all values."
      else 
        params = {'mysql' => { 'database' => database,
                               'username' => username,
                               'password' => password}.merge(backup_settings) }
        looop = false
      end
    when /^dir/
      path = Capistrano::CLI.ui.ask("\t[dir] enter path to backup", nil)
      unless path
        puts "!! Must enter all values."
      else 
        params = {'directory' => { 'path' => path }.merge(backup_settings)}
        looop = false
      end
    when /^q/
      puts "Cancelling"
      exit(0)
    end
  end
  return params
end

def create_config_name params
  type = params.keys.first
  case params.keys.first
  when 'mysql'
    "mysql-#{params[type]['database']}.backup"
  when 'directory'
    "directory-#{params[type]['path'].gsub(/\/|\\/,"_").gsub(/^_/,'')}.backup"
  end
end
