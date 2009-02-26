require 'fileutils'
require 'tempfile'
require 'yaml'

require 'rubygems'
require 'net/ssh'

module ConfigHandler
  LOCAL_CONFIG_DIRECTORY = File.join(File.dirname(__FILE__), '..', 'config')

  BACKUP_CONFIG_SAMPLE = <<-EOS
  type: backup
  id: red5-VM
  hostname: 192.168.1.28
  username: red5server
  backup_storage: /home/red5server/backups
  EOS

  NODE_CONFIG_SAMPLE = <<-EOS
  type: node
  id: ubuntu-general-VM
  hostname: 192.168.1.31
  username: adam
  EOS

  CONNECTIONS_CONFIG_SAMPLE = <<-EOS
  type: connections
  id: central-connection-repository
  hostname: 192.168.1.31
  username: adam
  config_directory: connections
  EOS

  def self.load_yaml_file file
    File.open(file) { |yf| YAML::load( yf ) }
  end

  def self.load_yaml str
    YAML::load( str )
  end

  def self.sample_configs; 
    "==== Sample Backup Config File \n#{ BACKUP_CONFIG_SAMPLE } \n\n"\
    "==== Sample Node Config File \n#{ NODE_CONFIG_SAMPLE } \n\n"\
    "==== Sample Connections Config File \n#{ CONNECTIONS_CONFIG_SAMPLE }"
  end

  def self.validate_config conf
    return (conf['type'] and conf['id'] and conf['hostname'] and conf['username'])
  end

  def self.all_servers
    @@all_servers ||= load_all_configs
  end

  # Check local ./config directory for connection .yml files
  def self.load_all_configs
    _servers = {} 
    conf_dir = LOCAL_CONFIG_DIRECTORY
    for file in Dir.new(conf_dir).select { |f| /^.*\.yml$/ =~ f }
      config_file = File.join(conf_dir, file)
      config = load_yaml_file(config_file)
      if validate_config(config)
        _servers[config['id']] = config 
      else
        puts "Invalid configuration found: "
        puts "==== #{ config_file }"
        puts File.new(config_file).read
        puts
        puts "Compare to: \n #{ sample_configs }"
      end
    end
    return _servers.merge( load_remote_configs(_servers) )
  end

  # Check remote configuration server for connection .yml files (nodes and backups)
  def self.load_remote_configs servs
    configs = {}
    ((servs.select { |id, c| c['type'] == 'connections' }).map { |s| s.last }).each do |conf|
      Net::SSH.start(conf['hostname'], conf['username'], :auth_methods => ['publickey']) do |ssh|
        config_files = ssh.exec!("[ -e #{ conf['config_directory'] } ] && ls #{ conf['config_directory'] }").chomp
        for conf_file in config_files
          config_text = ssh.exec!("cat #{ conf['config_directory'] }/#{ conf_file }")
          config = load_yaml(config_text)
          if validate_config(config)
            configs[config['id']] = config
          else
            puts "Invalid configuration found in repo "\
              "(#{ conf['username'] }@#{ conf['hostname'] }:~/#{ conf['config_directory'] }): "
            puts "==== #{ conf_file }"
            puts config_text
            puts
            puts "Compare to: \n #{ sample_configs }"
          end
        end
      end
    end
    return configs
  end

  def self.all_nodes; @@all_nodes ||= get_nodes; end
  def self.all_backups; @@all_backups ||= get_backups; end
  def self.all_connections; @@all_connections ||= get_connections; end

  def self.get_nodes
    if ENV['BT_NODE'] && all_servers[ENV['BT_NODE']]
      puts "Using #{ ENV['BT_NODE'] } node config"
      return [ all_servers[ENV['BT_NODE']] ]
    else
      res = all_servers.select { |id, conf| conf['type'] == 'node' }
    end
    return (res.class == {}.class ? res : res.map {|c| c.last})
  end

  def self.get_backups
    if ENV['BT_BACKUP'] && all_servers[ENV['BT_BACKUP']]
      puts "Using #{ ENV['BT_BACKUP'] } node config"
      return [ all_servers[ENV['BT_BACKUP']] ]
    else
      res = all_servers.select { |id, conf| conf['type'] == 'backup' }
    end
    return (res.class == {}.class ? res : res.map {|c| c.last})
  end

  def self.get_connections
    return (all_servers.select { |id, c| c['type'] == 'connections' }).map {|c| c.last}
  end

  def self.create_temp_config_file config_hash
    temp = Tempfile.new('configfile')
    temp.write(YAML::dump( config_hash )); temp.close
    return temp
  end

  def self.create_new_config config_hash
    tempfile = create_temp_config_file config_hash
    filename = "#{ config_hash['username'] }-#{ config_hash['hostname'] }-#{ config_hash['type'] }.yml"
    begin 
      remote = all_connections.first
      Net::SFTP.start(remote['hostname'], remote['username'], :auth_methods => ['publickey']) do |sftp|
        sftp.upload!(tempfile.path, "#{ remote['config_directory'] }/#{ filename }")
      end
      puts "config saved to #{ remote['hostname'] }:#{ remote['config_directory'] }/#{ filename }"
    rescue 
      FileUtils.mv(tempfile.path, File.join(LOCAL_CONFIG_DIRECTORY, filename))
      raise
    end
  end
end
