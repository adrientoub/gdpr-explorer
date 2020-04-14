#! /usr/bin/env ruby

require 'json'
require 'date'
require_relative '../common/csv_exporter'
require_relative '../common/dir_size'

path = ARGV[0] || 'inbox'

conversations_raw = []

# find all conversations
children = Dir.children(path)
puts "Loading #{children.count} conversations"

children.each_with_index do |conversation_name, i|
  puts "  Done #{i}/#{children.count}" if i % 25 == 0

  conversation_relative_path = File.join(path, conversation_name)

  if File.directory?(conversation_relative_path)
    conversation_directory = Dir.new(conversation_relative_path)
    conv_raw = {
      message_count: 0,
      count_per_participant: {}
    }
    conv_raw[:size] = DirSize.all_file_sizes(conversation_relative_path)
    conversation_directory.each do |message_file|
      message_file_path = File.join(conversation_relative_path, message_file)
      if File.file?(message_file_path)
        json = JSON.parse(File.read(message_file_path))

        conv_raw[:title] = json['title']
        conv_raw[:participants] = json['participants'].map { |k| k['name'] }
        json['messages'].each do |message|
          conv_raw[:message_count] += 1
          conv_raw[:count_per_participant][message['sender_name']] ||= 0
          conv_raw[:count_per_participant][message['sender_name']] += 1
        end
      end
    end
    conversations_raw << conv_raw
  end
end

puts "Loading done. Printing out data."

# print out data
conversations_raw.sort_by! { |conv_raw| -conv_raw[:message_count] }
exportable_data = []
conversations_raw.each do |conv_raw|
  puts "#{conv_raw[:message_count]} - #{conv_raw[:title]}"
  conv_raw[:count_per_participant].to_a.sort_by { |participant, count| -count }.each do |participant, count|
    puts "  #{count} - #{participant}"
  end
  exportable_data << [conv_raw[:title], conv_raw[:message_count]]
end

puts "Saving raw data to disk"

File.open('messages_raw_data.json', 'w') do |file|
  file.puts JSON.dump(conversations_raw)
end
File.open('message_count.csv', 'w') do |file|
  CsvExporter.export_csv(file, exportable_data, %w(conversation_name message_count))
end
