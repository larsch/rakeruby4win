module Net
  autoload :HTTP, 'net/http'
end
autoload :Hpricot, 'hpricot'
autoload :URI, 'uri'
require 'rubygems'
gem 'hpricot'
autoload :OpenStruct, 'ostruct'

def make_path(path)
  elems = path.split(File::SEPARATOR)
  (1..elems.size).each { |parts|
    p = elems[0,parts].join(File::SEPARATOR)
    if File.exist?(p)
      if not File.directory?(p)
        raise "Can't create #{path}: #{p} exist and is not a directory"
      end
    else
      Dir.mkdir(p)
    end
  }
end

def sys_k(*cmd)
  puts cmd.join(' ')
  system(*cmd)
end
def sys(*cmd)
  sys_k(*cmd) or raise "External command failed: #{$?.inspect}"
end

=begin
def copy_file(src, dst)
  File.open(src, "rb") { |fin|
    File.open(dst, "wb") { |fout|
      while data = fin.read(0x10000)
        fout.write(data)
      end
    }
  }
end
=end
def extract(path)
  basename = File.basename(path)
  copy_file(path, basename)
  case path
  when /\.tar\.bz2$/i
    tar = basename.
      gsub(/\.bz2$/,'')
    File.unlink(tar) if File.exist?(tar)
    sys("bzip2 -d #{basename}")
    sys("tar xf #{tar}")
    File.unlink(tar) if File.exist?(tar)
  when /\.tar\.gz$/i
    tar = basename.gsub(/\.gz$/,'')
    File.unlink(tar) if File.exist?(tar)
    sys("gzip -d #{basename}")
    sys("tar xf #{tar}")
    File.unlink(tar) if File.exist?(tar)
  when /\.zip$/i
    sys("unzip -o -q #{basename}")
  else
    raise "Don't know how to extract #{basename}"
  end
  File.unlink(basename) if File.exist?(basename)
end
def makemsyspath(path)
  path.sub(/^([a-z]):/i, "/\\1")
end

def msys_sh(cmd)
  bash = File.join(MSYS_ROOT, 'bin', 'bash.exe')
  path = ENV['PATH']
  #ENV['PATH'] = ''
  sys("#{bash} --login -c \"cd #{makemsyspath(Dir.pwd)};#{cmd}\"")
  ENV['PATH'] = path
end

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

def formattimedelta(delta)
  seconds_dec = delta % 60.0
  seconds = delta.to_i
  minutes = seconds / 60
  hours = seconds / (60*60)
  minutes_part = (delta % (60 * 60)) / 60
  seconds_part = delta % 60
  s = ""
  s << sprintf("%dh", hours) if hours > 0
  s << sprintf("%dm", minutes_part) if hours > 0 or minutes > 0
  s << sprintf("%.3fs", seconds_dec)
  return s
end


def download_http(uri, path)
  Net::HTTP.start(uri.host, uri.port) do |http|
    puts "GET #{uri}"
    r = http.request_get(uri.request_uri) do |response|
      case response
      when Net::HTTPSuccess
        mkdir_p(File.dirname(path))
        File.open(path, "wb") { |f|
          response.read_body do |ch|
            f << ch
          end
        }
      when Net::HTTPRedirection
        download(URI.parse(response['location']), path)
      else
        raise "Unexpected response #{response.inspect}"
      end
    end
  end
end

def download_ftp(uri, path)
  Net::FTP.open(uri.host, 'anonymous', 'nil') do |ftp|
    puts "FTP RETR #{uri}"
    ftp.chdir(File.dirname(uri.path))
    ftp.get(File.basename(uri.path), path, 4096)
  end
end

def download(uri, path)
  case uri
  when URI::HTTP
    download_http(uri, path)
  when URI::FTP
    download_ftp(uri, path)
  else
    raise "Unhandled URI scheme: #{uri}"
  end
end

def determineurl(uri)
  begin
    puts "HEAD #{uri}"
    Net::HTTP.start(uri.host, uri.port) do |http|
      r, d = http.head(uri.request_uri)
      case r
      when Net::HTTPRedirection
        newuri = URI.join(uri.to_s, r['location'])
        determineurl(newuri)
      when Net::HTTPSuccess
        return uri
      end
    end
  end
end


class Version < Array
  include Comparable
  
  def initialize(str)
    parts = str.scan(/\d+|[a-z]+/).map { |x| (x =~ /^\d+$/) ? x.to_i : x }
    super(parts)
  end

  def <=>(other)
    each_with_index { |e,i|
      if i >= other.size
        return 1
      else
        c = e <=> other[i]
        if c.nil?
          c = e.to_s <=> other[i].to_s
        end
        return c unless c == 0
      end
    }
    return -1 if other.size > size
    return 0
  end
end

def Version(str)
  Version.new(str)
end

def get_doc_do(url)
  uri = URI.parse(url)
  Net::HTTP.start(uri.host, uri.port) do |http|
    puts "GET #{uri}"
    r, d = http.get(uri.request_uri)
    case r
    when Net::HTTPSuccess
      return Hpricot.parse(d)
    when Net::HTTPRedirection
      return get_doc_do(r['location'])
    else
      raise "Unexpected HTTP response: #{r}"
    end
  end
end

def get_doc(url)
  $cache ||= OpenStruct.new
  $cache.docs ||= {}
  $cache.docs[url] ||= get_doc_do(url)
end

def findfile(url, re, excl_re = nil)
  doc = get_doc(url)
  newestver = nil
  newesturi = nil
  doc.search("//a") { |a|
    if a.inner_text =~ re and (excl_re.nil? or a.inner_text !~ excl_re)
      ver = Version.new(a.inner_text)
      if newestver.nil? or ver > newestver
        newestver = ver
        newesturi = URI.join(url, a['href'])
      end
    end
  }
  return newesturi
end

def findfilex(url, re)
  uri = URI.parse(url)
  
  newestver = nil
  newesturi = nil
  
  Net::HTTP.start(uri.host, uri.port) do |http|
    puts "GET #{uri}"
    r, d = http.get(uri.request_uri)
    doc = Hpricot.parse(d)
    doc.search("//a") { |a|
      if a.inner_text =~ re
        ver = Version.new(a.inner_text)
        if newestver.nil? or ver > newestver
          newestver = ver
          newesturi = URI.join(uri.to_s, a['href'])
        end
      end
    }
  end
  
  return newesturi
end

def findfile_ftp(url, re)
  uri = URI.parse(url)
  filename = nil
  Net::FTP.open(uri.host, 'anonymous', 'nil') do |ftp|
    ftp.chdir(uri.path)
    ftp.list.each { |fnrow|
      if fnrow =~ /\s(unz[^-]+\.exe)$/
        filename = $1
      end
    }
  end
  uri.path = File.join(uri.path, filename)
  return uri
end

def openssluri
  $cache.openssluri ||= findfile("http://www.openssl.org/source/", /^openssl-(\d+.*)\.tar\.gz$/)
end

def rubygemsuri
  $cache.rubygemsuri ||= findfile("http://rubyforge.org/frs/?group_id=126", /^rubygems-(\d+(\.\d+)*)\.zip$/)
end

def unzipuri
  $cache.unzipuri ||= findfile_ftp("ftp://tug.ctan.org/tex-archive/tools/zip/info-zip/WIN32/", /\s(unz[^-]+\.exe)$/)
end

def pdcursesuri
  $cache.pdcursesuri ||= findfile("http://sourceforge.net/project/showfiles.php?group_id=30480&package_id=22452",
                                  /^pdc(\d)+dll\.zip$/)
end

def find_msysbasepackages
  msysbasesystem_downloadpage = "http://sourceforge.net/project/showfiles.php?group_id=2435&package_id=24963"
  urls = []
  packs = [ 'bash', 'bzip2', 'coreutils', 'findutils', 'gawk', 'lzma', 'make', 'tar' ]
  packs.each { |pack|
    urls << determineurl(findfile(msysbasesystem_downloadpage, /^#{pack}-.*-MSYS-\d+\.\d+\.\d+-(\d+|snapshot)(-bin)?\.tar\.(gz|bz2)$/))
  }
  urls << determineurl(findfile(msysbasesystem_downloadpage, /^MSYS-\d+\.\d+\.\d+-\d+\.tar\.bz2$/))
  urls << determineurl(findfile(msysbasesystem_downloadpage, /^msysCORE-(.*).tar\.bz2$/))
end

def msysbasepackages
  $cache.msysbasepackages ||= find_msysbasepackages
end

def in_tmpdir
  path = File.join(WORK_ROOT, 'tmptmptmp')
  rm_rf(path)
  mkdir_p(path)
  cd(path) do
    yield
  end
  rm_rf(path)
end


def find_iscc
  if iscc = which('iscc.exe')
    return iscc
  else
    glob = File.join(ENV['ProgramFiles'], 'Inno Setup*', 'iscc.exe').gsub(/\\/, '/')
    f = Dir.glob(glob)
    if f.empty?
      raise "Unable to find iscc.exe from Inno Setup in PATH or #{ENV['PROGRAMFILES']}. Please install"
    end
    return f[0]
  end
end

def add_pkg_uri(*uris)
  uris.each { |uri|
    pkg = File.join(PKG_PATH, File.basename(uri.path))
    file pkg do
      download(uri, pkg)
    end
  }
end

def pkggroup(pkgname, directory)
  @urls = []
  def pkg(url, re, excl_re = nil)
    @urls << findfile(url, re, excl_re)
  end
  
  yield
  
  pkgnames = @urls.map { |uri| File.join(PKG_PATH, File.basename(uri.path)) }

  pkg_checkpoint = File.join(directory, "#{pkgname}_checkpoint")
  
  task pkgname => pkg_checkpoint

  add_pkg_uri(*@urls)
  
  file pkg_checkpoint => [ directory, pkgnames ].flatten do
    cd(directory)
    pkgnames.each { |pkg|
      extract(pkg)
    }
    touch(pkg_checkpoint)
  end
    
  undef pkg
end

