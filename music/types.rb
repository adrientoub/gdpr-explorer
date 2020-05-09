require 'json'
require 'date'

class MusicIndex
  attr_accessor :version, :artists

  def self.from_json(json)
    index = new
    index.version = json['version']
    index.artists = json['artists']&.map do |channel|
      ArtistIndex.from_json(channel)
    end
    index
  end
end

class ArtistIndex
  attr_accessor :artist_name, :path, :listens_count

  def self.from_json(json)
    artist_index = new
    artist_index.artist_name = json['artist_name']
    artist_index.path = json['path']
    artist_index.listens_count = json['listens_count']
    artist_index
  end

  def load_artist(output_path)
    content = File.read(File.join(output_path, self.path))
    json = JSON.parse(content)
    ArtistFile.from_json(json)
  end
end

class ArtistFile
  attr_accessor :artist_name, :listens

  def self.from_json(json)
    artist_file = new
    artist_file.artist_name = json['artist_name']
    artist_file.listens = json['listens'].map do |view|
      Listen.from_json(view)
    end
    artist_file
  end
end

class Listen
  attr_accessor :song_name, :container_name, :date, :song_duration, :play_duration

  def self.from_json(json)
    listen = new
    listen.song_name = json['song_name']
    listen.container_name = json['container_name']
    listen.date = DateTime.parse(json['date'])
    listen.song_duration = json['song_duration']
    listen.play_duration = json['play_duration']
    listen
  end
end
