require 'fileutils'

config_report = <<-EOS
==== $filename ====

<pre>
$conf
</pre>
EOS

def templatize template, namespace
  for k in namespace.keys
    template = template.gsub(/\$#{k}/, namespace[k])
  end
  template
end

namespace :node do
  desc "force backup tasks on the selected node to run"
  task :execute, :roles => :node do
    run "backup-runner"
  end

  desc "dump node's run.log file (record of backups)"
  task :log, :roles => :node do
    run "[ -r /home/#{ node_server['username'] }/.backup-log/run.log ] && cat /home/#{ node_server['username'] }/.backup-log/run.log"
  end

  desc "list backup jobs on the node"
  task :jobs, :roles => :node do
    confs_dir = nil
    confs = []
    templs = []
    run "cat /etc/backup-toolkit.conf | grep conf | awk '{ print $2 }'" do |ch, stream, data|
      confs_dir = data.chomp
    end
    run "ls #{confs_dir}" do |ch, stream, data|
      confs = data.split()
    end
    for c in confs
      run "cat #{confs_dir}/#{c}" do |ch, s, data|
        templs << templatize(config_report, { 'filename' => c, 'conf' => data })
      end
    end
    puts templs.join("\n\n")
  end

  desc "Create new mysql or directory backup task"
  task :create_task, :roles => :node do
    remote_config_dir = "/home/#{node_server['username']}/.backup-config"
    unless capture("if [ -e #{remote_config_dir} ]; then echo true; fi").chomp == 'true'
      puts "remote config directory doesn't seem to exist, please run 'cap dist:install' before running 'cap node:create_task'"
      exit(1)
    end

    parms = get_backup_command_params
    config_file = ConfigHandler::create_temp_config_file(parms)
    upload(config_file.path, "#{remote_config_dir}/#{create_config_name(parms)}")
  end
end

def get_backup_command_params
  backup_settings = {
    'backup_destination' => "backups",
    'backup_hostname' => backup_server['hostname'],
    'backup_username' => backup_server['username']
  }
  looop = true
  while looop == true 
    case Capistrano::CLI.ui.ask("[node] Which backup command would you like to generate? [mysql|directory] ").downcase
    when /^my/
      database = Capistrano::CLI.ui.ask("[mysql] enter database name:")
      username = Capistrano::CLI.ui.ask("[mysql] enter username:")
      password = Capistrano::CLI.password_prompt("[mysql] enter password:")
      unless database && username && password 
        puts "!! Must enter all values."
      else 
        params = {'mysql' => { 'database' => database,
                               'username' => username,
                               'password' => password}.merge(backup_settings) }
        looop = false
      end
    when /^dir/
      path = Capistrano::CLI.ui.ask("[dir] enter path to backup", nil)
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
    "mysql-#{ params[type]['database'] }-to-#{ params[type]['backup_hostname'] }.backup"
  when 'directory'
    "directory-#{ params[type]['path'].gsub(/\/|\\/,"_").gsub(/^_/,'') }-to-#{ params[type]['backup_hostname'] }.backup"
  end
end
