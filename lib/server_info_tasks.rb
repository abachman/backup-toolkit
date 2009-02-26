
set(:backup_server) do
  _get_server_info('backup')
end

set(:node_server) do
  _get_server_info('node')
end

set(:adhoc_server) do
  _get_server_info('adhoc')
end

set(:all_servers) do
  ConfigHandler::all_servers
end

set(:all_nodes) do
  ConfigHandler::all_nodes
end

def _get_server_info env
  opts = {}
  case env
  when /backup|node/
    conf_choices = env == 'backup' ? ConfigHandler::all_backups : ConfigHandler::all_nodes
    if conf_choices.size == 1
      opts = conf_choices[0]
    else
      puts "choose a configuration for #{env}: [0]"
      conf_choices.each_with_index do |conf, n|
        puts " [#{n}] #{ conf['id'] } (#{ conf['username'] }@#{ conf['hostname'] })"
      end
     
      confirm = Capistrano::CLI.ui.ask("> ")
      if confirm.empty? or confirm.to_i > conf_choices.size - 1
        opts = conf_choices[0]
      else 
        opts = conf_choices[confirm.to_i]
      end
    end
  when /adhoc/
    opts['hostname'] = Capistrano::CLI.ui.ask("target hostname: ")
    opts['username'] = Capistrano::CLI.ui.ask("target username: ")
    opts['id'] = "adhoc server #{opts['username']}@#{opts['hostname']}"
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
