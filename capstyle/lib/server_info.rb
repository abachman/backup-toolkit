set(:backup_server) do
  opts = {}
  dir = File.dirname(__FILE__)
  Dir.new(dir).each do |file|
    file = File.join(dir, file)
    next unless File.file?(file)
    next unless /backup.*\.yml/ =~ file
    confirm = Capistrano::CLI.ui.ask("use #{file} for backup config? Y/n ")
    if confirm.empty? or /^y/i =~ confirm
      opts = File.open(file) { |yf| YAML::load( yf ) }
      break
    end
  end
  opts
end

set(:production_server) do
  opts = {}
  dir = File.dirname(__FILE__)
  Dir.new(dir).each do |file|
    file = File.join(dir, file)
    next unless File.file?(file)
    next unless /production.*\.yml/ =~ file
    confirm = Capistrano::CLI.ui.ask("use #{file} for production config? Y/n ")
    if confirm.empty? or /^y/i =~ confirm
      opts = File.open(file) { |yf| YAML::load( yf ) }
      break
    end
  end
  opts
end

