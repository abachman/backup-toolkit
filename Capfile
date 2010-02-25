#!/usr/bin/env ruby

require 'lib/confighandler'

load 'lib/server_info_tasks'
load 'lib/key_exchange_tasks'
load 'lib/backup_tasks'
load 'lib/node_tasks'
load 'lib/connection_tasks'
load 'lib/audit_tasks'

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
    upload 'dist.tar.gz', "dist.tar.gz"  
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
    unless node_server['install_directory']
      installdir = Capistrano::CLI.ui.ask("what is the remote install directory? ") {|q| q.default = '~/backup-toolkit'}
    else 
      installdir = node_server['install_directory']
    end
    run_time = Capistrano::CLI.ui.ask("what time would you like to run backups (hh:mm)? [#{ r_h }:#{ r_m }] ")
    run_time = (run_time.chomp.empty? || run_time.count(':') != 1) ? "#{r_h}:#{r_m}" : run_time.chomp
    run "dist/install.sh -h#{ run_time.split(':')[0] } -m#{ run_time.split(':')[1] } #{ installdir }", :verbose => Logger::DEBUG
  end

  desc "update the core backup-toolkit scripts on node"
  task :update, :roles => :node do
    installdir = node_server['install_directory']
    %w(backup-runner.rb mysql-dump.sh setup-ssh.sh tar-dump.sh).each do |file|
      upload "dist/#{file}", "#{installdir}/#{file}"
    end
  end

  desc "uninstall backup-toolkit on node"
  task :uninstall, :roles => :node do
    run "dist/uninstall.sh #{ node_server['install_directory'] }"
  end
end

desc "deploy backup-toolkit to a remote server"
task :deploy do
  confirm = Capistrano::CLI.ui.ask("create new node connection? {Y|n}") {|q| q.default = "yes"} .downcase
  connection.node.create if /[Yy]/ =~ confirm
  confirm = Capistrano::CLI.ui.ask("create new backup connection? {y|N}") {|q| q.default = "no"} .downcase
  connection.backup.create if /[Yy]/ =~ confirm
  keys.sync.default
  dist.install
  node.create_jobs
  node.jobs
end

task :invoke do

end

task :shell do

end


