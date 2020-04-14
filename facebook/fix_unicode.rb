class FixUnicode
  def self.fix(input)
    output = []
    unicode = []
    in_unicode = false
    had_slash = false

    to_find = '\\u00'.bytes
    bytes = input.bytes
    bytes.each do |char|
      if in_unicode
        unicode << char
        if unicode.length == 4
          output << unicode.pack('C*').to_i(16)
          in_unicode = false
        end
      elsif had_slash
        had_slash = false
        if char == to_find[1]
          in_unicode = true
          unicode = []
        else
          output << to_find[0]
          output << char
        end
      elsif char == to_find[0]
        had_slash = true
      else
        output << char
      end
    end
    if had_slash
      output << to_find[0]
    end

    packed = output.pack('C*')
    packed
  end
end
