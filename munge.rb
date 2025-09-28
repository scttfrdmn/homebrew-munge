class Munge < Formula
  desc "MUNGE Uid 'N' Gid Emporium - Authentication service for HPC clusters"
  homepage "https://dun.github.io/munge/"
  url "https://github.com/dun/munge/releases/download/munge-0.5.16/munge-0.5.16.tar.xz"
  sha256 "6fa6f14de41064c2b56422592df7ad1de2af483912c54460863db2827e6a2861"
  license "GPL-3.0-or-later"

  depends_on "autoconf" => :build
  depends_on "automake" => :build  
  depends_on "libtool" => :build
  depends_on "openssl@3"

  def install
    if File.read("configure.ac").include?("src/libmissing/Makefile")
      inreplace "configure.ac", /.*src\/libmissing\/Makefile.*\n/, ""
    end
    
    if File.read("src/Makefile.am").include?("libmissing")
      inreplace "src/Makefile.am", /.*libmissing.*\n/, ""
    end
    
    Dir.glob("src/*/Makefile.am").each do |file|
      content = File.read(file)
      if content.include?("libmissing")
        inreplace file, /.*libmissing.*\n/, ""
      end
      if content.include?("../libmissing/libmissing.la")
        inreplace file, /.*\.\.\/libmissing\/libmissing\.la.*\n/, ""
      end
    end

    ["src/munge", "src/munged", "src/mungekey"].each do |dir|
      mkdir_p dir
      (buildpath/"#{dir}/missing.h").write "#include <arpa/inet.h>\n#include <string.h>"
      (buildpath/"#{dir}/strlcpy.h").write "#include <string.h>"
      (buildpath/"#{dir}/strlcat.h").write "#include <string.h>" 
      (buildpath/"#{dir}/inet_ntop.h").write "#include <arpa/inet.h>"
    end
    
    unmunge_content = File.read("src/munge/unmunge.c")
    if unmunge_content.include?('#include "missing.h"') && !unmunge_content.include?("extern const char *inet_ntop")
      inreplace "src/munge/unmunge.c", /#include "missing\.h".*/, 
                "\\0\nextern const char *inet_ntop(int af, const void *src, char *dst, socklen_t size);"
    end

    system "autoreconf", "-fiv"
    system "./configure", 
           "--prefix=#{prefix}",
           "--sysconfdir=#{prefix}/etc",
           "--localstatedir=#{prefix}/var",
           "--with-openssl-prefix=#{Formula["openssl@3"].opt_prefix}"
    system "make", "install"
  end

  def post_install
    (prefix/"etc/munge").mkpath
    (prefix/"var/lib/munge").mkpath
    (prefix/"var/log/munge").mkpath  
    (prefix/"var/run/munge").mkpath
    
    (prefix/"etc/munge").chmod 0700
    (prefix/"var/lib/munge").chmod 0700
    (prefix/"var/log/munge").chmod 0700
    (prefix/"var/run/munge").chmod 0755

    key_file = prefix/"etc/munge/munge.key"
    unless key_file.exist?
      system sbin/"mungekey", "--create", "--keyfile=#{key_file}"
    end
    key_file.chmod 0400
  end

  service do
    run [opt_sbin/"munged", "--foreground"]
    keep_alive true
    working_dir opt_prefix/"var/lib/munge"
    log_path opt_prefix/"var/log/munge/munged.log"
    error_log_path opt_prefix/"var/log/munge/munged.log"
  end

  test do
    system bin/"munge", "--version"
  end
end

  def caveats
    <<~EOS
      MUNGE has been configured to use paths within the Homebrew prefix.
      
      Configuration: #{opt_prefix}/etc/munge/
      Runtime files: #{opt_prefix}/var/lib/munge/
      
      If you encounter permission errors, you may need to temporarily
      adjust Homebrew directory permissions with:
        sudo chmod g-w #{HOMEBREW_PREFIX}/etc #{HOMEBREW_PREFIX}/var
      
      For production use, consider copying munge.key from your cluster:
        cp /path/to/cluster/munge.key #{opt_prefix}/etc/munge/
        chmod 400 #{opt_prefix}/etc/munge/munge.key
    EOS
  end
