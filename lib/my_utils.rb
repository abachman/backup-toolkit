require 'optparse'
require 'readline'

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
  puts "#{prompt} [#{default}]" if prompt
  out = Readline::readline('> ').strip
  return out.empty? ? default : out
end

