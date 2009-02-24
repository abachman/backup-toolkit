
set(:backup_server) do
  _get_server_info('backup')
end

set(:node_server) do
  _get_server_info('node')
end

set(:all_servers) do
  _load_all_configs 
end

def _load_yaml_file file
  File.open(file) { |yf| YAML::load( yf ) }
end

backup_config_sample = <<-EOS
# Example backup configuration (note the entry for backup_storage)

type: backup
id: red5-VM
hostname: 192.168.1.28
username: red5server
backup_storage: /home/red5server/backups
EOS

node_config_sample = <<-EOS
# Example node configuration

type: node
id: ubuntu-general-VM
hostname: 192.168.1.31
username: adam
EOS

def sample_configs; "#{ backup_config_sample } \n\n#{ node_config_sample }"; end

def _validate_config conf
  return (conf['type'] and conf['id'] and conf['hostname'] and conf['username'])
end

def _load_all_configs
  servers = {} 
  conf_dir = File.join(File.dirname(__FILE__), '..', 'config')
  for file in Dir.new(conf_dir).select { |f| /^.*\.yml$/ =~ f }
    config = _load_yaml_file(File.join(conf_dir, file))
    if _validate_config(config)
      servers[config['id']] = config 
    else
      puts "Invalid configuration found: #{ File.join(conf_dir, file) }"
      puts "Compare to: \n #{ sample_configs }"
    end
  end
  return servers
end

def get_nodes
  if ENV['BT_NODE'] && all_servers[ENV['BT_NODE']]
    puts "Using #{ ENV['BT_NODE'] } node config"
    return [ all_servers[ENV['BT_NODE']] ]
  else
    res = all_servers.select { |id, conf| conf['type'] == 'node' }
  end
  return (res.class == {}.class ? res : res.map(&:last))
end

def get_backups
  if ENV['BT_BACKUP'] && all_servers[ENV['BT_BACKUP']]
    puts "Using #{ ENV['BT_BACKUP'] } node config"
    return [ all_servers[ENV['BT_BACKUP']] ]
  else
    res = all_servers.select { |id, conf| conf['type'] == 'backup' }
  end
  return (res.class == {}.class ? res : res.map(&:last))
end

def _get_server_info env
  conf_choices = env == 'backup' ? get_backups : get_nodes
  if conf_choices.size == 1
    opts = conf_choices[0]
  else
    puts "choose a configuration for #{env}: [0]"
    conf_choices.each_with_index do |id, n|
      puts " [#{n}] #{ id['id'] } "
    end
   
    confirm = Capistrano::CLI.ui.ask("> ")
    if confirm.empty? or confirm.to_i > conf_choices.size - 1
      opts = conf_choices[0]
    else 
      opts = conf_choices[confirm.to_i]
    end
  end

  opts['ssh_address'] = "#{opts['username']}@#{opts['hostname']}" if (opts['username'] && opts['hostname'])
  opts['password'] = Capistrano::CLI.password_prompt("#{ opts['ssh_address'] } password: ").chomp
  opts['password'] = nil if opts['password'].empty?
  opts || raise("no #{env} config available, add #{env}.yml to config directory. #{ sample_configs }")
end

namespace "configuration" do
  task "check" do
    all_servers.keys.each do |server|
      puts "#{ server }: #{ all_servers[server].inspect }"
    end
  end
end
