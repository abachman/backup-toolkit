def retrieve_remote_key remote
  puts "RETRIEVING REMOTE KEY"
  ssh_dir = "/home/#{node_server['username']}/.ssh"
  key_exists = capture("if [ -r #{ ssh_dir }/id_rsa.pub ]; then echo true; else echo false; fi", 
                       :hosts => remote['ssh_address']).chomp
  if key_exists == 'false'
    puts "Forcing id_rsa.pub creation on #{ remote['ssh_address'] }"
    run "mkdir -p #{ ssh_dir } && chmod 700 #{ ssh_dir }", :hosts => remote['ssh_address']
    # create key with blank passphrase if necessary
    run "yes '\r' | ssh-keygen -t rsa -q -f #{ ssh_dir }/id_rsa", 
        :hosts => remote['ssh_address']    
  end
  return capture("cat #{ ssh_dir }/id_rsa.pub", :hosts => remote['ssh_address']).chomp
end

namespace :keys do
  desc "send your ssh key to node and backup and send node's ssh key to backup"
  task :sync do
    puts "If this is your first time logging in to #{node_server['hostname']} or #{backup_server['hostname']} you may have to enter passwords."
    node_key = retrieve_remote_key(node_server)
    my_key = choose_my_key

    # send my key to node
    _apply_key_to_remote my_key, node_server, 'authorized_keys'

    # send my key to backup
    _apply_key_to_remote my_key, backup_server, 'authorized_keys'

    # send node key to backup
    _apply_key_to_remote node_key, backup_server, 'authorized_keys'

    # send backup's key to node (known hosts)
    puts 'applying backup key to node known_hosts'
    _apply_key_to_remote retrieve_remote_key(backup_server), node_server, 'known_hosts'
  end

  namespace :show do
    desc "show installed keys on node"
    task :node do
      _show_trusted_ssh_keys node_server['ssh_address']
    end
    desc "show installed keys on backup"
    task :backup do
      _show_trusted_ssh_keys backup_server['ssh_address']
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
def _apply_key_to_remote key, remote, keyfile
  ssh_dir = "/home/#{remote['username']}/.ssh"

  # create remote .ssh directory and chmod it to user-only 
  run "mkdir -p #{ ssh_dir } && chmod 700 #{ ssh_dir }", :hosts => remote['ssh_address']

  # make sure keyfile exists
  run "touch #{ ssh_dir }/#{ keyfile }", :hosts => remote['ssh_address']
  
  # add key if it hasn't already been added
  run("if [ -z \"$(grep '#{ key }' #{ ssh_dir }/#{ keyfile })\" ]; then echo \"#{ key }\" >> #{ ssh_dir }/#{ keyfile }; else echo 'already exists on #{ remote['id'] }'; fi || true", 
      :hosts => remote['ssh_address'])
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
  auth_keys = capture("echo '----------------- Authorized Keys' && cat ~/.ssh/authorized_keys", 
                      :hosts => remote)
  known_hosts = capture("echo '----------------- Known Hosts' && cat ~/.ssh/known_hosts",
                        :hosts => remote)
  puts "Authorized Keys and Known Hosts file on #{ remote }"
  puts auth_keys
  puts known_hosts
end
