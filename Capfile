#!/usr/bin/env ruby

load 'lib/server_info'
load 'lib/generate_task'
load 'lib/key_exchange'
load 'lib/backup_tasks'

role :node, node_server['ssh_address']
role :backup, backup_server['ssh_address']

namespace :dist do
  task :send_pkg, :roles => :node do
    `tar zcvf dist.tar.gz dist/`
    upload 'dist.tar.gz', "/home/#{node_server['username']}/dist.tar.gz"  
    run "tar xzvf dist.tar.gz"
  end

  task :cleanup, :roles => :node do
    run "rm dist.tar.gz"
    `rm dist.tar.gz`
    run "rm -rf dist/"
  end

  desc "install backup-toolkit on node"
  task :install, :roles => :node do
    send_pkg
    sudo "dist/install.sh #{node_server['username']}"
    run "cat /home/#{node_server['username']}/.backup-log/install.log"
    cleanup
  end

  desc "uninstall backup-toolkit on node"
  task :uninstall, :roles => :node do
    send_pkg
    sudo "dist/uninstall.sh #{node_server['username']}"
    cleanup
  end
end


