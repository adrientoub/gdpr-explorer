#! /usr/bin/env ruby

require_relative './common/types'
require_relative './facebook/parser'
require_relative './messages/analyse'

def print_help
  puts "Usage: #{__FILE__ } [path_to_inbox] [output_directory]"
  puts "  'path_to_inbox' is the path to the Facebook Archive folder named 'messages/inbox'"
  puts "  'output_directory' is the directory where you want the script to output its work"
  exit 1
end

if ARGV.length < 2
  print_help
end

path_to_inbox, output_directory = ARGV

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
index ||= FacebookParser.parse(path_to_inbox, output_directory)

MessagesAnalyse.analyse(index, output_directory)
