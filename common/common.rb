CURRENT_VERSION = '0.0.5'
INDEX_PATH = 'index.json'
DELIMITER = ';'

class Common
  def self.read_from_index(output_directory)
    index_path = File.join(output_directory, INDEX_PATH)
    if File.exists?(index_path)
      index = JSON.parse(File.read(index_path))
      if index['version'] != CURRENT_VERSION
        puts "Found an index on #{index['version']}, need #{CURRENT_VERSION}. Reloading."
      else
        puts "Found a viable index, reusing it."
        return index
      end
    end

    nil
  end
end
