require 'uri'
require 'util'
require 'hpricot'

# Ruby4Windows Rakefile
#
# = Description
#
# The goal of this Rakefile is to build Ruby of Windows using MingW
# with most standard extensions included, assuming only that the user
# has Ruby installed (with rake + hpricot gems). The rest will be
# downloaded.
#
# The packages to download are defined in the 'pkggroup' sections. The
# script is rather smart in figuring out which version and files to
# download, but if may break if the maintainers of those pages change
# their naming schemes. In that case, the 'pkggroup' definitions needs
# to be updated.
#
# Download URLs are stored in cache.bin (as a marshalled
# OpenStruct). They will be detected the first time "rake" is run. To
# refresh the URL's, delete "cache.bin".
#
# The host tools, ruby prerequisites, etc. are not fully dependency
# checked. Instead a checkpoint mechanism is used. In each directory
# (mingw, hostprereqs, etc.) there is a checkpoint file that is
# created when the packages has been extracted. They will not be
# recreated while this file exist. To recreate them, simply delete
# them or run "rake clean".
#
# = Environment variables
#
#  * PATH is generally cleared by the Rakefile to avoid using other
#    tools than the intented. Perl.exe needs to be in the PATH when
#    invoking rake though.
#
#  * RUBYOPT has no effect except the the ruby instance running the
#    rakefile.
#
#  * RUBY_SVN is the Ruby repository to check out and build.
#
#  * CFLAGS is the optimisation flags used when building Ruby. The
#    default is "-O2 -mtune=i686".

MP_VERSION = "1"


# Detect perl
if perl_path = which('perl')
  if `#{perl_path} -v` !~ /ActiveState/
      p `#{perl_path} -v`
      puts "WARNING: Your Perl installation is not ActiveState. This has not been tested!"
    puts ""
    puts "Press ENTER to continue or Ctrl+C to abort . . ."
    STDIN.gets
  end
else
  puts "ERROR: Couldn't not find a perl.exe installed. This needed needed"
  puts "to compile OpenSSL. Please install ActivePerl and ensure that Perl.exe"
  puts "is in your path. This is the only manual dependency, I promise :-)"
end

ENV['PATH'] = File.dirname(perl_path).gsub(/\//, '\\')

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
# p ENV['PATH']
ENV['LIBRARY_PATH'] = '/prereq/lib'
ENV['C_INCLUDE_PATH'] = '/prereq/include'
ENV['CFLAGS'] ||= '-O2 -mtune=i686'
ENV['RUBYOPT'] = ""
tmpinstall_path = File.join(WORK_ROOT, 'tmpinstall')
PKG_PATH = File.join(WORK_ROOT, 'pkg')
ARCH_URLS = {}
hostmingw_path = File.expand_path("hostmingw")
svn_uri = URI.join(svn_root, svn_path)
sandbox_path = File.expand_path(File.join('svn', svn_uri.host, svn_uri.request_uri))
configure_script = File.join(sandbox_path, 'configure')
build_path = sandbox_path + '-build'
makefile = File.join(build_path, 'Makefile')

ENV['PATH'] += ';' + hostprereq_path.gsub(/\//, '\\') + '\\bin' +
  ';' + hostmingw_path.gsub(/\//, '\\') + '\\bin'



# HOST_PREREQS = {
#   ['gtar','tar'] => ['bin', 'dep'],
#   'bzip2' => ['bin', 'dep'],
#   'gzip' => ['bin', 'dep'],
#   # 'unzip' => ['bin', 'dep']
# }

def unzip_pkg
  File.join(PKG_PATH, File.basename(unzipuri.path))
end

directory prereq_path
directory hostmingw_path
directory build_path
directory hostprereq_path
directory MSYS_ROOT

UNZIP_EXE = File.join(hostprereq_path, 'bin', 'unzip.exe')
bzip2_exe = File.join(hostprereq_path, 'bin', 'bzip2.exe')
gzip_exe = File.join(hostprereq_path, 'bin', 'gzip.exe')
tar_exe = File.join(hostprereq_path, 'bin', 'tar.exe')

file UNZIP_EXE => unzip_pkg do
  if not File.exist?(UNZIP_EXE)
    unzdir = File.join(hostprereq_path, 'bin')
    mkdir_p(unzdir)
    cd unzdir do
      sys(unzip_pkg, '-o', '-q', 'unzip.exe')
    end
  end
end

#
# Package definitions
#

pkggroup :prereq, prereq_path do
  pkg "http://gnuwin32.sourceforge.net/packages/gdbm.htm", /^gdbm-bin-zip/
  pkg "http://gnuwin32.sourceforge.net/packages/gdbm.htm", /^gdbm-lib-zip/
  pkg "http://gnuwin32.sourceforge.net/packages/readline.htm", /^readline-bin-zip/
  pkg "http://gnuwin32.sourceforge.net/packages/readline.htm", /^readline-lib-zip/
  pkg "http://gnuwin32.sourceforge.net/packages/zlib.htm", /^zlib-bin-zip/
  pkg "http://gnuwin32.sourceforge.net/packages/zlib.htm", /^zlib-lib-zip/
  pkg "http://gnuwin32.sourceforge.net/packages/libiconv.htm", /^libiconv-bin-zip/
  pkg "http://gnuwin32.sourceforge.net/packages/libiconv.htm", /^libiconv-lib-zip/
end

pkggroup :hostprereq, hostprereq_path do
  pkg "http://gnuwin32.sourceforge.net/packages/gtar.htm", /^tar-bin-zip/
  pkg "http://gnuwin32.sourceforge.net/packages/gtar.htm", /^tar-dep-zip/
  pkg "http://gnuwin32.sourceforge.net/packages/bzip2.htm", /^bzip2-bin-zip/
  pkg "http://gnuwin32.sourceforge.net/packages/gzip.htm", /^gzip-bin-zip/
end

pkggroup :mingw, hostmingw_path do
  pkg "http://sourceforge.net/project/showfiles.php?group_id=2435&package_id=82723", /^gcc-core-.*.tar.gz$/
  pkg "http://sourceforge.net/project/showfiles.php?group_id=2435&package_id=11290", /^binutils-2\.17.*\d\.tar\.gz$/, /-src\.tar\.gz$/
  pkg "http://sourceforge.net/project/showfiles.php?group_id=2435&package_id=23918", /^mingw32-make-.*\.tar\.gz$/, /-src.*\.tar\.gz$/
  pkg "http://sourceforge.net/project/showfiles.php?group_id=2435&package_id=11550", /^w32api-.*\.tar\.gz$/, /-src\.tar\.gz$/
end

pkggroup :msys, MSYS_ROOT do
  msys_url = "http://sourceforge.net/project/showfiles.php?group_id=2435&package_id=24963"
  packs = [ 'bash', 'bzip2', 'coreutils', 'findutils', 'gawk', 'lzma', 'make', 'tar' ]
  packs.each { |pack|
    pkg msys_url, /^#{pack}-.*-MSYS-\d+\.\d+\.\d+-(\d+|snapshot)(-bin)?\.tar\.(gz|bz2)$/
  }
  pkg msys_url, /^MSYS-\d+\.\d+\.\d+-\d+\.tar\.bz2$/
  pkg msys_url, /^msysCORE-(.*).tar\.bz2$/

  msyssupp_url = "http://sourceforge.net/project/showfiles.php?group_id=2435&package_id=67879"
  pkg msyssupp_url, /^autoconf2.5.*-bin\.tar\.bz2$/ # autoconf
  pkg msyssupp_url, /^perl-\d.*\.tar\.bz2$/, /-src\.tar/ # Perl (dependency of autoconf)
  pkg msyssupp_url, /^crypt-.*\.tar\.bz2$/, /-src\./ # libcrypt (dependency of perl)
  pkg msyssupp_url, /^bison-\d.*\.tar\./, /-src\./
end

task :default => [:build]

ENV['RUBYOPT'] = nil

def pkgpath(filename)
  File.join(WORK_ROOT, 'pkg', filename)
end


task :clean_build do
  rm_rf(build_path)
end

task :fresh_build => [ :update_sandbox, :build ]

desc "Build Ruby"
task :build => [ :msys, :mingw, makefile ] do
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

file configure_script => [ sandbox_path, :prereq ] do
  Dir.chdir(sandbox_path) do
    autoconf = Dir.glob(File.join(MSYS_ROOT, 'bin', 'autoconf*'))[0] ||
      Dir.glob(File.join(MSYS_ROOT, 'usr', 'bin', 'autoconf*'))[0] ||
      Dir.glob(File.join(MSYS_ROOT, 'usr', 'local', 'bin', 'autoconf*'))[0] ||
      Dir.glob(File.join(MSYS_ROOT, 'local', 'bin', 'autoconf*'))[0]
    msys_sh(File.basename(autoconf))
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
  cd tmprubygems do
    extract(rubygem_zippath)
    cd File.dirname(Dir['*/setup.rb'][0]) do
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

############################################################################
# PDCurses
############################################################################

pdcurses_uri = pdcursesuri
pdcurses_filename = File.basename(pdcurses_uri.path)
pdcurses_path = File.join(PKG_PATH, pdcurses_filename)
ARCH_URLS[pdcurses_filename] = pdcurses_uri
pdcurses_checkpoint = File.join(prereq_path, 'pdcurses_checkpoint')
file pdcurses_checkpoint => pdcurses_path do
  in_tmpdir do
    extract pdcurses_path
    cp Dir.glob('*.h'), File.join(prereq_path, 'include')
    cp Dir.glob('*.lib'), File.join(prereq_path, 'lib')
    cp Dir.glob('*.dll'), File.join(prereq_path, 'bin')
  end
  touch pdcurses_checkpoint
end
task :prereq => pdcurses_checkpoint

############################################################################
# OpenSSL
############################################################################

openssl_uri = openssluri
openssl_filename = File.basename(openssl_uri.path)
ARCH_URLS[openssl_filename] = openssl_uri

openssl_path = File.join(PKG_PATH, openssl_filename)
opensslbuild_path = File.join(WORK_ROOT, 'openssl-build')
directory opensslbuild_path

openssl_checkpoint = File.join(prereq_path, 'openssl_checkpoint')
opensslbuild_checkpoint = File.join(opensslbuild_path, 'opensslbuild_checkpoint')

task :opensslbuild => opensslbuild_checkpoint

file opensslbuild_checkpoint => openssl_path do
  rm_rf opensslbuild_path
  mkdir_p opensslbuild_path
  cd opensslbuild_path do
    extract openssl_path
    cd File.dirname(Dir['*/configure'][0]) do
      sys("ms\\mingw32.bat")
    end
  end
  touch opensslbuild_checkpoint
end

file openssl_checkpoint => opensslbuild_checkpoint do
  cd opensslbuild_path do
    cd File.dirname(Dir['*/configure'][0]) do
      cp_r 'outinc/openssl', File.join(prereq_path, 'include')
      cp_r Dir.glob('out/lib*.a'), File.join(prereq_path, 'lib')
      cp_r Dir.glob('*.dll'), File.join(prereq_path, 'bin')
    end
  end
  touch openssl_checkpoint
end
task :prereq => openssl_checkpoint

############################################################################
#
############################################################################

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

ARCH_URLS.each { |fn, uri|
  path = File.join(PKG_PATH, fn)
  file path do
    download(uri, path)
  end
}

task :clean do
  rm_rf(prereq_path)
  rm_rf(MSYS_ROOT)
  rm_rf(hostprereq_path)
  rm_rf(hostmingw_path)
end

task :msys do
  fixmsys = makemsyspath(File.join(WORK_ROOT, 'fixmsyslocal.sh'))
  sys(File.join(MSYS_ROOT, 'bin', 'bash.exe') + " --login #{fixmsys} " + makemsyspath(MSYS_ROOT))
end

task :testgcc => :mingw do
  gcc = File.join(hostmingw_path, 'bin', 'gcc.exe')
  sys(gcc, '-E', 'test.c')
end
