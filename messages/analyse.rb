require 'json'
require_relative './types'
require_relative '../common/csv_exporter'

class MessagesAnalyse
  def self.analyse(json, output_path, force)
    raw_payload = load_or_parse(json, output_path, force)
    conversations_raw = raw_payload['conversations']

    sort!(conversations_raw)

    export_message_count(conversations_raw, output_path)
    export_messages_per_month(conversations_raw, output_path)
    export_messages_per_hour(conversations_raw, output_path)
    export_messages_per_day_of_week(conversations_raw, output_path)
    export_yearly_rewind(conversations_raw, output_path)
  end

  private

  def self.load_or_parse(json, output_path, force)
    raw_payload = Common.load_from_cache(Common::MESSAGES_TYPE, ANALYSE_CACHE_PATH, 'analyse', output_path) unless force
    raw_payload ||= parse(json, output_path)
  end

  def self.parse(json, output_path)
    index = MessagesIndex.from_json(json)

    conversations_raw = []
    raw_payload = {
      'version' => Common.required_version(Common::MESSAGES_TYPE),
      'conversations' => conversations_raw,
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
        'message_per_day_per_participant' => Hash.new { |hash, key|
          hash[key] = Hash.new(0)
        },
        'message_per_hour' => Hash.new(0),
        'message_per_year' => Hash.new { |hash, key|
          hash[key] = {
            'message_per_participant' => Hash.new(0),
            'reaction_per_participant' => {},
          }
        }
      }
      conversations_raw << conv_raw_metadata

      loaded_conversation.messages.each do |message|
        conv_raw_metadata['message_count'] += 1
        datetime = message.date.to_s
        date = datetime[0...10]
        hour = datetime[11..12]
        year = datetime[0...4]

        conv_raw_metadata['message_per_participant'][message.sender] += 1
        conv_raw_metadata['message_per_year'][year]['message_per_participant'][message.sender] += 1
        message.reactions&.each do |reaction|
          conv_raw_metadata['reaction_count'] += 1
          conv_raw_metadata['message_per_year'][year]['reaction_per_participant'][reaction.sender] ||= Hash.new(0)
          conv_raw_metadata['message_per_year'][year]['reaction_per_participant'][reaction.sender]['total_count'] += 1
          conv_raw_metadata['message_per_year'][year]['reaction_per_participant'][reaction.sender][reaction.reaction] += 1
          conv_raw_metadata['reaction_per_participant'][reaction.sender] ||= Hash.new(0)
          conv_raw_metadata['reaction_per_participant'][reaction.sender]['total_count'] += 1
          conv_raw_metadata['reaction_per_participant'][reaction.sender][reaction.reaction] += 1
        end
        conv_raw_metadata['message_per_day'][date] += 1
        conv_raw_metadata['message_per_day_per_participant'][date][message.sender] += 1
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
        print_reactions = (conv_raw['reaction_count'] || 0) != 0

        if print_reactions
          file.puts "#{conv_raw['message_count']} messages - #{conv_raw['title']} (#{conv_raw['reaction_count'] || 0} reactions)"
        else
          file.puts "#{conv_raw['message_count']} messages - #{conv_raw['title']}"
        end
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
            if print_reactions
              file.puts "  #{message_count} messages - #{participant} (#{reaction_per_participant.dig(participant, 'total_count') || 0} reactions)"
            else
              file.puts "  #{message_count} messages - #{participant}"
            end
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

  def self.export_yearly_rewind(conversations_raw, output_path)
    exportable_data = []
    message_per_person_per_year = Hash.new { |hash, key|
      hash[key] = Hash.new(0)
    }
    reaction_per_person_per_year = Hash.new { |hash, key|
      hash[key] = Hash.new { |h, k|
        h[k] = Hash.new(0)
      }
    }

    # Find out who the dumps is from by finding out who is in all conversations
    person_per_conversation = Hash.new(0)
    conversations_raw.each do |conv_raw|
      conv_raw['participants'].each do |p|
        person_per_conversation[p] += 1
      end
    end
    user_name = person_per_conversation.to_a.sort_by(&:last).last.first

    message_per_day = Hash.new(0)
    received_message_per_day = Hash.new(0)
    sent_message_per_day = Hash.new(0)

    conversations_raw.each do |conv_raw|
      conv_raw['message_per_day'].each do |day, count|
        message_per_day[day] += count
        received_message_per_day[day] += count - (conv_raw.dig('message_per_day_per_participant', day, user_name) || 0)
        sent_message_per_day[day] += (conv_raw.dig('message_per_day_per_participant', day, user_name) || 0)
      end

      conv_raw['message_per_year'].each do |year, mpy|
        mpy['message_per_participant'].each do |participant, count|
          message_per_person_per_year[year][participant] += count
        end
        mpy['reaction_per_participant'].each do |participant, counts|
          counts.each do |count_name, count|
            reaction_per_person_per_year[year][participant][count_name] += count
          end
        end
      end
    end
    File.open(File.join(output_path, 'message_per_person_per_year.json'), 'w') do |file|
      file.puts JSON.dump(message_per_person_per_year)
    end
    File.open(File.join(output_path, 'reaction_per_person_per_year.json'), 'w') do |file|
      file.puts JSON.dump(reaction_per_person_per_year)
    end

    message_per_person_per_year.each do |year, person_count|
      reactions = Hash.new(0)
      reaction_per_person_per_year[year].each do |_, counts|
        counts.each do |react, cnt|
          reactions[react] += cnt
        end
      end
      reactions = reactions.to_a.sort_by { |a| -a[1] }.map(&:first)

      File.open(File.join(output_path, "message_#{year}.csv"), 'w') do |file|
        file.puts "Name#{DELIMITER}Count#{DELIMITER}#{reactions.join(DELIMITER)}"
        person_count.to_a.sort_by { |a| -a[1] }.each do |a|
          s = ''
          reactions.each do |r|
            s += "#{DELIMITER}#{reaction_per_person_per_year[year][a[0]][r]}"
          end
          file.puts "#{a[0]}#{DELIMITER}#{a[1]}#{s}"
        end
      end
    end

    last_year = message_per_person_per_year.keys.to_a.sort[-1]
    puts "In #{last_year} you (#{user_name})"
    puts "* Received messages from #{message_per_person_per_year[last_year].count} persons"
    sent_message_count = message_per_person_per_year[last_year][user_name]
    puts "* Sent #{sent_message_count} messages"
    received_messages = message_per_person_per_year[last_year].sum { |k, v| v } - sent_message_count
    puts "* Received #{received_messages} messages"
    biggest_day = message_per_day.sort_by { |k, v| -v }.find { |k, v| k.include?(last_year) }
    puts "* The biggest day of your year was #{biggest_day.first} where you received/sent #{biggest_day.last} messages"
    biggest_day_received = received_message_per_day.sort_by { |k, v| -v }.find { |k, v| k.include?(last_year) }
    puts "* The day when you received the most messages was #{biggest_day_received.first} where you received #{biggest_day_received.last} messages"
    biggest_day_sent = sent_message_per_day.sort_by { |k, v| -v }.find { |k, v| k.include?(last_year) }
    puts "* The day when you sent the most messages of your year was #{biggest_day_sent.first} where you sent #{biggest_day_sent.last} messages"
    puts
    # Keep 5 best friends by taking the top 6 persons who sent messages and removing the name of the current user
    best_friends = message_per_person_per_year[last_year].to_a.sort_by(&:last).last(6).reverse.map(&:first)
    best_friends.delete(user_name)
    puts "The persons who sent you the most messages were #{best_friends.join(', ')}"
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

    dates = messages_per_month.keys.sort
    month_list = generate_all_months(dates[0], dates[-1])

    File.open(File.join(output_path, 'message_per_month.csv'), 'w') do |file|
      file.puts "Date#{DELIMITER}#{thread_list.map { |thread_name| CsvExporter.sanitize_data(thread_name, DELIMITER) }.join(DELIMITER)}"
      lines = []

      month_list.each do |date|
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
