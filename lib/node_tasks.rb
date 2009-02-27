require 'fileutils'

namespace :node do
  desc "force backup tasks on the selected node to run"
  task :execute, :roles => :node do
    run "#{ node_server['install_directory'] }/backup-runner.rb"
  end

  desc "dump node's run.log file (record of backups)"
  task :log, :roles => :node do
    home = node_server['install_directory']
    run "[ -r #{ home }/backup-log/run.log ] && cat #{ home }/backup-log/run.log"
  end

  desc "list backup jobs on the node"
  task :jobs, :roles => :node do
    templs = []
    home = node_server['install_directory']
    jobs_dir = capture("cat #{ home }/backup-toolkit.conf | grep job | awk '{ print $2 }'").chomp 
    jobs = capture("ls #{jobs_dir}").split() 
    for c in jobs
      _config = capture("cat #{jobs_dir}/#{c}")
      templs << "==== #{ c } ====\n<pre>\n#{ _config }\n</pre>"
    end
    puts templs.join("\n\n")
  end

  desc "Create new mysql or directory backup task"
  task :create_jobs, :roles => :node do
    remote_master_config = ConfigHandler::dump_yaml( capture("cat #{ node_server['install_directory'] }/backup-toolkit.conf") )
    remote_jobs_dir = "#{ node_server['install_directory'] }/backup-jobs"
    unless capture("if [ -e #{remote_jobs_dir} ]; then echo true; fi").chomp == 'true'
      puts "remote jobs directory doesn't seem to exist, please run 'cap dist:install' before running 'cap node:create_task'"
      exit(1)
    end

    params = get_backup_command_params
    params.each do |parm|
      job_file = ConfigHandler::create_temp_config_file(parm)
      puts "copying #{job_file.path} to #{remote_jobs_dir}/#{create_job_name(parm)}"
      upload(job_file.path, "#{remote_jobs_dir}/#{create_job_name(parm)}")
    end
  end
end

def get_backup_command_params
  backup_settings = {
    'backup_destination' => "backups",
    'backup_hostname' => backup_server['hostname'],
    'backup_username' => backup_server['username']
  }
  params = []
  looop = true
  while looop == true 
    case Capistrano::CLI.ui.ask("[node] Which backup command would you like to generate? [mysql|directory] ").downcase
    when /^m/
      database = Capistrano::CLI.ui.ask("[mysql] enter database name:")
      username = Capistrano::CLI.ui.ask("[mysql] enter username:")
      password = Capistrano::CLI.password_prompt("[mysql] enter password:")
      unless database && username && password 
        puts "!! Must enter all values."
      else 
        params << {'mysql' => { 'database' => database,
                               'username' => username,
                               'password' => password}.merge(backup_settings) }
      end
    when /^d/
      path = Capistrano::CLI.ui.ask("[dir] enter path to backup", nil)
      unless path
        puts "!! Must enter all values."
      else 
        params << {'directory' => { 'path' => path }.merge(backup_settings)}
      end
    when /.*/
      puts "done"
      looop = false
    end
  end
  return params
end

def create_job_name params
  type, job = params.clone.shift
  case type
  when 'mysql'
    "mysql-#{ job['database'] }-to-#{ job['backup_hostname'] }.backup"
  when 'directory'
    "directory-#{ job['path'].gsub(/\/|\\/,"_").gsub(/^_/,'') }-to-#{ job['backup_hostname'] }.backup"
  end
end
