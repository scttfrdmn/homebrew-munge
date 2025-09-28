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
    # macOS build fixes - only replace if patterns exist
    if File.read("configure.ac").include?("src/libmissing/Makefile")
      inreplace "configure.ac", /.*src\/libmissing\/Makefile.*\n/, ""
    end
    
    if File.read("src/Makefile.am").include?("libmissing")
      inreplace "src/Makefile.am", /.*libmissing.*\n/, ""
    end
    
    # Remove libmissing references from subdirectory Makefiles
    Dir.glob("src/*/Makefile.am").each do |file|
      content = File.read(file)
      if content.include?("libmissing")
        inreplace file, /.*libmissing.*\n/, ""
      end
      if content.include?("../libmissing/libmissing.la")
        inreplace file, /.*\.\.\/libmissing\/libmissing\.la.*\n/, ""
      end
    end

    # Create dummy headers in ALL directories that might need them
    ["src/munge", "src/munged", "src/mungekey"].each do |dir|
      mkdir_p dir
      (buildpath/"#{dir}/missing.h").write "#include <arpa/inet.h>\n#include <string.h>"
      (buildpath/"#{dir}/strlcpy.h").write "#include <string.h>"
      (buildpath/"#{dir}/strlcat.h").write "#include <string.h>" 
      (buildpath/"#{dir}/inet_ntop.h").write "#include <arpa/inet.h>"
    end
    
    # Fix inet_ntop declaration if needed
    unmunge_content = File.read("src/munge/unmunge.c")
    if unmunge_content.include?('#include "missing.h"') && !unmunge_content.include?("extern const char *inet_ntop")
      inreplace "src/munge/unmunge.c", /#include "missing\.h".*/, 
                "\\0\nextern const char *inet_ntop(int af, const void *src, char *dst, socklen_t size);"
    end

    system "autoreconf", "-fiv"
    system "./configure", 
           "--prefix=#{prefix}",
           "--sysconfdir=#{etc}",
           "--localstatedir=#{var}",
           "--with-openssl-prefix=#{Formula["openssl@3"].opt_prefix}"
    system "make", "install"
  end

  def post_install
    # Create required runtime directories
    (etc/"munge").mkpath
    (var/"lib/munge").mkpath
    (var/"log/munge").mkpath  
    (var/"run/munge").mkpath
    
    # Set secure permissions on sensitive directories
    (var/"lib/munge").chmod 0700
    (var/"log/munge").chmod 0700
    (var/"run/munge").chmod 0755
    (etc/"munge").chmod 0700

    # Generate a default key if one doesn't exist
    key_file = etc/"munge/munge.key"
    unless key_file.exist?
      system sbin/"mungekey", "--create", "--keyfile=#{key_file}"
      key_file.chmod 0400
    else
      key_file.chmod 0400
    end  end

  service do
    run [opt_sbin/"munged", "--foreground"]
    keep_alive true
    working_dir var/"lib/munge"
    log_path var/"log/munge/munged.log"
    error_log_path var/"log/munge/munged.log"
  end

  test do
    system bin/"munge", "--version"
    # Start daemon in background for testing
    fork { exec sbin/"munged", "--foreground" }
    sleep 2
    system "sh", "-c", "#{bin}/munge -n | #{bin}/unmunge"
  end
end
