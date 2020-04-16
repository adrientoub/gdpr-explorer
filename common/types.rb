require 'json'
require 'date'

CURRENT_VERSION = '0.0.3'
INDEX_PATH = 'index.json'

class Index
  attr_accessor :version, :conversations

  def self.from_json(json)
    index = new
    index.version = json['version']
    index.conversations = json['conversations'].map do |conversation|
      ConversationIndex.from_json(conversation)
    end
    index
  end
end

class ConversationIndex
  attr_accessor :conversation_name, :path, :message_count

  def self.from_json(json)
    conversation = new
    conversation.conversation_name = json['conversation_name']
    conversation.path = json['path']
    conversation.message_count = json['message_count']
    conversation
  end

  def load_conversation
    content = File.read(self.path)
    json = JSON.parse(content)
    ConversationFile.from_json(json)
  end
end

class ConversationFile
  attr_accessor :conversation_name, :participants, :messages

  def self.from_json(json)
    conversation = new
    conversation.conversation_name = json['conversation_name']
    conversation.participants = json['participants']
    conversation.messages = json['messages'].map do |message|
      Message.from_json(message)
    end
    conversation
  end
end

class Message
  attr_accessor :sender, :content, :date, :reactions

  def self.from_json(json)
    message = new
    message.sender = json['sender']
    message.content = json['content']
    message.date = DateTime.parse(json['date'])
    message.reactions = json['reactions']&.map do |reaction|
      Reaction.from_json(reaction)
    end
    message
  end
end

class Reaction
  attr_accessor :reaction, :sender

  def self.from_json(json)
    reaction = new
    reaction.reaction = json['reaction']
    reaction.sender = json['sender']
    reaction
  end
end
