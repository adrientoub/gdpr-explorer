#! /usr/bin/env ruby

require_relative './common/common'
require_relative './apple_music/parser'
require_relative './music/analyse'

def print_help
  puts "Usage: #{__FILE__ } [path_to_play_activity] [output_directory]"
  puts "  'path_to_play_activity' is the path to the file named 'Apple Music Play Activity.csv'"
  puts "  'output_directory' is the directory where you want the script to output its work"
  exit 1
end

if ARGV.length < 2
  print_help
end
force = Common.get_force_from_argv

path_to_play_activity, output_directory = ARGV

index = Common.read_from_index(Common::MUSIC_TYPE, output_directory) unless force
index ||= AppleMusicParser.parse(path_to_play_activity, output_directory)

MusicAnalyse.analyse(index, output_directory, force)
