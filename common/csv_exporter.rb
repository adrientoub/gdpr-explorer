class CsvExporter
  def self.export_csv(file, content, headers, delimiter)
    if content.is_a? Array
      file.puts headers.join(delimiter)
      content.each do |line|
        file.puts line.join(delimiter)
      end
    else
      raise "Not supported content of type #{content.class}"
    end
  end

  # remove delimiter from data
  def self.sanitize_data(data, delimiter)
    data.gsub(delimiter, ':')
  end
end
