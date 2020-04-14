class DirSize
  def self.all_file_sizes(dir_path)
    Dir.glob(File.join(dir_path, '**', '*'))
      .map{ |f| File.size(f) }
      .inject(:+)
  end
end
