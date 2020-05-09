#! /usr/bin/env ruby

require 'csv'
require 'date'
require 'fileutils'
require 'json'

class AppleMusicParser
  # Messages path is the path to the Apple-Music-Play-Activity.csv file
  # Output path is the directory where you want to save your index.json file
  def self.parse(play_activity_path, output_directory)
    index_path = File.join(output_directory, INDEX_PATH)

    # Create output directory
    FileUtils.mkdir_p(File.join(output_directory, 'artists'))

    content = File.read(play_activity_path)
    csv = CSV.parse(content, headers: true)
    puts "Parsed CSV #{play_activity_path}"

    artists_index = []
    index = {
      'version' => Common.required_version(Common::MUSIC_TYPE),
      'artists' => artists_index
    }
    artists_raw = Hash.new { Hash.new }

    csv.each do |song|
      artist_name = song['Artist Name']

      # Do this to allow artists that are split in 2 different Hash
      artist_raw = artists_raw[artist_name]
      artists_raw[artist_name] = artist_raw

      listens = artist_raw['listens'] || []
      listens << {
        'song_name' => song['Song Name'],
        'container_name' => song['Container Name'],
        'date' => song['Event Received Timestamp'],
        'song_duration' => song['Media Duration In Milliseconds'].to_i,
        # take absolute value because "old" Apple Music data reports negative play durations
        'play_duration' => song['Play Duration Milliseconds'].to_i.abs,
      }
      artist_raw['artist_name'] ||= artist_name
      artist_raw['listens'] = listens
    end

    # Dump all artists to disk
    artists_raw.each do |artist_name, artist_raw|
      output_song_path = "artists/#{artist_name}.json"
      File.open(File.join(output_directory, output_song_path), 'w') do |file|
        file.puts JSON.dump(artist_raw)
      end

      artists_index << {
        'artist_name' => artist_name,
        'path' => output_song_path,
        'listens_count' => artist_raw['listens'].count
      }
    end

    artists_index.sort_by! do |song|
      song['listens_count']
    end.reverse!

    File.open(index_path, 'w') do |file|
      file.puts JSON.dump(index)
    end
    puts "Saved index in #{index_path}"
    index
  end
end
