require 'json'
require 'date'
require 'set'
require 'fileutils'

class WhatsAppParser
  DIRECTORY_PREFIX = 'WhatsApp Chat - '

  # Input directory path is the path to the folder containing all message archives of the form 'WhatsApp Chat - *'
  # Output path is the directory where you want to save your index.json file
  def self.parse(input_directory_path, output_directory)
    index_path = File.join(output_directory, INDEX_PATH)

    # Create output directory
    FileUtils.mkdir_p(File.join(output_directory, 'conversations'))

    conversations_index = []

    index = {
      'version' => CURRENT_VERSION,
      'conversations' => conversations_index
    }

    children = Dir.children(input_directory_path)
    puts "Loading #{children.count} conversations"

    children.each do |directory_name|
      conversation_relative_path = File.join(input_directory_path, directory_name)

      if File.directory?(conversation_relative_path)
        if directory_name.start_with?(DIRECTORY_PREFIX)
          conversation_name = directory_name[(DIRECTORY_PREFIX.length)..-1]
        else
          conversation_name = directory_name
        end
        message_file_path = File.join(conversation_relative_path, '_chat.txt')

        if File.file?(message_file_path)
          output_conversation_path = "conversations/#{directory_name}.json"
          conv_raw = parse_file_content(conversation_name, message_file_path)
          File.open(File.join(output_directory, output_conversation_path), 'w') do |file|
            file.puts JSON.dump(conv_raw)
          end
          index_conv = {
            'conversation_name' => conv_raw['conversation_name'],
            'path' => output_conversation_path,
            'message_count' => conv_raw['messages'].count
          }
          conversations_index << index_conv
        else
          puts "Found no conversation at #{message_file_path}."
        end
      end
    end

    File.open(index_path, 'w') do |file|
      file.puts JSON.dump(index)
    end
    puts "Saved index in #{index_path}"

    index
  end

  private

  def self.parse_file_content(conversation_name, message_file_path)
    messages = []
    participants = Set.new
    conv_raw = {
      'conversation_name' => conversation_name,
      'participants' => nil,
      'messages' => messages
    }

    message = nil
    sender = nil
    date = nil

    File.open(message_file_path).each do |line|
      if match_data = /^\[([0-9\/: ]{19})\] (.+?):(.+)/.match(line)
        unless message.nil?
          messages << {
            'sender' => sender,
            'date' => DateTime.parse(date).to_s,
            'content' => message
          }
        end

        date = match_data[1]
        sender = match_data[2]
        participants << sender
        message = match_data[3]
      else
        message += "#{line}"
      end
    end

    conv_raw['participants'] = participants.to_a
    conv_raw
  end
end
