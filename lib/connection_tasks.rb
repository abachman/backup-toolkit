# ConfigHandler

desc "create new connection config files"
namespace :connection do
  task :create do
    type = Capistrano::CLI.ui.ask("Which type of connection would you like to create (backup|node) ? ") do |q| 
      q.default = 'node'
    end
    case type
    when /no/
      node.create
    when /ba/
      backup.create
    end
  end

  desc "create node connection"
  namespace :node do
    task :create do
      # create node connection config file.
      config = { 'type' => 'node' }.merge( _get_prelims() )
      ConfigHandler::create_new_config(config)
    end

    task :list do
    end
  end

  desc "create backup connection"
  namespace :backup do
    task :create do
      # create node connection config file.
      config = { 
        'type' => 'backup',
      }.merge( _get_prelims() )
      config['backup_storage'] = Capistrano::CLI.ui.ask("storage directory on backup server (relative to ~/): ")
      ConfigHandler::create_new_config(config)
    end

    task :list do
    end
  end
end

def _get_prelims
  id = Capistrano::CLI.ui.ask("id (used to identify the connection): ") { |q| q.answer_type = String; q.whitespace = :chomp_and_collapse }
  id = id.chomp.downcase.gsub(/ /, '-').gsub(/[^a-z-]/,'')
  hostname = Capistrano::CLI.ui.ask("hostname: ") { |q| q.answer_type = String; q.whitespace = :chomp }
  username = Capistrano::CLI.ui.ask("username: ") { |q| q.answer_type = String; q.whitespace = :chomp }
  {
    'id' => id,
    'hostname' => hostname,
    'username' => username
  }
end
