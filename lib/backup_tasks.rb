require 'erb'

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

namespace :backup do
  desc "force backup tasks on the selected node to run"
  task :execute, :roles => :node do
    run "backup-runner"
  end

  desc "list backup files on the backup server"
  task :list, :roles => :backup do
    run "ls -sh1 #{backup_server['backup_storage']}"
  end

  desc "dump a given backup package"
  task :dump, :roles => :backup do 
    if ENV['BACKUP_FILE'] 
      fname = "#{ backup_server['backup_storage'] }/#{ ENV['BACKUP_FILE'] }"
      if /\.tar\.gz/ =~ fname
        run "[ -r #{ fname } ] && tar tf #{ fname } || echo 'error opening file'"
      elsif /\.sql\.gz/ =~ fname
        run "[ -r #{ fname } ] && zcat #{ fname } || echo 'error opening file'"
      else
        run "echo \"unknown filetype, can't access\""
      end
    else
      puts "No backup file specified. Run backup:list to get filenames and then run this"
      puts "command again with the BACKUP_FILE=filename specified."
    end
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
end

