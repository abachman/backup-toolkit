desc "run ssh-keygen on production"
task :create_remote_key, :roles => :production do
  ssh_dir = "/home/#{production_server['username']}/.ssh"
  begin
    run "ls #{ssh_dir}/id_rsa.pub"
  rescue 
    run "mkdir -p #{ ssh_dir } && chmod 700 #{ ssh_dir }"
    # create key with blank passphrase
    run "yes \"\r\" | ssh-keygen -t rsa -q -f #{ ssh_dir }/id_rsa"
  end
  out = nil
  run "cat #{ ssh_dir }/id_rsa.pub" do |ch, stream, data|
    out = data if stream == :out
  end
  out
end

namespace :apply_key do
  task :_apply_key_to_production, :roles => :production do
    ssh_dir = "/home/#{remote['username']}/.ssh"
    # create remote .ssh directory
    run "mkdir -p #{ ssh_dir } && chmod 700 #{ ssh_dir }"
    
    # add key if it hasn't already been added
    begin 
      run "ls #{ ssh_dir }/authorized_keys"
      run "if [ -z \"$(grep '#{ key }' #{ ssh_dir }/authorized_keys)\" ]; then echo \"#{ key }\" >> #{ ssh_dir }/authorized_keys; fi"
    rescue
      run "echo \"#{ key }\" >> #{ ssh_dir }/authorized_keys"
    end
  end

  task :_apply_key_to_backup, :roles => :backup do
    ssh_dir = "/home/#{remote['username']}/.ssh"
    # create remote .ssh directory
    run "mkdir -p #{ ssh_dir } && chmod 700 #{ ssh_dir }"
    
    # add key if it hasn't already been added
    begin 
      run "ls #{ ssh_dir }/authorized_keys"
      run "if [ -z \"$(grep '#{ key }' #{ ssh_dir }/authorized_keys)\" ]; then echo \"#{ key }\" >> #{ ssh_dir }/authorized_keys; fi"
    rescue
      run "echo \"#{ key }\" >> #{ ssh_dir }/authorized_keys"
    end
  end
  
  desc "send your ssh key to production and backup and send production's ssh key to backup"
  task :all do
    puts "If this is your first time logging in to #{production_server['hostname']} or #{backup_server['hostname']} you may have to enter passwords."
    prod_key = create_remote_key.chomp
    my_key = `cat #{ choose_my_key }`.chomp

    # send my key to production
    set :key, my_key
    set :remote, production_server
    _apply_key_to_production

    # send my key to backup
    unset :remote
    set :remote, backup_server 
    _apply_key_to_backup  

    # send production key to backup
    unset :key
    set :key, prod_key
    _apply_key_to_backup
  end
end

# {{{ Local Key File actions
def choose_my_key          
  keys = `ls ~/.ssh/*.pub`.split()
  return keys[0] if keys.size == 1

  default = keys.empty? ? nil : keys[0]
  puts "[local] Which personal key do you want to deploy? [0]"
  c = 0
  for key in keys
    puts "\t#{c}.\t#{key}"
    c += 1
  end
  return keys[Capistrano::CLI.ui.ask("> ").to_i || 0]
end
