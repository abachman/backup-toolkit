require 'fileutils'
require 'tempfile'
require 'yaml'

module ConfigHandler
  BACKUP_CONFIG_SAMPLE = <<-EOS
  # Example backup configuration (note the entry for backup_storage)

  type: backup
  id: red5-VM
  hostname: 192.168.1.28
  username: red5server
  backup_storage: /home/red5server/backups
  EOS

  NODE_CONFIG_SAMPLE = <<-EOS
  # Example node configuration

  type: node
  id: ubuntu-general-VM
  hostname: 192.168.1.31
  username: adam
  EOS


  def self.load_yaml_file file
    File.open(file) { |yf| YAML::load( yf ) }
  end

  def self.load_yaml str
    YAML::load( str )
  end

  def self.sample_configs; "#{ BACKUP_CONFIG_SAMPLE } \n\n#{ NODE_CONFIG_SAMPLE }"; end

  def self.validate_config conf
    return (conf['type'] and conf['id'] and conf['hostname'] and conf['username'])
  end

  def self.all_servers
    @@all_servers ||= load_all_configs
  end

  def self.load_all_configs
    _servers = {} 
    conf_dir = File.join(File.dirname(__FILE__), '..', 'config')
    for file in Dir.new(conf_dir).select { |f| /^.*\.yml$/ =~ f }
      config = load_yaml_file(File.join(conf_dir, file))
      if validate_config(config)
        _servers[config['id']] = config 
      else
        puts "Invalid configuration found: #{ File.join(conf_dir, file) }"
        puts "Compare to: \n #{ sample_configs }"
      end
    end
    return _servers
  end

  def self.all_nodes; @@all_nodes ||= get_nodes; end
  def self.all_backups; @@all_backups ||= get_backups; end

  def self.get_nodes
    if ENV['BT_NODE'] && all_servers[ENV['BT_NODE']]
      puts "Using #{ ENV['BT_NODE'] } node config"
      return [ all_servers[ENV['BT_NODE']] ]
    else
      res = all_servers.select { |id, conf| conf['type'] == 'node' }
    end
    return (res.class == {}.class ? res : res.map(&:last))
  end

  def self.get_backups
    if ENV['BT_BACKUP'] && all_servers[ENV['BT_BACKUP']]
      puts "Using #{ ENV['BT_BACKUP'] } node config"
      return [ all_servers[ENV['BT_BACKUP']] ]
    else
      res = all_servers.select { |id, conf| conf['type'] == 'backup' }
    end
    return (res.class == {}.class ? res : res.map(&:last))
  end

  def self.create_temp_config_file config_hash
    temp = Tempfile.new('configfile')
    temp.write(YAML::dump( config_hash )); temp.close
    return temp
  end
end
