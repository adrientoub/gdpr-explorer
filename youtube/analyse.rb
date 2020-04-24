require 'json'
require_relative '../common/common'
require_relative '../common/csv_exporter'
require_relative './types'

ANALYSE_CACHE_PATH = 'view_analysed_cache.json'

class YoutubeAnalyse
  def self.analyse(json, output_path)
    raw_payload = load_or_parse(json, output_path)
    channels_raw = raw_payload['channels']

    sort!(channels_raw)

    export_view_count(channels_raw, output_path)
    export_views_per_month(channels_raw, output_path)
    export_views_per_hour(channels_raw, output_path)
    export_views_per_day_of_week(channels_raw, output_path)
  end

  private

  def self.load_or_parse(json, output_path)
    analyse_cache_path = File.join(output_path, ANALYSE_CACHE_PATH)
    if File.exists?(analyse_cache_path)
      raw_payload = JSON.parse(File.read(analyse_cache_path))
      if raw_payload.is_a?(Hash) && raw_payload['version'] != CURRENT_VERSION
        puts "Found a cache on #{raw_payload['version']}, need #{CURRENT_VERSION}. Reloading."
        raw_payload = nil
      else
        puts "Found a viable cache, reusing it."
      end
    end
    raw_payload ||= parse(json, output_path)
  end

  def self.parse(json, output_path)
    index = YoutubeIndex.from_json(json)

    channels_raw = []
    raw_payload = {
      'version' => CURRENT_VERSION,
      'channels' => channels_raw
    }

    index.channels.each do |channel|
      loaded_channel = channel.load_channel(output_path)
      conv_raw_metadata = {
        'title' => loaded_channel.channel_name,
        'view_count' => 0,
        'view_per_day' => Hash.new(0),
        'view_per_hour' => Hash.new(0)
      }
      channels_raw << conv_raw_metadata

      loaded_channel.views.each do |view|
        conv_raw_metadata['view_count'] += 1
        datetime = view.date.to_s
        date = datetime[0...10]
        hour = datetime[11..12]
        conv_raw_metadata['view_per_day'][date] += 1
        conv_raw_metadata['view_per_hour']["h#{hour}"] += 1
      end
    end

    File.open(File.join(output_path, ANALYSE_CACHE_PATH), 'w') do |file|
      file.puts JSON.dump(raw_payload)
    end

    raw_payload
  end

  def self.sort!(channels_raw)
    # Sort highest view count first
    channels_raw.sort_by! do |conv_raw|
      conv_raw['view_count']
    end.reverse!
  end

  def self.export_view_count(channels_raw, output_path)
    exportable_data = []
    File.open(File.join(output_path, 'view_count.txt'), 'w') do |file|
      channels_raw.each do |conv_raw|
        file.puts "#{conv_raw['view_count']} views - #{conv_raw['title']}"
        exportable_data << [conv_raw['title'], conv_raw['view_count']]
      end
    end

    puts "Export view count to CSV."
    File.open(File.join(output_path, 'view_count.csv'), 'w') do |file|
      CsvExporter.export_csv(file, exportable_data, %w(channel_name view_count), DELIMITER)
    end
  end

  def self.export_views_per_month(channels_raw, output_path)
    views_per_month = Hash.new

    channels_raw.each do |conv_raw|
      conv_raw['view_per_day'].each do |date, msg_count|
        month_date = date[0..-4]
        views_per_month[month_date] ||= Hash.new(0)
        views_per_month[month_date][conv_raw['title']] += msg_count
      end
    end

    # Keep only channels with more than 50 views
    channel_list = channels_raw.select do |c|
      c['view_count'] > 50
    end.sort_by do |c|
      -c['view_count']
    end.map do |c|
      c['title']
    end
    puts "Keeping #{channel_list.count} channels for the per month graph."

    File.open(File.join(output_path, 'view_per_month.json'), 'w') do |file|
      file.puts JSON.dump(views_per_month)
    end
    File.open(File.join(output_path, 'view_per_month.csv'), 'w') do |file|
      file.puts "Date#{DELIMITER}#{channel_list.map { |thread_name| CsvExporter.sanitize_data(thread_name, DELIMITER) }.join(DELIMITER)}"
      lines = []

      dates = views_per_month.keys.sort
      generate_all_months(dates[0], dates[-1]).each do |date|
        chan = views_per_month[date] || {}
        res = []
        channel_list.each do |channel_name|
          res << (chan[channel_name] || 0)
        end
        file.puts "#{date}#{DELIMITER}#{res.join(DELIMITER)}"
      end
    end
  end

  # from and to are in the form '2020-04'
  def self.generate_all_months(from, to)
    (Date.parse("#{from}-01")..Date.parse("#{to}-01")).map do |date|
      date.to_s[0..6]
    end.uniq
  end

  def self.export_views_per_hour(channels_raw, output_path)
    hours = (0..23).to_a
    hours_usable = hours.map { |hour| "h#{hour.to_s.rjust(2, '0')}" }.to_a
    File.open(File.join(output_path, 'view_per_hour.csv'), 'w') do |file|
      file.puts "Channel name#{DELIMITER}#{hours.join(DELIMITER)}"
      lines = []

      channels_raw.each do |conv_raw|
        next unless conv_raw['view_count'] > 50

        res = []
        hours_usable.each do |hour|
          res << (conv_raw['view_per_hour'][hour] || 0)
        end
        file.puts "#{CsvExporter.sanitize_data(conv_raw['title'], DELIMITER)}#{DELIMITER}#{res.join(DELIMITER)}"
      end
    end
  end

  def self.export_views_per_day_of_week(channels_raw, output_path)
    views_per_day_of_week = Array.new(7) { Hash.new(0) }

    channels_raw.each do |conv_raw|
      conv_raw['view_per_day'].each do |date, msg_count|
        day_of_week = Date.parse(date).wday
        views_per_day_of_week[day_of_week][conv_raw['title']] += msg_count
      end
    end

    # Keep only channels with more than 50 views
    channel_list = channels_raw.select do |c|
      c['view_count'] > 50
    end.sort_by do |c|
      -c['view_count']
    end.map do |c|
      c['title']
    end
    puts "Keeping #{channel_list.count} threads for the day of the week graph."

    File.open(File.join(output_path, 'view_per_day_of_week.json'), 'w') do |file|
      file.puts JSON.dump(views_per_day_of_week)
    end
    days = %w(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)
    File.open(File.join(output_path, 'view_per_day_of_week.csv'), 'w') do |file|
      file.puts "Date#{DELIMITER}#{channel_list.map { |thread_name| CsvExporter.sanitize_data(thread_name, DELIMITER) }.join(DELIMITER)}"
      lines = []

      views_per_day_of_week.each_with_index do |threads, day|
        res = []
        channel_list.each do |thread|
          res << (threads[thread] || 0)
        end
        file.puts "#{days[day]}#{DELIMITER}#{res.join(DELIMITER)}"
      end
    end
  end
end
