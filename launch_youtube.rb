#! /usr/bin/env ruby

require_relative './common/common'
require_relative './youtube/parser'
require_relative './youtube/analyse'

def print_help
  puts "Usage: #{__FILE__ } [path_to_history] [output_directory]"
  puts "  'path_to_history' is the path to the YouTube file named 'watch-history.json'"
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
index ||= YoutubeParser.parse(path_to_inbox, output_directory)

YoutubeAnalyse.analyse(index, output_directory)
