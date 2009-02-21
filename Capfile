#!/usr/bin/env ruby

load 'lib/server_info'
load 'lib/generate_task'
load 'lib/key_exchange'
load 'lib/backup_tasks'

role :production, production_server['ssh_address']
role :backup, backup_server['ssh_address']

namespace :dist do
  task :send_pkg, :roles => :production do
    `tar zcvf dist.tar.gz dist/`
    upload 'dist.tar.gz', "/home/#{production_server['username']}/dist.tar.gz"  
    run "tar xzvf dist.tar.gz"
  end

  task :cleanup, :roles => :production do
    run "rm dist.tar.gz"
    `rm dist.tar.gz`
    run "rm -rf dist/"
  end

  desc "install backup-toolkit on remote production server"
  task :install, :roles => :production do
    send_pkg
    sudo "dist/install.sh #{production_server['username']}"
    run "cat /home/#{production_server['username']}/.backup-log/install.log"
    cleanup
  end

  desc "uninstall backup-toolkit on remote production server"
  task :uninstall, :roles => :production do
    send_pkg
    sudo "dist/uninstall.sh #{production_server['username']}"
    cleanup
  end
end


