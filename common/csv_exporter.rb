class CsvExporter
  def self.export_csv(file, content, headers)
    if content.is_a? Array
      file.puts headers.join(',')
      content.each do |line|
        file.puts line.join(',')
      end
    else
      raise "Not supported content of type #{content.class}"
    end
  end
end
