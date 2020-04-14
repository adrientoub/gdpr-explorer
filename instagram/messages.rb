#! /usr/bin/env ruby

require 'json'
require 'date'
require_relative '../common/csv_exporter'

DELIMITER = ','

filename = ARGV[0] || 'messages.json'
username = ARGV[1] || 'adrientoub'

json = JSON.parse(File.read(filename))
puts "Parsed json #{filename}"

raw_data = {}
json.each do |conversation|
  conv_raw = {}
  conv_raw[:message_count] = 0
  conv_raw[:participants] = {}
  conversation['conversation'].each do |message|
    conv_raw[:participants][message['sender']] ||= 0
    conv_raw[:participants][message['sender']] += 1
    conv_raw[:message_count] += 1
  end
  raw_data[conversation['participants'].sort.join('-')] = conv_raw
end

puts "Dumping raw data to file"
File.open('messages_raw_data.json', 'w') do |file|
  file.puts JSON.dump(raw_data)
end

sorted_data = raw_data.to_a.sort_by { |_, stats| -stats[:message_count] }
exportable_data = []
sorted_data[0...10].each do |conversation_name, stats|
  count = stats[:message_count]
  puts "#{count}: #{conversation_name}"
  stats[:participants].each do |participant, participant_count|
    puts "#{participant}: #{participant_count} (#{(participant_count.to_f * 100 / count).round(2)}%)"
  end
end

# prepare data for export
sorted_data.each do |conversation_name, stats|
  count = stats[:message_count]
  ratio = 0
  stats[:participants].each do |participant, participant_count|
    if participant == username
      ratio = (participant_count.to_f * 100 / count).round(2)
    end
  end
  exportable_data << [conversation_name, count, ratio]
end
File.open('message_count.csv', 'w') do |file|
  CsvExporter.export_csv(file, exportable_data, %w(conversation_name message_count ratio), DELIMITER)
end
