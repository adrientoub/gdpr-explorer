#! /usr/bin/env ruby

require 'json'
require 'date'
require_relative '../common/csv_exporter'
require_relative '../common/dir_size'
require_relative './fix_unicode'

path = ARGV[0] || 'inbox'
STANDARD_OUTPUT = false

conversations_raw = []

# find all conversations
if File.exists?('messages_raw_data.json')
  puts "Loading raw data from disk conversations"
  conversations_raw = JSON.parse(File.read('messages_raw_data.json'), symbolize_names: true)
else
  children = Dir.children(path)
  puts "Loading #{children.count} conversations"

  children.each_with_index do |conversation_name, i|
    puts "  Done #{i}/#{children.count}" if i % 25 == 0

    conversation_relative_path = File.join(path, conversation_name)

    if File.directory?(conversation_relative_path)
      conversation_directory = Dir.new(conversation_relative_path)
      conv_raw = {
        message_count: 0,
        count_per_participant: {},
        message_per_day: {}
      }
      conv_raw[:size] = DirSize.all_file_sizes(conversation_relative_path)
      conversation_directory.each do |message_file|
        message_file_path = File.join(conversation_relative_path, message_file)
        if File.file?(message_file_path)
          content = File.read(message_file_path)
          begin
            json = JSON.parse(FixUnicode.fix(content))
          rescue
            puts "cannot read #{message_file_path}, reading without fixing encoding"
            json = JSON.parse(content)
          end

          conv_raw[:title] = json['title']
          conv_raw[:participants] = json['participants'].map { |k| k['name'] }
          json['messages'].each do |message|
            conv_raw[:message_count] += 1
            conv_raw[:count_per_participant][message['sender_name']] ||= 0
            conv_raw[:count_per_participant][message['sender_name']] += 1
            date = Time.at(message['timestamp_ms'] / 1000).to_date.to_s
            conv_raw[:message_per_day][date] ||= 0
            conv_raw[:message_per_day][date] += 1
          end
        end
      end
      conversations_raw << conv_raw
    end
  end

  puts "Saving raw data to disk"

  File.open('messages_raw_data.json', 'w') do |file|
    file.puts JSON.dump(conversations_raw)
  end
end

puts "Loading done. Printing out data."

# print out data
conversations_raw.sort_by! { |conv_raw| -conv_raw[:message_count] }
exportable_data = []
conversations_raw.each do |conv_raw|
  puts "#{conv_raw[:message_count]} - #{conv_raw[:title]}" if STANDARD_OUTPUT
  conv_raw[:count_per_participant].to_a.sort_by { |participant, count| -count }.each do |participant, count|
    puts "  #{count} - #{participant}" if STANDARD_OUTPUT
  end
  exportable_data << [conv_raw[:title], conv_raw[:message_count]]
end

puts "Export message count to CSV."
File.open('message_count.csv', 'w') do |file|
  CsvExporter.export_csv(file, exportable_data, %w(conversation_name message_count))
end

messages_per_month = Hash.new

conversations_raw.each do |conv_raw|
  conv_raw[:message_per_day].each do |date, msg_count|
    month_date = date[0..-4]
    messages_per_month[month_date] ||= Hash.new(0)
    messages_per_month[month_date][conv_raw[:title]] += msg_count
  end
end

thread_list = conversations_raw.select { |c| c[:message_count] > 50 }.sort_by { |c| -c[:message_count] }.map { |c| c[:title] }
puts "Keeping #{thread_list.count} threads for the per month graphs."

File.open('message_per_month.json', 'w') do |file|
  file.puts JSON.dump(messages_per_month)
end
File.open('message_per_month.csv', 'w') do |file|
  file.puts "Date,#{thread_list.map { |m| m.gsub(',', ':') }.join(',')}"
  lines = []

  messages_per_month.each do |date, threads|
    res = []
    thread_list.each do |thread|
      res << (threads[thread] || 0)
    end
    lines << "#{date},#{res.join(',')}"
  end
  file.puts lines.sort.join("\n")
end
