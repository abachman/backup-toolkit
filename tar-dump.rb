#!/usr/bin/env ruby
# 
# generate timestamped, gzipped dump of a folder with sensible defaults.

require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: generate_backup [options]"

  opts.on("-v", "--verbose", "verbose output") do |v|
    options[:verbose] = v
  end
  opts.on("-p", "--path PATH", "set source path") do |s|
    options[:server] = s
  end
  opts.on("-", "--backup ADDRESS", "set backup server address") do |s|
    options[:backup] = s
  end
  targets = ['directory', 'mysql']
  target_aliases = { 'dir' => 'directory', 'ms' => 'mysql' }
  opts.on("-t", "--target TARGET", targets, target_aliases, "select backup target type") do |t|
    options[:target] = t
  end
end.parse!

