require 'json'
require_relative '../common/common'
require_relative '../common/csv_exporter'
require_relative './types'

MIN_LISTEN_FOR_EXPORT = 10

class MusicAnalyse
  def self.analyse(json, output_path, force)
    raw_payload = load_or_parse(json, output_path, force)
    artists_raw = raw_payload['artists']

    sort!(artists_raw)

    export_listen_count(artists_raw, output_path)
    export_views_per_month(artists_raw, output_path)
    export_views_per_hour(artists_raw, output_path)
    export_views_per_day_of_week(artists_raw, output_path)
  end

  private

  def self.load_or_parse(json, output_path, force)
    raw_payload = Common.load_from_cache(Common::MUSIC_TYPE, ANALYSE_CACHE_PATH, 'analyse', output_path) unless force
    raw_payload ||= parse(json, output_path)
  end

  def self.parse(json, output_path)
    index = MusicIndex.from_json(json)

    artists_raw = []
    raw_payload = {
      'version' => Common.required_version(Common::MUSIC_TYPE),
      'artists' => artists_raw
    }

    index.artists.each do |artist|
      loaded_artist = artist.load_artist(output_path)
      artist_raw_metadata = {
        'name' => loaded_artist.artist_name,
        'listen_count' => 0,
        'listen_duration' => 0,
        'listen_per_day' => Hash.new(0),
        'listen_per_hour' => Hash.new(0)
      }
      artists_raw << artist_raw_metadata

      loaded_artist.listens.each do |listen|
        artist_raw_metadata['listen_count'] += 1
        artist_raw_metadata['listen_duration'] += listen.play_duration
        datetime = listen.date.to_s
        date = datetime[0...10]
        hour = datetime[11..12]
        artist_raw_metadata['listen_per_day'][date] += 1
        artist_raw_metadata['listen_per_hour']["h#{hour}"] += 1
      end
    end

    File.open(File.join(output_path, ANALYSE_CACHE_PATH), 'w') do |file|
      file.puts JSON.dump(raw_payload)
    end

    raw_payload
  end

  def self.sort!(artists_raw)
    # Sort highest view count first
    artists_raw.sort_by! do |art_raw|
      art_raw['listen_count']
    end.reverse!
  end

  def self.export_listen_count(artists_raw, output_path)
    exportable_data = []
    File.open(File.join(output_path, 'listen_count.txt'), 'w') do |file|
      artists_raw.each do |art_raw|
        duration_time = Time.at(art_raw['listen_duration'] / 1000).utc
        duration_days = duration_time.strftime('%j').to_i - 1
        duration_days_print = "#{duration_days} days - " if duration_days > 0
        duration_print = "#{duration_days_print}#{duration_time.strftime("%H:%M:%S")}"
        file.puts "#{art_raw['listen_count']} listens - #{art_raw['name']} - #{duration_print}"
        exportable_data << [art_raw['name'], art_raw['listen_count'], duration_print]
      end
    end

    puts "Export view count to CSV."
    File.open(File.join(output_path, 'listen_count.csv'), 'w') do |file|
      CsvExporter.export_csv(file, exportable_data, %w(name listen_count listen_duration), DELIMITER)
    end
  end

  def self.export_views_per_month(artists_raw, output_path)
    views_per_month = Hash.new

    artists_raw.each do |art_raw|
      art_raw['listen_per_day'].each do |date, msg_count|
        month_date = date[0..-4]
        views_per_month[month_date] ||= Hash.new(0)
        views_per_month[month_date][art_raw['name']] += msg_count
      end
    end

    # Keep only artists with more than MIN_LISTEN_FOR_EXPORT listens
    artist_list = create_artist_list(artists_raw)

    File.open(File.join(output_path, 'listen_per_month.json'), 'w') do |file|
      file.puts JSON.dump(views_per_month)
    end
    File.open(File.join(output_path, 'listen_per_month.csv'), 'w') do |file|
      file.puts "Date#{DELIMITER}#{artist_list.map { |artist_name| CsvExporter.sanitize_data(artist_name, DELIMITER) }.join(DELIMITER)}"
      lines = []

      dates = views_per_month.keys.sort
      generate_all_months(dates[0], dates[-1]).each do |date|
        art = views_per_month[date] || {}
        res = []
        artist_list.each do |artist_name|
          res << (art[artist_name] || 0)
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

  def self.export_views_per_hour(artists_raw, output_path)
    hours = (0..23).to_a
    hours_usable = hours.map { |hour| "h#{hour.to_s.rjust(2, '0')}" }.to_a
    File.open(File.join(output_path, 'listen_per_hour.csv'), 'w') do |file|
      file.puts "Artist name#{DELIMITER}#{hours.join(DELIMITER)}"
      lines = []

      artists_raw.each do |art_raw|
        next unless art_raw['listen_count'] > MIN_LISTEN_FOR_EXPORT

        res = []
        hours_usable.each do |hour|
          res << (art_raw['listen_per_hour'][hour] || 0)
        end
        file.puts "#{CsvExporter.sanitize_data(art_raw['name'], DELIMITER)}#{DELIMITER}#{res.join(DELIMITER)}"
      end
    end
  end

  def self.export_views_per_day_of_week(artists_raw, output_path)
    views_per_day_of_week = Array.new(7) { Hash.new(0) }

    artists_raw.each do |art_raw|
      art_raw['listen_per_day'].each do |date, msg_count|
        day_of_week = Date.parse(date).wday
        views_per_day_of_week[day_of_week][art_raw['name']] += msg_count
      end
    end

    artist_list = create_artist_list(artists_raw)

    File.open(File.join(output_path, 'listen_per_day_of_week.json'), 'w') do |file|
      file.puts JSON.dump(views_per_day_of_week)
    end
    days = %w(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)
    File.open(File.join(output_path, 'listen_per_day_of_week.csv'), 'w') do |file|
      file.puts "Date#{DELIMITER}#{artist_list.map { |artist_name| CsvExporter.sanitize_data(artist_name, DELIMITER) }.join(DELIMITER)}"
      lines = []

      views_per_day_of_week.each_with_index do |threads, day|
        res = []
        artist_list.each do |thread|
          res << (threads[thread] || 0)
        end
        file.puts "#{days[day]}#{DELIMITER}#{res.join(DELIMITER)}"
      end
    end
  end

  def self.create_artist_list(artists_raw)
    # Keep only artists with more than MIN_LISTEN_FOR_EXPORT listens
    artist_list = artists_raw.select do |c|
      c['listen_count'] > MIN_LISTEN_FOR_EXPORT
    end.sort_by do |c|
      -c['listen_count']
    end.map do |c|
      c['name']
    end
    puts "Keeping #{artist_list.count} artists for the graphs."

    artist_list
  end
end
