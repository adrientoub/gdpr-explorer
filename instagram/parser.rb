#! /usr/bin/env ruby

require 'json'
require 'date'
require 'fileutils'
require_relative '../common/types'

filename = ARGV[0] || 'messages.json'

json = JSON.parse(File.read(filename))
puts "Parsed json #{filename}"

index = {
  version: CURRENT_VERSION,
  conversations: []
}

FileUtils.mkdir_p('conversations')

json.each do |conversation|
  conversation_name = conversation['participants'].sort.join('-')
  path = "conversations/#{conversation_name}.json"

  conv_raw = {
    conversation_name: conversation_name,
    participants: conversation['participants'],
    messages: conversation['conversation'].map do |message|
      {
        sender: message['sender'],
        date: message['created_at'],
        content: message['text'],
        reactions: message['likes']&.map do |like|
          {
            sender: like['username'],
            reaction: 'like'
          }
        end
      }
    end
  }
  File.open(path, 'w') do |file|
    file.puts JSON.dump(conv_raw)
  end

  index_conv = {
    conversation_name: conversation_name,
    path: path,
    message_count: conv_raw[:messages].count
  }
  index[:conversations] << index_conv
end
index[:conversations].sort_by! do |conversation|
  conversation[:message_count]
end.reverse!

File.open(INDEX_PATH, 'w') do |file|
  file.puts JSON.dump(index)
end
puts "Saved index in #{INDEX_PATH}"
