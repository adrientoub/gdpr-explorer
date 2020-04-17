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
      'version' => CURRENT_VERSION,
      'conversations' => conversations_index
    }
    conversations_raw = Hash.new { Hash.new }

    json.each do |conversation|
      conversation_name = conversation['participants'].sort.join('-')

      # Do this to allow conversations that are split in 2 different Hash
      conv_raw = conversations_raw[conversation_name]
      conversations_raw[conversation_name] = conv_raw

      messages = conv_raw['messages'] || []
      conversation['conversation'].each do |message|
        messages << {
          'sender' => message['sender'],
          'date' => message['created_at'],
          'content' => message['text'],
          'reactions' => message['likes']&.map do |like|
            {
              'sender' => like['username'],
              'reaction' => 'like'
            }
          end
        }
      end
      conv_raw['conversation_name'] ||= conversation_name
      conv_raw['participants'] ||= conversation['participants']
      conv_raw['messages'] = messages
    end

    # Dump all conversations to disk
    conversations_raw.each do |conversation_name, conv_raw|
      output_conversation_path = "conversations/#{conversation_name}.json"
      File.open(File.join(output_directory, output_conversation_path), 'w') do |file|
        file.puts JSON.dump(conv_raw)
      end

      conversations_index << {
        'conversation_name' => conversation_name,
        'path' => output_conversation_path,
        'message_count' => conv_raw['messages'].count
      }
    end

    conversations_index.sort_by! do |conversation|
      conversation['message_count']
    end.reverse!

    File.open(index_path, 'w') do |file|
      file.puts JSON.dump(index)
    end
    puts "Saved index in #{index_path}"
    index
  end
end
