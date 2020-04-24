require 'json'
require 'date'
require 'fileutils'
require_relative '../common/types'

class YoutubeParser
  # History path is the path to the watch-history.json file
  # Output path is the directory where you want to save your index.json file
  def self.parse(path_to_history, output_directory)
    # Create output directory
    FileUtils.mkdir_p(File.join(output_directory, 'channels'))

    json = JSON.parse(File.read(path_to_history))
    puts "Parsed json #{path_to_history}"

    channels_index = []
    index = {
      'version' => CURRENT_VERSION,
      'channels' => channels_index
    }

    channels_raw = Hash.new { Hash.new }
    json.each do |view|
      # private video, not linked to channel, skip for now
      next if view['subtitles'].nil? || view['subtitles'].first['url'].nil?

      channel_name = view['subtitles'].first['name']
      channel_url = view['subtitles'].first['url']

      channel_raw = channels_raw[channel_url]
      channels_raw[channel_url] = channel_raw

      views = channel_raw['views'] || []
      views << {
        'url' => view['titleUrl'],
        'title' => view['title'],
        'date' => DateTime.parse(view['time'])
      }

      channel_raw['channel_name'] ||= channel_name
      channel_raw['channel_url'] ||= channel_url
      channel_raw['views'] = views
    end

    # Dump all conversations to disk
    channels_raw.each do |channel_url, channel_raw|
      # only keep the last part of the URL of the channel (ex: UCMjoAtEf57gvCk5N69SuKtQ)
      output_channel_path = "channels/#{channel_url.split('/')[-1]}.json"
      File.open(File.join(output_directory, output_channel_path), 'w') do |file|
        file.puts JSON.dump(channel_raw)
      end

      channels_index << {
        'channel_name' => channel_raw['channel_name'],
        'channel_url' => channel_url,
        'path' => output_channel_path,
        'view_count' => channel_raw['views'].count
      }
    end
    channels_index.sort_by! do |channel|
      channel['view_count']
    end.reverse!

    index_path = File.join(output_directory, INDEX_PATH)
    File.open(index_path, 'w') do |file|
      file.puts JSON.dump(index)
    end
    puts "Saved index in #{index_path}"
    index
  end
end
