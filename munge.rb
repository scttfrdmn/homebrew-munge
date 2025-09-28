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
  depends_on "zlib"
  depends_on "bzip2"

  def install
    # macOS build fixes: remove problematic libmissing references
    inreplace "configure.ac", /.*src\/libmissing\/Makefile.*\n/, ""
    inreplace "src/Makefile.am", /.*libmissing.*\n/, ""
    
    # Remove libmissing references from all subdirectory Makefiles
    Dir.glob("src/*/Makefile.am").each do |file|
      inreplace file, /.*libmissing.*\n/, ""
      inreplace file, /.*\.\.\/libmissing\/libmissing\.la.*\n/, ""
      inreplace file, /.*\$\(top_builddir\)\/src\/libmissing\/libmissing\.la.*\n/, ""
    end

    # Create replacement headers for macOS (which provides these functions natively)
    mkdir_p "src/libmissing"
    
    (buildpath/"src/libmissing/missing.h").write <<~EOS
      /* Missing function declarations for macOS build */
      #ifndef MISSING_H
      #define MISSING_H
      #include <sys/types.h>
      #include <sys/socket.h>
      #include <arpa/inet.h>
      #include <string.h>
      #endif /* MISSING_H */
    EOS
    
    (buildpath/"src/libmissing/inet_ntop.h").write <<~EOS
      #ifndef INET_NTOP_H
      #define INET_NTOP_H
      #include <sys/types.h>
      #include <sys/socket.h>
      #include <arpa/inet.h>
      #endif /* INET_NTOP_H */
    EOS
    
    (buildpath/"src/libmissing/strlcpy.h").write <<~EOS
      #ifndef STRLCPY_H
      #define STRLCPY_H
      #include <string.h>
      #endif /* STRLCPY_H */
    EOS
    
    (buildpath/"src/libmissing/strlcat.h").write <<~EOS
      #ifndef STRLCAT_H
      #define STRLCAT_H
      #include <string.h>
      #endif /* STRLCAT_H */
    EOS

    # Copy headers to directories that need them
    cp_r "src/libmissing/.", "src/munged/"
    cp_r "src/libmissing/.", "src/mungekey/"
    
    # Fix inet_ntop declaration in unmunge.c
    inreplace "src/munge/unmunge.c", 
              /#include "missing\.h".*/, 
              "\\0\n\n/* Manual function declarations for macOS */\nextern const char *inet_ntop(int af, const void *src, char *dst, socklen_t size);"

    # Regenerate build system after our changes
    system "autoreconf", "-fiv"

    # Configure with macOS-specific settings
    system "./configure",
           "--prefix=#{prefix}",
           "--sysconfdir=#{etc}/munge", 
           "--localstatedir=#{var}",
           "--with-crypto-lib=openssl",
           "--with-openssl-prefix=#{Formula["openssl@3"].opt_prefix}",
           "--disable-static",
           "--enable-shared"

    system "make", "install"
  end

  def post_install
    # Create runtime directories
    (var/"lib/munge").mkpath
    (var/"log/munge").mkpath
    (var/"run/munge").mkpath
    
    # Set secure permissions
    (var/"lib/munge").chmod 0700
    (var/"log/munge").chmod 0700
    (var/"run/munge").chmod 0755
  end

  service do
    run [opt_sbin/"munged", "--foreground"]
    keep_alive true
    working_dir var/"lib/munge"
    log_path var/"log/munge/munged.log"
    error_log_path var/"log/munge/munged.log"
  end

  test do
    system bin/"munge", "--version"
    # Test basic munge/unmunge functionality
    system "sh", "-c", "#{bin}/munge -n | #{bin}/unmunge"
  end
end
