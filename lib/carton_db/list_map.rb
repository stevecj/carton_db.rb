require 'fileutils'
require 'digest'
require 'cgi'

module CartonDb

  class ListMap
    def initialize(name)
      self.name = name
      FileUtils.mkpath name
    end

    def empty?
      each_data_file do |file, stat|
        return false unless stat.zero?
      end
      true
    end

    def []=(key, array_val)
      key = key.to_s
      file = file_path_for(key)
      stat = File.stat(file) if File.file?(file)
      if stat.nil? or stat.zero?
        concat_to key, array_val
      else
        esc_key = CGI.escape(key)
        new_file = "#{file}.new"
        File.open new_file, 'w' do |nf_io|
          File.open file do |io|
            io.each_line do |line|
              l_esc_key, l_esc_element = line.strip.split("\t", 2)
              nf_io.print line unless l_esc_key == esc_key
            end
          end
          element_count = 0
          array_val.each do |element|
            element_count += 1
            nf_io.puts "#{CGI.escape(key)}\t#{CGI.escape(element)}"
          end
          if element_count.zero?
            nf_io.puts CGI.escape(key)
          end
        end
        File.unlink file
        File.rename new_file, file
      end
    end

    def [](key)
      key = key.to_s
      file = file_path_for(key)
      return nil unless File.file?(file)
      esc_key = CGI.escape(key)
      ary = nil
      File.open file do |io|
        io.each_line do |line|
          line.strip!
          l_esc_key, l_esc_element = line.split("\t", 2)
          next ary unless l_esc_key == esc_key
          ary ||= []
          next unless l_esc_element
          ary << CGI.unescape(l_esc_element)
        end
      end
      ary
    end

    def delete(key)
      key = key.to_s
      file = file_path_for(key)
      stat = File.stat(file) if File.file?(file)
      if stat.nil? or stat.zero?
        concat_to key, array_val
      else
        esc_key = CGI.escape(key)
        new_file = "#{file}.new"
        File.open new_file, 'w' do |nf_io|
          File.open file do |io|
            io.each_line do |line|
              l_esc_key, l_esc_element = line.strip.split("\t", 2)
              nf_io.print line unless l_esc_key == esc_key
            end
          end
        end
        File.unlink file
        File.rename new_file, file
      end
    end

    def append_to(key, element)
      key = key.to_s
      file = file_path_for(key)
      FileUtils.mkpath File.dirname(file)
      File.open file, 'a' do |io|
        io.puts "#{CGI.escape(key)}\t#{CGI.escape(element)}"
      end
    end

    def concat_to(key, elements)
      key = key.to_s
      file = file_path_for(key)
      FileUtils.mkpath File.dirname(file)
      File.open file, 'a' do |io|
        element_count = 0
        elements.each do |element|
          element_count += 1
          io.puts "#{CGI.escape(key)}\t#{CGI.escape(element)}"
        end
        if element_count.zero?
          io.puts CGI.escape(key)
        end
      end
    end

    private

    attr_accessor :name

    def file_path_for(key)
      hex_hashcode = Digest::MD5.hexdigest(key)[0..3]
      subdir = "#{hex_hashcode[0..1].to_i(16) % 128}"
      filename = "#{hex_hashcode[2..3].to_i(16) % 128}.txt"
      File.join(name, subdir, filename)
    end

    def each_data_file
      each_subdir do |subdir|
        each_data_file_in subdir do |file, stat|
          yield file, stat
        end
      end
    end

    def each_subdir
      Dir.entries(name).each do |e|
        next unless e =~ /^\d{1,3}$/
        subdir = File.join(name, e)
        next unless File.directory?(subdir)
        yield subdir
      end
    end

    def each_data_file_in(dir)
      Dir.entries(dir).each do |e|
        next unless e =~ /^\d{1,3}[.]txt$/
        file = File.join(dir, e)
        stat = File.stat(file)
        next unless stat.file?
        yield file, stat
      end
    end
  end

end
