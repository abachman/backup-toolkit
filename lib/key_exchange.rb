def retrieve_remote_key remote
  puts "RETRIEVING REMOTE KEY"
  ssh_dir = "/home/#{production_server['username']}/.ssh"
  key_exists = capture("if [ -x #{ ssh_dir }/id_rsa.pub ]; then echo true; else echo false; fi", 
                       :hosts => remote['ssh_address'])
  if key_exists == 'false'
    run "mkdir -p #{ ssh_dir } && chmod 700 #{ ssh_dir }", :hosts => remote['ssh_address']
    # create key with blank passphrase
    run "ssh-keygen -t rsa -q -f #{ ssh_dir }/id_rsa", 
        :hosts => remote['ssh_address'] do |ch, stream, data|
      if stream == :out and /^Enter/ =~ data
        ch.send_data("\r")
      end
    end
  end
  return capture("cat #{ ssh_dir }/id_rsa.pub", :hosts => remote['ssh_address'])
end

namespace :apply_key do
  desc "send your ssh key to production and backup and send production's ssh key to backup"
  task :all do
    puts "If this is your first time logging in to #{production_server['hostname']} or #{backup_server['hostname']} you may have to enter passwords."
    prod_key = retrieve_remote_key(production_server)
    my_key = choose_my_key

    # send my key to production
    _apply_key_to_remote my_key, production_server, 'authorized_keys'

    # send my key to backup
    _apply_key_to_remote my_key, backup_server, 'authorized_keys'

    # send production key to backup
    _apply_key_to_remote prod_key, backup_server, 'authorized_keys'

    # send backup's key to production (known hosts)
    _apply_key_to_remote retrieve_remote_key(backup_server), production_server, 'known_hosts'
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
  
  # add key if it hasn't already been added
  run "if [ -z \"$(grep '#{ key }' #{ ssh_dir }/#{ keyfile })\" ]; then echo \"#{ key }\" >> #{ ssh_dir }/authorized_keys; fi || true", :hosts => remote['ssh_address']
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
  return `cat #{ key }`
end
