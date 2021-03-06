#! /usr/bin/env ruby

require_relative './common/common'
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
force = Common.get_force_from_argv

path_to_dms, output_directory = ARGV

index = Common.read_from_index(Common::MESSAGES_TYPE, output_directory) unless force
index ||= TwitterParser.parse(path_to_dms, output_directory)

MessagesAnalyse.analyse(index, output_directory, force)
