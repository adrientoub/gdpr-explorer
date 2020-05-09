#! /usr/bin/env ruby

require_relative './common/common'
require_relative './videos/analyse'
require_relative './youtube/parser'

def print_help
  puts "Usage: #{__FILE__ } [path_to_history] [output_directory]"
  puts "  'path_to_history' is the path to the YouTube file named 'watch-history.json'"
  puts "  'output_directory' is the directory where you want the script to output its work"
  exit 1
end

if ARGV.length < 2
  print_help
end
force = Common.get_force_from_argv

path_to_inbox, output_directory = ARGV

index = Common.read_from_index(Common::VIDEOS_TYPE, output_directory) unless force
index ||= YoutubeParser.parse(path_to_inbox, output_directory)

VideosAnalyse.analyse(index, output_directory, force)
