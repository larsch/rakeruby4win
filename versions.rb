require 'fileutils'
include FileUtils
def which(filename)
  if pathext = ENV['PATHEXT']
    pathexts = pathext.split(File::PATH_SEPARATOR)
    haspathext = pathexts.find { |ext|
      filename.size >= ext.size &&
      filename[-ext.size..-1].downcase == ext.downcase }
  else
    pathexts = [""]
    haspathext = true
  end

  ENV['PATH'].split(File::PATH_SEPARATOR).each { |path|
    fullpath = File.join(path, filename)
    if haspathext
      return fullpath if File.exist?(fullpath)
    end
    pathexts.each { |ext|
      fullpathext = fullpath + ext
      return fullpathext if File.exist?(fullpathext)
    }
  }
  return nil
end

homepath = 'd:/src/rubybuild/tmpinstall/bin'

PF = " * "

puts "Ruby #{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}"

puts "\n3rd party:\n\n"

require 'dl'
require 'openssl'
puts PF + OpenSSL::OPENSSL_VERSION
puts PF + DL.dlopen(Dir.glob(File.join(homepath, "gdbm*.dll"))[0])['gdbm_version'].ptr.to_s
puts PF + DL.dlopen(File.join(homepath, 'pdcurses.dll'))['curses_version','S'].call[0]

dl = DL.dlopen('root/prereq/bin/libiconv2.dll')['_libiconv_version']
dl.struct!('I', :i)
puts sprintf("#{PF}libiconv %d.%d", dl[:i] >> 8, dl[:i] & 0xFF)
require 'readline'
puts "#{PF}Readline " + Readline::VERSION

require 'rubygems'

puts "\nGems:\n\n"
puts Gem.source_index.search("").map { |g| PF + g.name + " " + g.version.to_s }
