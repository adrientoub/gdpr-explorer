#! /usr/bin/env ruby

require 'json'
require 'date'
require 'fileutils'
require_relative '../common/types'

class InstagramParser
  # Messages path is the path to the messages.json file
  # Output path is the directory where you want to save your index.json file
  def self.parse(messages_path, output_directory)
    index_path = File.join(output_directory, INDEX_PATH)

    # Create output directory
    FileUtils.mkdir_p(File.join(output_directory, 'conversations'))

    json = JSON.parse(File.read(messages_path))
    puts "Parsed json #{messages_path}"

    conversations_index = []
    index = {
      version: CURRENT_VERSION,
      conversations: conversations_index
    }

    json.each do |conversation|
      conversation_name = conversation['participants'].sort.join('-')
      output_conversation_path = "conversations/#{conversation_name}.json"

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
      File.open(File.join(output_directory, output_conversation_path), 'w') do |file|
        file.puts JSON.dump(conv_raw)
      end

      index_conv = {
        conversation_name: conversation_name,
        path: output_conversation_path,
        message_count: conv_raw[:messages].count
      }
      conversations_index << index_conv
    end
    conversations_index.sort_by! do |conversation|
      conversation[:message_count]
    end.reverse!

    File.open(index_path, 'w') do |file|
      file.puts JSON.dump(index)
    end
    puts "Saved index in #{index_path}"
    index
  end
end
