#! /usr/bin/env ruby

require 'json'
require 'date'
require_relative '../common/csv_exporter'

filename = ARGV[0] || 'likes.json'

json = JSON.parse(File.read(filename))
puts "Parsed json #{filename}"

raw_data = {}
json['media_likes'].each do |date, username|
  raw_data[username] ||= []
  raw_data[username] << DateTime.parse(date).to_date.to_s
end

puts "Dumping raw data to file"
File.open('likes_raw_data.json', 'w') do |file|
  file.puts JSON.dump(raw_data)
end

puts "Finding most liked accounts..."
like_count = raw_data.map do |k, v|
  [k, v.count]
end
# sort from most liked to least liked
like_count.sort_by! { |_, like_count| -like_count }
puts "10 Most liked accounts"
like_count[0..10].each do |username, like_count|
  puts "#{like_count} - #{username}"
end
puts "Liked #{like_count.count} different accounts."

puts "Finding most liked accounts per year..."
like_per_year = {}
raw_data.each do |username, all_like_dates|
  all_like_dates.each do |date|
    year = date[0..3]
    like_per_year[year] ||= {}
    like_per_year[year][username] ||= 0
    like_per_year[year][username] += 1
  end
end
puts "dumping like count raw data"
File.open('like_count.json', 'w') do |file|
  file.puts JSON.dump(like_count)
end
File.open("like_count.csv", 'w') do |file|
  CsvExporter.export_csv(file, like_count, %w(username count))
end

# sort from most liked to least liked
likes_per_year_sorted = like_per_year.to_a.sort_by { |year, _| -year.to_i }
likes_per_year_sorted.each do |year, like_count_for_year|
  like_count_for_year_sorted = like_count_for_year.to_a.sort_by { |_, like_count| -like_count }
  puts "10 Most liked accounts in #{year}"
  like_count_for_year_sorted[0...10].each do |username, like_count|
    puts "#{like_count} - #{username}"
  end
  puts "Liked #{like_count_for_year_sorted.count} different accounts in #{year}."

  puts "Dumping like count #{year} raw data"
  File.open("like_count_#{year}.json", 'w') do |file|
    file.puts JSON.dump(like_count_for_year_sorted)
  end
  File.open("like_count_#{year}.csv", 'w') do |file|
    CsvExporter.export_csv(file, like_count_for_year_sorted, %w(username count))
  end
end
