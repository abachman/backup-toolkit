#!/usr/bin/env ruby

require 'lib/confighandler'

load 'lib/server_info_tasks'
load 'lib/key_exchange_tasks'
load 'lib/backup_tasks'
load 'lib/node_tasks'
load 'lib/connection_tasks'

set :auth_methods, %w( publickey password )

role :node do
  node_server['ssh_address']
end

role :backup do 
  backup_server['ssh_address']
end

before "dist:install", "dist:send_pkg"
after "dist:install", "dist:cleanup"

before "dist:uninstall", "dist:send_pkg"
after "dist:uninstall", "dist:cleanup"

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
    r_h = sprintf "%02i", (rand(4) + 1)
    r_m = sprintf "%02i", rand(60)
    run_time = Capistrano::CLI.ui.ask("what time would you like to run backups (hh:mm)? [#{ r_h }:#{ r_m }] ")
    run_time = (run_time.chomp.empty? || run_time.count(':') != 1) ? "#{r_h}:#{r_m}" : run_time.chomp
    sudo "dist/install.sh #{node_server['username']} #{ run_time.split(':')[0] } #{ run_time.split(':')[1] }"
    run "cat /home/#{node_server['username']}/.backup-log/install.log"
  end

  desc "uninstall backup-toolkit on node"
  task :uninstall, :roles => :node do
    sudo "dist/uninstall.sh #{node_server['username']}"
  end
end

task :invoke do

end

task :shell do

end

