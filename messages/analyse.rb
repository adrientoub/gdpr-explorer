require 'json'
require_relative '../common/types'
require_relative '../common/csv_exporter'

ANALYSE_CACHE_PATH = 'message_analysed_cache.json'

class MessagesAnalyse
  def self.analyse(json, output_path)
    raw_payload = load_or_parse(json, output_path)
    conversations_raw = raw_payload['conversations']

    sort!(conversations_raw)

    export_message_count(conversations_raw, output_path)
    export_messages_per_month(conversations_raw, output_path)
    export_messages_per_hour(conversations_raw, output_path)
    export_messages_per_day_of_week(conversations_raw, output_path)
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
    index = Index.from_json(json)

    conversations_raw = []
    raw_payload = {
      'version' => CURRENT_VERSION,
      'conversations' => conversations_raw
    }

    index.conversations.each do |conversation|
      loaded_conversation = conversation.load_conversation(output_path)
      conv_raw_metadata = {
        'title' => loaded_conversation.conversation_name,
        'participants' => loaded_conversation.participants,
        'message_count' => 0,
        'reaction_count' => 0,
        'message_per_participant' => Hash.new(0),
        'reaction_per_participant' => {},
        'message_per_day' => Hash.new(0),
        'message_per_hour' => Hash.new(0)
      }
      conversations_raw << conv_raw_metadata

      loaded_conversation.messages.each do |message|
        conv_raw_metadata['message_count'] += 1
        conv_raw_metadata['message_per_participant'][message.sender] += 1
        message.reactions&.each do |reaction|
          conv_raw_metadata['reaction_count'] += 1
          conv_raw_metadata['reaction_per_participant'][reaction.sender] ||= Hash.new(0)
          conv_raw_metadata['reaction_per_participant'][reaction.sender]['total_count'] += 1
          conv_raw_metadata['reaction_per_participant'][reaction.sender][reaction.reaction] += 1
        end
        datetime = message.date.to_s
        date = datetime[0...10]
        hour = datetime[11..12]
        conv_raw_metadata['message_per_day'][date] += 1
        conv_raw_metadata['message_per_hour']["h#{hour}"] += 1
      end
    end

    File.open(File.join(output_path, ANALYSE_CACHE_PATH), 'w') do |file|
      file.puts JSON.dump(raw_payload)
    end

    raw_payload
  end

  def self.sort!(conversations_raw)
    # Sort highest message count first
    conversations_raw.sort_by! do |conv_raw|
      conv_raw['message_count']
    end.reverse!
  end

  def self.export_message_count(conversations_raw, output_path)
    exportable_data = []
    File.open(File.join(output_path, 'message_count.txt'), 'w') do |file|
      conversations_raw.each do |conv_raw|
        file.puts "#{conv_raw['message_count']} messages - #{conv_raw['title']} (#{conv_raw['reaction_count'] || 0} reactions)"
        reaction_per_participant = conv_raw['reaction_per_participant']
        conv_raw['message_per_participant'].to_a.sort_by { |participant, count| -count }.each do |participant, message_count|
          different_reaction_count = reaction_per_participant[participant]&.count
          if !different_reaction_count.nil? && different_reaction_count > 2
            file.puts "  #{message_count} messages - #{participant}"
            reaction_per_participant[participant].sort_by { |r, c| -c }.each do |reaction, count|
              if reaction == 'total_count'
                file.puts "    Total reaction count #{count}"
              else
                file.puts "    #{reaction} #{count}"
              end
            end
          else
            file.puts "  #{message_count} messages - #{participant} (#{reaction_per_participant.dig(participant, 'total_count') || 0} reactions)"
          end
        end
        exportable_data << [conv_raw['title'], conv_raw['message_count']]
      end
    end

    puts "Export message count to CSV."
    File.open(File.join(output_path, 'message_count.csv'), 'w') do |file|
      CsvExporter.export_csv(file, exportable_data, %w(conversation_name message_count), DELIMITER)
    end
  end

  def self.export_messages_per_month(conversations_raw, output_path)
    messages_per_month = Hash.new

    conversations_raw.each do |conv_raw|
      conv_raw['message_per_day'].each do |date, msg_count|
        month_date = date[0..-4]
        messages_per_month[month_date] ||= Hash.new(0)
        messages_per_month[month_date][conv_raw['title']] += msg_count
      end
    end

    # Keep only conversations with more than 50 messages
    thread_list = conversations_raw.select do |c|
      c['message_count'] > 50
    end.sort_by do |c|
      -c['message_count']
    end.map do |c|
      c['title']
    end
    puts "Keeping #{thread_list.count} threads for the per month graph."

    File.open(File.join(output_path, 'message_per_month.json'), 'w') do |file|
      file.puts JSON.dump(messages_per_month)
    end
    File.open(File.join(output_path, 'message_per_month.csv'), 'w') do |file|
      file.puts "Date#{DELIMITER}#{thread_list.map { |thread_name| CsvExporter.sanitize_data(thread_name, DELIMITER) }.join(DELIMITER)}"
      lines = []

      dates = messages_per_month.keys.sort
      generate_all_months(dates[0], dates[-1]).each do |date|
        threads = messages_per_month[date] || {}
        res = []
        thread_list.each do |thread|
          res << (threads[thread] || 0)
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

  def self.export_messages_per_hour(conversations_raw, output_path)
    hours = (0..23).to_a
    hours_usable = hours.map { |hour| "h#{hour.to_s.rjust(2, '0')}" }.to_a
    File.open(File.join(output_path, 'message_per_hour.csv'), 'w') do |file|
      file.puts "Thread name#{DELIMITER}#{hours.join(DELIMITER)}"
      lines = []

      conversations_raw.each do |conv_raw|
        next unless conv_raw['message_count'] > 50

        res = []
        hours_usable.each do |hour|
          res << (conv_raw['message_per_hour'][hour] || 0)
        end
        file.puts "#{CsvExporter.sanitize_data(conv_raw['title'], DELIMITER)}#{DELIMITER}#{res.join(DELIMITER)}"
      end
    end
  end

  def self.export_messages_per_day_of_week(conversations_raw, output_path)
    messages_per_day_of_week = Array.new(7) { Hash.new(0) }

    conversations_raw.each do |conv_raw|
      conv_raw['message_per_day'].each do |date, msg_count|
        day_of_week = Date.parse(date).wday
        messages_per_day_of_week[day_of_week][conv_raw['title']] += msg_count
      end
    end

    # Keep only conversations with more than 50 messages
    thread_list = conversations_raw.select do |c|
      c['message_count'] > 50
    end.sort_by do |c|
      -c['message_count']
    end.map do |c|
      c['title']
    end
    puts "Keeping #{thread_list.count} threads for the day of the week graph."

    File.open(File.join(output_path, 'message_per_day_of_week.json'), 'w') do |file|
      file.puts JSON.dump(messages_per_day_of_week)
    end
    days = %w(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)
    File.open(File.join(output_path, 'message_per_day_of_week.csv'), 'w') do |file|
      file.puts "Date#{DELIMITER}#{thread_list.map { |thread_name| CsvExporter.sanitize_data(thread_name, DELIMITER) }.join(DELIMITER)}"
      lines = []

      messages_per_day_of_week.each_with_index do |threads, day|
        res = []
        thread_list.each do |thread|
          res << (threads[thread] || 0)
        end
        file.puts "#{days[day]}#{DELIMITER}#{res.join(DELIMITER)}"
      end
    end
  end
end
