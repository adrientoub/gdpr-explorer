#! /usr/bin/env ruby

require_relative './common/common'
require_relative './messages/analyse'
require_relative './messages/types'
require_relative './whatsapp/parser'

def print_help
  puts "Usage: #{__FILE__ } [path_to_input_directory] [output_directory]"
  puts "  'path_to_input_directory' is the path to the folder containing all message archives of the form 'WhatsApp Chat'"
  puts "  'output_directory' is the directory where you want the script to output its work"
  exit 1
end

if ARGV.length < 2
  print_help
end

path_to_input_directory, output_directory = ARGV

index = Common.read_from_index(Common::MESSAGES_TYPE, output_directory)
index ||= WhatsAppParser.parse(path_to_input_directory, output_directory)

MessagesAnalyse.analyse(index, output_directory)
