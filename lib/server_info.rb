
set(:backup_server) do
  _get_server_info 'backup'
end

set(:production_server) do
  _get_server_info 'production'
end

def _get_conf_yaml conf_dir, file
  File.open(File.join(conf_dir, file)) { |yf| YAML::load( yf ) }
end

def _get_server_info env
  opts = nil
  conf_dir = File.join(File.dirname(__FILE__), '..', 'config')
  confs = `ls #{conf_dir} | grep #{env}`.split().each { |f| f.chomp }
  if confs.size == 1 
    opts = _get_conf_yaml(conf_dir, confs.first)
  else 
    conf_files = []
    for file in Dir.new(conf_dir)
      conf_files << file
    end
    puts "choose a config file for #{env}: [0]"
    conf_files.each_with_index do |file, n|
      puts " [#{n}] #{file} "
    end

    confirm = Capistrano::CLI.ui.ask("> ")
    if confirm.empty? or confirm.to_i > conf_files.size - 1
      opts = _get_conf_yaml(conf_dir, conf_files[0])
    else 
      opts = _get_conf_yaml(conf_dir, conf_files[confirm.to_i])
    end
  end
  opts['ssh_address'] = "#{opts['username']}@#{opts['hostname']}" if (opts['username'] && opts['hostname'])
  opts || raise("no #{env} config available, add #{env}.[hostname].yml to config directory")
end
