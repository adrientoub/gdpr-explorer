require 'json'
require 'date'

class YoutubeIndex
  attr_accessor :version, :channels

  def self.from_json(json)
    index = new
    index.version = json['version']
    index.channels = json['channels']&.map do |channel|
      ChannelIndex.from_json(channel)
    end
    index
  end
end

class ChannelIndex
  attr_accessor :channel_name, :channel_url, :path, :view_count

  def self.from_json(json)
    channel = new
    channel.channel_name = json['channel_name']
    channel.channel_url = json['channel_url']
    channel.path = json['path']
    channel.view_count = json['view_count']
    channel
  end

  def load_channel(output_path)
    content = File.read(File.join(output_path, self.path))
    json = JSON.parse(content)
    ChannelFile.from_json(json)
  end
end

class ChannelFile
  attr_accessor :channel_name, :channel_url, :views

  def self.from_json(json)
    channel = new
    channel.channel_name = json['channel_name']
    channel.channel_url = json['channel_url']
    channel.views = json['views'].map do |view|
      View.from_json(view)
    end
    channel
  end
end

class View
  attr_accessor :url, :title, :date

  def self.from_json(json)
    view = new
    view.url = json['url']
    view.title = json['titlee']
    view.date = DateTime.parse(json['date'])
    view
  end
end
