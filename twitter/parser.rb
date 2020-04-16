require 'json'
require 'date'
require 'fileutils'
require_relative '../common/types'

class TwitterParser
  # Messages path is the path to the direct-messages.js file
  # Output path is the directory where you want to save your index.json file
  def self.parse(path_to_dms, output_directory)
    # Create output directory
    FileUtils.mkdir_p(File.join(output_directory, 'conversations'))

    dms_file_content = File.read(path_to_dms)
    unless dms_file_content.start_with?('window.YTD.direct_messages.part0 = ')
      raise "Invalid 'direct-message.js' file at #{path_to_dms}."
    end

    json = JSON.parse(dms_file_content[35..-1])
    puts "Parsed json #{path_to_dms}"

    conversations_index = []
    index = {
      'version' => CURRENT_VERSION,
      'conversations' => conversations_index
    }

    conversations_raw = Hash.new { Hash.new }

    json.each do |conversation|
      dm_conversation = conversation['dmConversation']
      conversation_name = dm_conversation['conversationId']

      # Do this to allow conversations that are split in 2 different Hash
      conv_raw = conversations_raw[conversation_name]
      conversations_raw[conversation_name] = conv_raw

      messages = conv_raw['messages'] || []
      # reverse the messages to have the message first and then the reactions
      dm_conversation['messages'].reverse.each do |message|
        if msg = message['messageCreate'] || message['welcomeMessageCreate']
          messages << {
            'id' => msg['id'],
            'sender' => msg['senderId'],
            'date' => msg['createdAt'],
            'content' => msg['text'],
            'reactions' => []
          }
        # link the reaction to the correct tweet
        elsif reaction = message['reactionCreate']
          position = messages.find_index do |msg|
            msg['id'] == reaction['eventId']
          end
          if position
            messages[position]['reactions'] << {
              'sender' => reaction['senderId'],
              'reaction' => reaction['reactionKey']
            }
          end
        else
          # print if the message type is unknown to handle it
          p message
        end
      end

      conv_raw['conversation_name'] ||= conversation_name
      conv_raw['participants'] ||= conversation_name.split('-')
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

    index_path = File.join(output_directory, INDEX_PATH)
    File.open(index_path, 'w') do |file|
      file.puts JSON.dump(index)
    end
    puts "Saved index in #{index_path}"
    index
  end
end
