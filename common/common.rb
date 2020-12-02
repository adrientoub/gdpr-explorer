CURRENT_VERSION = '0.0.6'

DELIMITER = ';'

INDEX_PATH = 'index.json'
ANALYSE_CACHE_PATH = 'analyse_cache.json'

class Common
  MESSAGES_TYPE = 'messages'
  MUSIC_TYPE = 'music'
  VIDEOS_TYPE = 'videos'

  def self.read_from_index(type, output_directory)
    load_from_cache(type, INDEX_PATH, 'index', output_directory)
  end

  # type is the content type currently handled (messages, videos...)
  # cache_filename is the filename from which the cache should be loaded
  # cache_name is the user friendly name of this cache
  def self.load_from_cache(type, cache_filename, cache_name, output_directory)
    index_path = File.join(output_directory, cache_filename)
    if File.exists?(index_path)
      index = JSON.parse(File.read(index_path))
      if index.is_a?(Hash) && index['version'] != required_version(type)
        puts "Found a #{cache_name} cache on #{index['version']}, need #{required_version(type)}. Reloading."
      else
        puts "Found a viable #{cache_name} cache, reusing it."
        return index
      end
    end

    nil
  end

  def self.get_force_from_argv
    if ARGV.length >= 3
      if ARGV[2] == '-f' || ARGV[2] == '--force'
        return true
      end
    end
    return false
  end

  # type is the content type currently handled (messages, videos...)
  def self.required_version(type)
    "#{CURRENT_VERSION}-#{type}"
  end
end
