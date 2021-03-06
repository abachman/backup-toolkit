# In the interest of backup.dreamhost.com compatibility, all :roles => :backup tasks 
# should rely exclusively on sftp and scp.

require 'tempfile'

def retrieve_remote_key remote
  out = Tempfile.new('remote_key')
  # bring auth_key to local directory
  Net::SFTP.start(remote['hostname'], remote['username'], :auth_methods => ['publickey', 'password'], :password => remote['password']) do |sftp|
    if (sftp.dir.entries(".").map { |e| e.name }).include?('.ssh') && 
       (sftp.dir.entries(".ssh").map { |e| e.name }).include?('id_rsa.pub')
      sftp.download!(".ssh/id_rsa.pub", out.path) 
    else 
      raise "No default public key available at #{ remote['ssh_address'] }, please go create one"
    end
  end
  return out.read.chomp
end

namespace :keys do
  desc "send your key to a remote server (adhoc)"
  task :add do
    my_key = choose_keyfile
    _apply_key_to_remote my_key, adhoc_server, 'localhost'
  end

  desc "setup ssh keys for backup-toolkit"
  namespace :sync do
    desc "node's ssh key to backup"
    task :remote do
      node_key = retrieve_remote_key(node_server)   
      _apply_key_to_remote node_key, backup_server, node_server['id']
    end

    desc "send your ssh key to node and backup"
    task :local do
      my_key = choose_my_key
      # send my key to node
      _apply_key_to_remote my_key, node_server, 'localhost'
      # send my key to backup
      _apply_key_to_remote my_key, backup_server, 'localhost'
    end

    desc "keys:sync:local && keys:sync:remote"
    task :default do
      local
      remote
    end
  end

  namespace :show do
    desc "show installed keys on node"
    task :node do
      _show_trusted_ssh_keys node_server
    end
    desc "show installed keys on backup"
    task :backup do
      _show_trusted_ssh_keys backup_server
    end
    desc "show installed keys on your machine"
    task :local do
      _show_trusted_ssh_keys 'localhost'
    end
  end
end

# used to pass public keys between remote hosts and add them to keyfiles, 
#
# If server A's public key is added to server B's authorized_keys file, 
# server A can login to server B without a password.
#
# remote has keys: 'hostname', 'username', 'password'
def _apply_key_to_remote key, remote, source=nil
  temp_auth = Tempfile.new('auth')

  # bring auth_key to local directory
  Net::SFTP.start(remote['hostname'], remote['username'], :auth_methods => ['publickey', 'password'], :password => remote['password'] ) do |sftp|
    if (sftp.dir.entries(".").map {|f| f.name}).include?('.ssh')
      if (sftp.dir.entries(".ssh").map {|f| f.name}).include?('authorized_keys')
        sftp.download!(".ssh/authorized_keys", temp_auth.path)
      end
    else 
      sftp.mkdir!(".ssh")
    end
  end

  # add key if it hasn't already been added (to local copy of authorized_keys)
  unless temp_auth.read.include? key
    puts "#{ source }'s key doesn't exist on #{ remote['id'] }, adding..."
    temp_auth.write("\n" + key + "\n")
    temp_auth.close

    Net::SFTP.start(remote['hostname'], remote['username'], :auth_methods => ['publickey', 'password'], :password => remote['password']) do |sftp|
      sftp.upload!(temp_auth.path, '.ssh/authorized_keys')
    end
  else
    puts "#{ source }'s key already exists on #{ remote['id'] }"
  end
end

# select the local public key that will be used.
def choose_my_key          
  keys = `ls ~/.ssh/*.pub`.split()
  if keys.size == 1
    key = keys[0] 
  elsif keys.empty?
    raise "No keys available, please run ssh-keygen, then try again" 
  else 
    puts "[local] Which personal key do you want to deploy?"
    keys.each_with_index { |key, c| puts "\t#{c}.\t#{key}" }
    choice = Capistrano::CLI.ui.ask("> ") { |q| q.default = 0; q.answer_type = Integer }
    key = keys[choice]
  end
  return File.new(key).read.chomp
end

def choose_keyfile
  keys = `ls ~/.ssh/*.pub`.split()
  keyfile = Capistrano::CLI.ui.ask("enter /path/to/local/keyfile: ") do |q|
    q.default = keys[0] if keys.size > 0
    q.validate = lambda { |fname| File.exist? fname }
    q.responses[:not_valid] = "Keyfile doesn't exist, please try again."
  end
  return File.new(keyfile).read.chomp
end

def _show_trusted_ssh_keys remote
  temp_auth = Tempfile.new('auth')
  temp_known = Tempfile.new('known')

  # bring files to local directory
  Net::SFTP.start(remote['hostname'], remote['username'], :auth_methods => ['publickey', 'password'], :password => remote['password']) do |sftp|
    entries = sftp.dir.entries(".ssh").map { |e| e.name }
    if entries.include? 'authorized_keys'
      sftp.download!(".ssh/authorized_keys", temp_auth.path)
    end
    if entries.include? 'known_hosts'
      sftp.download!(".ssh/known_hosts", temp_known.path)
    end
  end

  puts "Authorized Keys and Known Hosts file on #{ remote['id'] }"
  puts "----------------- Authorized Keys\n" + temp_auth.read
  puts "----------------- Known Hosts\n" + temp_known.read
  
  temp_auth.close true
  temp_known.close true
end

