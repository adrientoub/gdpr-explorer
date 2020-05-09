require 'json'
require 'date'
require 'fileutils'
require_relative '../messages/types'
require_relative './fix_unicode'

class FacebookParser
  # Archive path is the path to the Facebook Archive folder named 'messages/inbox'
  # Output path is the directory where you want to save your index.json file
  def self.parse(archive_path, output_directory)
    index_path = File.join(output_directory, INDEX_PATH)

    # Create output directory
    FileUtils.mkdir_p(File.join(output_directory, 'conversations'))

    conversations_index = []

    index = {
      'version' => CURRENT_VERSION,
      'conversations' => conversations_index
    }

    children = Dir.children(archive_path)
    puts "Loading #{children.count} conversations"

    children.each_with_index do |conversation_name, i|
      puts "  Done #{i}/#{children.count}" if i % 25 == 0

      conversation_relative_path = File.join(archive_path, conversation_name)

      if File.directory?(conversation_relative_path)
        conversation_directory = Dir.new(conversation_relative_path)

        messages = []
        conv_raw = {
          'conversation_name' => nil,
          'participants' => nil,
          'messages' => messages
        }
        output_conversation_path = "conversations/#{conversation_name}.json"
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

            conv_raw['conversation_name'] ||= json['title']
            conv_raw['participants'] ||= json['participants'].map { |k| k['name'] }
            json['messages'].each do |message|
              messages << {
                'sender' => message['sender_name'],
                'date' => Time.at(message['timestamp_ms'] / 1000).to_datetime.to_s,
                'content' => message['content'],
                'reactions' => message['reactions']&.map do |reaction|
                  {
                    'sender' => reaction['actor'],
                    'reaction' => reaction['reaction']
                  }
                end
              }
            end
          end
        end
        File.open(File.join(output_directory, output_conversation_path), 'w') do |file|
          file.puts JSON.dump(conv_raw)
        end

        index_conv = {
          'conversation_name' => conv_raw['conversation_name'],
          'path' => output_conversation_path,
          'message_count' => conv_raw['messages'].count
        }
        conversations_index << index_conv
      end
    end

    File.open(index_path, 'w') do |file|
      file.puts JSON.dump(index)
    end
    puts "Saved index in #{index_path}"

    index
  end
end
