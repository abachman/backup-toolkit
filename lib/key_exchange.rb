# In the interest of backup.dreamhost.com compatibility, all :roles => :backup tasks 
# should rely exclusively on sftp and scp.

def retrieve_remote_key remote
  puts "RETRIEVING REMOTE KEY"

  temp_key = ".temp_key_#{ remote['id'] }_#{ rand(5000) }"

  # bring auth_key to local directory
  Net::SFTP.start(remote['hostname'], remote['username'], :auth_methods => ['publickey', 'password'], :password => remote['password']) do |sftp|
    if (sftp.dir.entries(".").map { |e| e.name }).include?('.ssh') && 
       (sftp.dir.entries(".ssh").map { |e| e.name }).include?('id_rsa.pub')
      sftp.download!(".ssh/id_rsa.pub", temp_key)
    else 
      raise "No default public key available at #{ remote['ssh_address'] }, please go create one"
    end
  end

  out = File.new(temp_key).read.chomp
  FileUtils.rm_f temp_key
  return out
end

namespace :keys do
  desc "send your ssh key to node and backup and send node's ssh key to backup"
  task :sync do
    puts "If this is your first time logging in to #{node_server['hostname']} or #{backup_server['hostname']} you may have to enter passwords."
    node_key = retrieve_remote_key(node_server)
    my_key = choose_my_key
    # send my key to node
    _apply_key_to_remote my_key, node_server, 'localhost'
    # send my key to backup
    _apply_key_to_remote my_key, backup_server, 'localhost'
    # send node key to backup
    _apply_key_to_remote node_key, backup_server, node_server['id']
#    # send backup's key to node (known hosts)
#    _apply_key_to_remote retrieve_remote_key(backup_server), node_server, 'known_hosts'
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
    desc "show installed keys on your machine, will probably prompt for your admin password"
    task :local do
      _show_trusted_ssh_keys 'localhost'
    end
    task :all do
      _show_trusted_ssh_keys
    end
  end
end

# used to pass public keys between remote hosts and add them to keyfiles, 
#
# If server A's public key is added to server B's authorized_keys file, 
# server A can login to server B without a password.
#
# If server B's public key is added to server A's known_hosts file, 
# server A won't be prompted to approve the connection to server B.
def _apply_key_to_remote key, remote, source=nil
  temp_auth = ".temp_auth_#{ remote['id'] }_#{ rand(5000) }"

  # bring auth_key to local directory
  Net::SFTP.start(remote['hostname'], remote['username'], :auth_methods => ['publickey', 'password'], :password => remote['password'] ) do |sftp|
    if (sftp.dir.entries(".").map { |e| e.name }).include?('.ssh')
      sftp.download!(".ssh/authorized_keys", temp_auth)
    else 
      sftp.mkdir!(".ssh")
      FileUtils.touch(temp_auth)
    end
  end

  # add key if it hasn't already been added (to local copy of authorized_keys)
  unless File.new(temp_auth).read.include? key
    puts "#{ source }'s key doesn't exist on #{ remote['id'] }, adding..."
    File.open(temp_auth, 'a') { |f| f.write("\n"); f.write(key) }
  else
    puts "#{ source }'s key already exists on #{ remote['id'] }"
  end

  Net::SFTP.start(remote['hostname'], remote['username'], :auth_methods => ['publickey', 'password'], :password => remote['password']) do |sftp|
    sftp.upload!(temp_auth, '.ssh/authorized_keys')
  end

  FileUtils.rm_f temp_auth
end

# select the local public key that will be used.
def choose_my_key          
  keys = `ls ~/.ssh/*.pub`.split()
  if keys.size == 1
    key = keys[0] 
  elsif keys.empty?
    raise "No keys available, please run ssh-keygen, then try again" 
  else 
    puts "[local] Which personal key do you want to deploy? [0]"
    keys.each_with_index { |key, c| puts "\t#{c}.\t#{key}" }
    key = keys[Capistrano::CLI.ui.ask("> ").to_i || 0]
  end
  return `cat #{ key }`.chomp
end

def _show_trusted_ssh_keys remote
  temp_auth = ".temp_auth_#{ remote['id'] }_#{ rand(5000) }"
  temp_known = ".temp_known_#{ remote['id'] }_#{ rand(5000) }"

  # bring files to local directory
  Net::SFTP.start(remote['hostname'], remote['username'], :auth_methods => ['publickey', 'password'], :password => remote['password']) do |sftp|
    entries = sftp.dir.entries(".ssh").map { |e| e.name }
    if entries.include? 'authorized_keys'
      sftp.download!(".ssh/authorized_keys", temp_auth)
    end
    if entries.include? 'known_hosts'
      sftp.download!(".ssh/known_hosts", temp_known)
    end
  end

  if File.exist? temp_auth
    auth_keys = "----------------- Authorized Keys\n" + `cat #{ temp_auth }`
  else 
    auth_keys = "NO AUTHORIZED_KEYS FILE FOUND."
  end

  if File.exist? temp_known
    known_hosts = "----------------- Known Hosts\n" + `cat #{ temp_known }`
  else
    known_hosts = "NO KNOWN_HOSTS FILE FOUND."
  end

  puts "Authorized Keys and Known Hosts file on #{ remote['id'] }"
  puts auth_keys
  puts known_hosts

  FileUtils.rm_f temp_auth
  FileUtils.rm_f temp_known
end

