require 'uri'
require 'util'
require 'hpricot'

# Download URLs are stored in cache.bin (as a marshalled
# OpenStruct). They will be detected the first time "rake" is run. To
# refresh the URL's, delete "cache.bin".
#
# The host prereqs and MSYS directories contain a checkpoint file when
# fully created. They will not be recreated while this file exist. To
# recreate them, simply delete them or run "rake clean".

MP_VERSION = "1"

ENV['PATH'] = ""

module Net
  autoload :HTTP, 'net/http'
  autoload :FTP, 'net/ftp'
end
autoload :Hpricot, 'hpricot'
autoload :OpenStruct, 'ostruct'

# Log run time
START_TIME = Time.now
at_exit { puts "Run time: " + formattimedelta(Time.now - START_TIME) }

# Load cached variables
if File.exist?('cache.bin')
  File.open('cache.bin', 'rb') { |f|
    $cache = Marshal.load(f.read)
  }
else
  $cache = OpenStruct.new
end

# Store cached variables when done
at_exit do
  File.open('cache.bin', 'wb') { |f|
    f.write(Marshal.dump($cache))
  }
end

#p which("svn")

# exit

# Rakefile for building Ruby on Windows using MingW. 
#
# === Targets:
#
# rake sandbox / clean_sandbox
#   Checkout of Ruby from SVN (or remove checkout)
#
# rake build / fresh_build
#   Build Ruby (fresh_build updates from SVN first)
#
# rake test
#   Run the Ruby test suite
#
# rake shell
#   Start a Bash shell in the build directory.
#
# === Options/Environment:
#
# rake RUBY_SVN=<path>
#
#   Set path to check out (trunk, branch/<branch>, tag/<tag>). For
#   example: "rake RUBY_SVN=branch/ruby_1_8". Default is "trunk"
#
# rake MSYS_ROOT=<path>
#
#   Set path to where MSYS is installed. Default is './root'.


# List of gems that we want in the installer
GEMNAMES = [
  'hpricot',
  'rake'
]

MSYS_ROOT = ENV['MSYS_ROOT'] || File.expand_path('root')
WORK_ROOT = Dir.pwd
svn_root = 'http://svn.ruby-lang.org/repos/ruby/'
svn_path = ENV['RUBY_SVN'] || 'tags/v1_8_7_22'
prereq_path = File.join(MSYS_ROOT, 'prereq')
hostprereq_path = File.join(WORK_ROOT, 'hostprereq')
ENV['PATH'] += ';' + hostprereq_path.gsub(/\//, '\\') + '\\bin'
# p ENV['PATH']
ENV['LIBRARY_PATH'] = '/prereq/lib'
ENV['C_INCLUDE_PATH'] = '/prereq/include'
ENV['CFLAGS'] = '-O2 -mtune=i686'
ENV['RUBYOPT'] = ""
tmpinstall_path = File.join(WORK_ROOT, 'tmpinstall')
PKG_PATH = File.join(WORK_ROOT, 'pkg')
ARCH_URLS = {}
hostmingw_path = File.expand_path("hostmingw")

HOST_PREREQS = {
  ['gtar','tar'] => ['bin', 'dep'],
  'bzip2' => ['bin', 'dep'],
  'gzip' => ['bin', 'dep'],
  # 'unzip' => ['bin', 'dep']
}

def unzip_pkg
  File.join(PKG_PATH, File.basename(unzipuri.path))
end

unzip_exe = File.join(hostprereq_path, 'bin', 'unzip.exe')
bzip2_exe = File.join(hostprereq_path, 'bin', 'bzip2.exe')
gzip_exe = File.join(hostprereq_path, 'bin', 'gzip.exe')
tar_exe = File.join(hostprereq_path, 'bin', 'tar.exe')

file unzip_exe => unzip_pkg do
  if not File.exist?(unzip_exe)
    unzdir = File.join(hostprereq_path, 'bin')
    mkdir_p(unzdir)
    cd(unzdir) do
      sys(unzip_pkg, '-o', '-q', 'unzip.exe')
    end
  end
end

############################################################################
# Prerequisites
############################################################################

PREREQS = {
  'gdbm' => ['bin', 'lib', 'src'],
  'readline' => ['bin', 'lib'],
  'zlib' => ['bin','lib'],
  'libiconv' => ['bin','lib'],
}

# Finds uri to GNUWIN32 packages
def gnuwin32uris(package, parts)
  if package.is_a?(Array)
    page, package = package
  else
    page = package
  end
  url = "http://gnuwin32.sourceforge.net/packages/#{page}.htm"
  uri1 = URI.parse(url)
  urix = uri1.dup
  Net::HTTP.start(uri1.host, uri1.port) do |http|
    puts "GET #{uri1}"
    r, d = http.get(uri1.request_uri)
    doc = Hpricot.parse(d)
    doc.search("//a") { |a|
      if href = a['href'] and a.inner_text == "Zip"
        basename = File.basename(href)
        parts_re = parts.join('|')
        if basename =~ /^#{package}-(#{parts_re})-zip.php$/
          uri2 = URI.join(url, href)
          targeturi = determineurl(uri2)
          yield(targeturi)
        end
      end
    }
  end
end

# file 'prereqs.bin' do
def gen_prereq_hash
  prereqs = {}
  PREREQS.each do |prereq,parts|
    gnuwin32uris(prereq, parts) do |uri|
      filename = File.basename(uri.path)
      prereqs[filename] = uri
    end
  end
  prereqs
end

def gen_hostprereq_hash
  prereqs = {}
  HOST_PREREQS.each do |prereq,parts|
    gnuwin32uris(prereq, parts) do |uri|
      filename = File.basename(uri.path)
      prereqs[filename] = uri
    end
  end
  prereqs
end

PREREQ_HASH = ($cache.prereq_hash ||= gen_prereq_hash)
PREREQ_FILES = PREREQ_HASH.keys.map { |fn| File.join(PKG_PATH, fn) }
HOSTPREREQ_HASH = ($cache.hostprereq_hash ||= gen_hostprereq_hash)
HOSTPREREQ_FILES = HOSTPREREQ_HASH.keys.map { |fn| File.join(PKG_PATH, fn) }

##################################################
svn_uri = URI.join(svn_root, svn_path)
sandbox_path = File.expand_path(File.join('svn', svn_uri.host, svn_uri.request_uri))
configure_script = File.join(sandbox_path, 'configure')
build_path = sandbox_path + '-build'
makefile = File.join(build_path, 'Makefile')

task :default => [:build]

ENV['RUBYOPT'] = nil

def pkgpath(filename)
  File.join(WORK_ROOT, 'pkg', filename)
end

directory build_path

task :clean_build do
  rm_rf(build_path)
end

task :fresh_build => [ :update_sandbox, :build ]

desc "Build Ruby"
task :build => [ MSYS_ROOT, makefile ] do
  Dir.chdir(build_path) do
    msys_sh("make")
  end
end

desc "Run ruby test suite"
task :test => [ makefile ] do
  Dir.chdir(build_path) do
    msys_sh("make test")
  end
end

desc "Run Ruby benchmark"
task :benchmark do
  Dir.chdir(build_path) do
    msys_sh("make benchmark")
  end
end

file configure_script => [ sandbox_path, prereq_path ] do
  Dir.chdir(sandbox_path) do
    msys_sh("autoconf")
  end
end

file makefile => [ MSYS_ROOT, configure_script, build_path ] do
  Dir.chdir(build_path) do
    msys_sh(File.join('..', File.basename(sandbox_path), "configure --prefix=/"))
  end
end

file sandbox_path do
  sandbox_path_parent = File.expand_path(File.join(sandbox_path, '..'))
  make_path(sandbox_path_parent)
  Dir.chdir(sandbox_path_parent) do
    sys("svn co #{svn_root}/#{svn_path}")
  end
end

desc "Update sandbox from #{svn_path}"
task :update_sandbox => [ sandbox_path ] do
  Dir.chdir(sandbox_path) do
    sys("svn update")
    # sys("svn revert .")
  end
end

task :shell do
  Dir.chdir(build_path) do
    msys_sh("bash")
  end
end

task :sandbox => [ sandbox_path ]

task :clean_sandbox do
  rm_rf sandbox_path
end

rubygemzip_uri = rubygemsuri
rubygem_zipfile = File.basename(rubygemzip_uri.path)
rubygem_zippath = File.join(PKG_PATH, rubygem_zipfile)
ARCH_URLS[rubygem_zipfile] = rubygemzip_uri

task :install => [ :install_nodoc, :install_prereq, :install_rubygems, :install_gems ]

task :install_nodoc => [ :build, rubygem_zippath ] do
  rm_rf(tmpinstall_path)
  Dir.chdir(build_path) do
    msys_sh("make install-nodoc DESTDIR=#{makemsyspath(tmpinstall_path)}")
  end
end

task :install_prereq do
  cp Dir.glob(File.join(prereq_path, 'bin', '*.dll')), File.join(tmpinstall_path, 'bin')
end

task :install_gems do
  with_path(File.join(tmpinstall_path, 'bin'), File.join(MSYS_ROOT, 'bin')) do
    GEMNAMES.each { |gemname|
      gem = File.join(tmpinstall_path, 'bin', 'gem.bat')
      sys(gem, 'install', gemname)
    }
  end
end

def with_path(*paths)
  oldpath = ENV['PATH']
  begin
    
    ENV['PATH'] = paths.map { |path| path.gsub(/\//, '\\') }.join(';') + ';' + ENV['PATH']
    yield
  ensure
    ENV['PATH'] = oldpath
  end
end

task :update_versions_txt do
  ruby = File.join(tmpinstall_path, 'bin', 'ruby.exe')
  system("#{ruby} versions.rb > versions.txt")
end

task :install_rubygems => rubygem_zippath do
  tmprubygems = File.join(WORK_ROOT, 'tmprubygemsinst')
  rm_rf(tmprubygems)
  mkdir_p(tmprubygems)
  cd(tmprubygems) do
    extract(rubygem_zippath)
    cd(File.dirname(Dir['*/setup.rb'][0])) do
      ruby = File.join(tmpinstall_path, 'bin', 'ruby.exe')
      sys(ruby, 'setup.rb')
    end
  end
  rm_rf(tmprubygems)
end

RUBY_EXT = {
  'bigdecimal' => 'bigdecimal',
  'curses' => 'curses',
  'dbm' => 'dbm',
  'digest' => ['digest', 'md5', 'sha1'],
  'dl' => 'dl',
  'etc' => 'etc',
  'fcntl' => 'fcntl',
  'gdbm' => 'gdbm',
  'iconv' => 'iconv',
  'io' => 'io/wait',
  'nkf' => 'nkf',
  'openssl' => 'openssl',
  # 'pty' => 'pty',
  'racc' => 'racc/cparse',
  'readline' => 'readline',
  'sdbm' => 'sdbm',
  'socket' => 'socket',
  'stringio' => 'stringio',
  'strscan' => 'strscan',
  'syck' => 'syck',
  # 'syslog' => 'syslog',
  'thread' => 'thread',
  # 'tk' => 'tk',
  'Win32API' => 'Win32API',
  'win32ole' => 'win32ole',
  'zlib' => 'zlib'
}

task :install_test_ext do

  p Dir.entries(File.join(sandbox_path, 'ext')).select { |x|
    File.directory?(File.join(sandbox_path, 'ext', x)) and x !~ /^\./
  } - RUBY_EXT.keys
  
  oldpath = ENV['PATH']
  begin
    ENV['PATH'] = ENV['WINDIR'] + ';' + ENV['WINDIR'] + '\\System32'
    Dir.chdir(File.join(tmpinstall_path, 'bin')) do
      ruby = File.join(tmpinstall_path, 'bin', 'ruby.exe')
      RUBY_EXT.keys.sort.each { |ext|
        reqs = [RUBY_EXT[ext]].flatten
        reqs.each { |req|
          if system("#{ruby} -r#{req} -e exit")
            puts "#{ext} #{$?.exitstatus}"
          else
            puts "#{ext} norun"
          end
        }
      }
    end
  ensure
    ENV['PATH'] = oldpath
  end
end

task :prereqs => prereq_path do
end

pdcurses_uri = pdcursesuri
pdcurses_filename = File.basename(pdcurses_uri.path)
pdcurses_path = File.join(PKG_PATH, pdcurses_filename)
ARCH_URLS[pdcurses_filename] = pdcurses_uri

openssl_uri = openssluri
openssl_filename = File.basename(openssl_uri.path)
openssl_path = File.join(PKG_PATH, openssl_filename)
ARCH_URLS[openssl_filename] = openssl_uri

openssl_buildpath = File.join(WORK_ROOT, 'openssl-build')

# Install prerequisites for Ruby extensions
task prereq_path => [ PREREQ_FILES, pdcurses_path, openssl_buildpath ].flatten do
  mkdir_p(prereq_path)
  cd(prereq_path) do
    PREREQ_FILES.each { |fn|
      if fn !~ /-src\.zip$/
        extract(fn)
      elsif File.basename(fn) =~ /^gdbm-.*-src.zip$/
        # Extract gbdm-dll.h from the source archive
        sys("unzip -q -j -o #{pkgpath('gdbm-1.8.3-1-src.zip')} src/gdbm/1.8.3/gdbm-1.8.3-src/gdbm-dll.h -d include")
      end
    }
  end
  
  in_tmpdir do
    extract(pdcurses_path)
    cp( Dir.glob('*.h'), File.join(prereq_path, 'include') )
    cp( Dir.glob('*.lib'), File.join(prereq_path, 'lib') )
    cp( Dir.glob('*.dll'), File.join(prereq_path, 'bin') )
  end

  cd openssl_buildpath do
    cp Dir.glob('*/*.dll'), File.join(prereq_path, 'bin')
    cp_r Dir.glob('*/outinc/openssl'), File.join(prereq_path, 'include')
    cp_r Dir.glob('*/out/lib*.a'), File.join(prereq_path, 'lib')
  end
end

task :getprereqs => PREREQ_FILES

[PREREQ_FILES,HOSTPREREQ_FILES].flatten.each do |prereq|
  file prereq do |task|
    filename = File.basename(task.name)
    uri = PREREQ_HASH[filename] || HOSTPREREQ_HASH[filename]
    download(uri, task.name)
  end
end

hostprereq_checkpoint = File.join(hostprereq_path, 'hostprereqcheckpoint')

directory hostprereq_path

file hostprereq_checkpoint => [ unzip_exe, HOSTPREREQ_FILES ].flatten do
  mkdir_p hostprereq_path
  cd hostprereq_path do
    HOSTPREREQ_FILES.each do |fn|
      extract fn
    end
  end
  touch hostprereq_checkpoint
end

task :hostprereq => hostprereq_checkpoint

task :buildopenssl2 do
  openssl_tmppath = File.join(WORK_ROOT, 'openssl-build')
  rm_rf(openssl_tmppath)
  mkdir_p(openssl_tmppath)
  cd(openssl_tmppath) do
    extract(openssl_path)
    cd(File.dirname(Dir['*/configure'][0])) do
      sys("ms\\mingw32.bat")
    end
  end
end

task :instopenssl2 do
  openssl_tmppath = File.join(WORK_ROOT, 'openssl-build')
  cd(openssl_tmppath) do
    cd(File.dirname(Dir['*/configure'][0])) do
      cp_r('outinc/openssl', File.join(prereq_path, 'include'))
      cp_r( Dir.glob('out/lib*.a'), File.join(prereq_path, 'lib'))
      cp_r( Dir.glob('*.dll'), File.join(prereq_path, 'bin'))
    end
  end
end

task :inst_test do
  Dir.entries(File.join(sandbox_path, 'test')).each { |fn|
    next if fn =~ /^\./
    next if not File.directory?(File.join(sandbox_path, 'test', fn))
    next if fn == 'drb'
    next if fn == 'readline'
    puts fn
    ruby = File.join(tmpinstall_path, 'bin', 'ruby.exe')
    sys_k(ruby, 'runner.rb', File.join(sandbox_path, 'test', fn))
  }
end

file 'rubyinst.iss' => :update_rubyinst_iss
file 'versions.txt' => :update_versions_txt

# Update rubyinst.iss with versions etc.
task :update_rubyinst_iss do
  ruby = File.join(tmpinstall_path, 'bin', 'ruby.exe')
  ruby_version = `#{ruby} -e "puts RUBY_VERSION"`.chomp
  ruby_patchlevel = `#{ruby} -e "puts RUBY_PATCHLEVEL"`.chomp
  outputname = "ruby-#{ruby_version}-p#{ruby_patchlevel}-build-#{MP_VERSION}"
  appvername = "Ruby #{ruby_version}"
  
  content = IO.read('rubyinst.iss')
  content.gsub!(/^LicenseFile=.*$/, "LicenseFile=#{File.join(sandbox_path, 'COPYING')}")
  content.gsub!(/^OutputBaseFilename=.*$/, "OutputBaseFilename=#{outputname}")
  content.gsub!(/^AppVerName=.*$/, "AppVerName=#{appvername}")
  File.open('rubyinst.iss', 'w') { |f| f << content }
end

desc "Build the Ruby for Windows installer"
task :installer => [ 'rubyinst.iss', 'versions.txt' ] do
  iscc = find_iscc
  sys(iscc, '/Q', 'rubyinst.iss')
end

msysbasepackage_pkgpaths = msysbasepackages.map { |uri| File.join(PKG_PATH, File.basename(uri.path)) }
msysbasepackages.each { |uri| ARCH_URLS[File.basename(uri.path)] = uri }

msysroot_checkpoint = File.join(MSYS_ROOT, 'msysrootcheckpoint')

directory MSYS_ROOT

file msysroot_checkpoint => [ hostprereq_checkpoint, msysbasepackage_pkgpaths ].flatten do
  mkdir_p(MSYS_ROOT)
  cd(MSYS_ROOT) do
    sys("attrib -R * /S")
    msysbasepackage_pkgpaths.each { |pkg|
      extract(pkg)
    }
  end
  touch(msysroot_checkpoint)
end

task :root => msysroot_checkpoint


# Task for each downloadable file
ARCH_URLS.each { |fn, uri|
  path = File.join(PKG_PATH, fn)
  file path do
    download(uri, path)
  end
}

task :clean do
  rm_rf(MSYS_ROOT)
  rm_rf(hostprereq_path)
  rm_rf(hostmingw_path)
end

directory hostmingw_path
pkggroup :mingw, hostmingw_path do
  # gcc version 3
  pkg "http://sourceforge.net/project/showfiles.php?group_id=2435&package_id=82723", /^gcc-core-.*.tar.gz$/
  # binutils
  pkg "http://sourceforge.net/project/showfiles.php?group_id=2435&package_id=11290", /^binutils-.*\d\.tar\.gz$/, /-src\.tar\.gz$/
  # mingw32-make
  pkg "http://sourceforge.net/project/showfiles.php?group_id=2435&package_id=23918", /^mingw32-make-.*\.tar\.gz$/, /-src.*\.tar\.gz$/
  # win32api
  pkg "http://sourceforge.net/project/showfiles.php?group_id=2435&package_id=11550", /^w32api-.*\.tar\.gz$/, /-src\.tar\.gz$/
end

task :testgcc => :mingw do
  gcc = File.join(hostmingw_path, 'bin', 'gcc.exe')
  # p which("gcc.exe")
  sys(gcc, '-E', 'test.c')
end
