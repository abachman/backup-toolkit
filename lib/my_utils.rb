require 'optparse'
require 'readline'
require 'rubygems'
require 'net/ssh'
require 'net/scp'
require 'yaml'

# {{{ Parse options
OPTIONS = {}
OptionParser.new do |opts|
  opts.banner = "Usage: generate_backup [options]"

  opts.on("-v", "--verbose", "verbose output") do |v|
    OPTIONS[:verbose] = v
  end
  opts.on("-s", "--server ADDRESS", "set production server address") do |s|
    OPTIONS[:server] = s
  end
  opts.on("-b", "--backup ADDRESS", "set backup server address") do |s|
    OPTIONS[:backup] = s
  end
  targets = [:directory, :mysql]
  target_aliases = { 'dir' => :directory, 'ms' => :mysql }
  opts.on("-t", "--target TARGET", targets, target_aliases, "select backup target type") do |t|
    OPTIONS[:target] = t.to_sym
  end
end.parse!
# }}}

def log m 
  puts m if OPTIONS[:verbose]
end

def input prompt=nil, default=nil
  puts "#{prompt} #{ "[#{default}]" if default }" if prompt
  out = Readline::readline('> ').strip
  return out.empty? ? default : out
end

module BackupToolkit
  class Server
    attr_accessor :hostname, :username, :password, :name
    def ssh_address
      "#{username}@#{hostname}"
    end
  end

  # {{{ Get Server Info
  def self.get_server_info server_name
    server = BackupToolkit::Server.new
    server.name = "backup"
    opts = {}
    if File.exist? File.join(File.dirname(__FILE__), '..', 'config', "#{server_name}.yml")
      opts = File.open(File.join(File.dirname(__FILE__), '..', 'config', "#{server_name}.yml")) { |yf| YAML::load( yf ) }
      log "[#{server_name}] Using config file for settings #{opts.inspect}"
    end
    
    server.hostname = opts['address'] || input("[#{server_name}] What's the server hostname?", nil)
    server.username = opts['username'] || input("[#{server_name}] What's the server username?", nil)
    server.password = opts['password'] || input("[#{server_name}] What's the server password?", nil)
    return server
  end
  # }}}

  def self.generate_config h
    YAML::dump( h )
  end

  # {{{ SSH utils
  def self.send_files server, *files
    # Runs file uploads in parallel, blocks until all are done.
    # *files is a collection of local, remote filepath tuples.
    begin
      Net::SCP.start(server.hostname, server.username, :password => server.password) do |scp|
        for file in files
          puts "uploading #{file[0]} to #{file[1]}"
          scp.upload!(file[0], file[1])
        end
      end
    rescue Net::SSH::AuthenticationFailed, Net::SCP::Error
      puts "ERROR: server = #{server.inspect}"
      raise
    end
  end

  def self.get_files server, *files
    # Runs file uploads in parallel, blocks until all are done.
    # *files is a collection of local, remote filepath tuples.
    begin
      Net::SCP.start(server.hostname, server.username, :password => server.password) do |scp|
        downs = []
        for file in files
          downs << scp.download(file[1], file[0])
        end
        downs.each { |u| u.wait }
      end
    rescue Net::SSH::AuthenticationFailed, Net::SCP::Error
      puts "ERROR: server = #{server.inspect}"
      raise
    end
  end
  # }}}

end
