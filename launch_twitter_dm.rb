#! /usr/bin/env ruby

require_relative './common/types'
require_relative './twitter/parser'
require_relative './messages/analyse'

def print_help
  puts "Usage: #{__FILE__ } [path_to_dms] [output_directory]"
  puts "  'path_to_dms' is the path to the Twitter file named 'direct-messages.js'"
  puts "  'output_directory' is the directory where you want the script to output its work"
  exit 1
end

if ARGV.length < 2
  print_help
end

path_to_dms, output_directory = ARGV

index_path = File.join(output_directory, INDEX_PATH)
if File.exists?(index_path)
  index = JSON.parse(File.read(index_path))
  if index['version'] != CURRENT_VERSION
    puts "Found an index on #{index['version']}, need #{CURRENT_VERSION}. Reloading."
    index = nil
  else
    puts "Found a viable index, reusing it."
  end
end
index ||= TwitterParser.parse(path_to_dms, output_directory)

MessagesAnalyse.analyse(index, output_directory)
