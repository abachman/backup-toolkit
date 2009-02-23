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
    run "ls #{backup_server['backup_storage']}"
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

