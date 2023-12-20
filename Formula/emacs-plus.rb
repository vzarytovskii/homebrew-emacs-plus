require_relative "../Library/EmacsBase"

class EmacsPlus < EmacsBase
  init 30
  version "30.0.50"
  env :std

  fails_with :clang
  depends_on "autoconf" => :build
  depends_on "awk" => :build
  depends_on "coreutils" => :build
  depends_on "gcc" => :build
  depends_on "gmp" => :build
  depends_on "gnu-sed" => :build
  depends_on "gnu-tar" => :build
  depends_on "gnutls" => :build
  depends_on "grep" => :build
  depends_on "imagemagick" => :build
  depends_on "jansson" => :build
  depends_on "libgccjit" => :build
  depends_on "libjpeg" => :build
  depends_on "librsvg" => :build
  depends_on "little-cms2" => :build
  depends_on "mailutils" => :optional
  depends_on "make" => :build
  depends_on "pkg-config" => :build
  depends_on "texinfo" => :build
  depends_on "tree-sitter"
  depends_on "webp" => :build
  depends_on "xz" => :build
  depends_on "zlib" => :build


  url "https://github.com/emacs-mirror/emacs.git", :branch => "master"
  inject_icon_options

  local_patch "fix-window-role", sha: "1f8423ea7e6e66c9ac6dd8e37b119972daa1264de00172a24a79a710efcb8130"
  local_patch "system-appearance", sha: "d6ee159839b38b6af539d7b9bdff231263e451c1fd42eec0d125318c9db8cd92"
  local_patch "poll", sha: "052eacac5b7bd86b466f9a3d18bff9357f2b97517f463a09e4c51255bdb14648"
  local_patch "round-undecorated-frame", sha: "7451f80f559840e54e6a052e55d1100778abc55f98f1d0c038a24e25773f2874"

  def initialize(*args, **kwargs, &block)
    a = super
    expand_path
    a
  end


  def install
    expand_path

    cc = "#{Formula["gcc"].opt_bin}/gcc-#{Formula["gcc"].any_installed_version.major}"

    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --enable-locallisppath=#{HOMEBREW_PREFIX}/share/emacs/site-lisp
      --infodir=#{info}/emacs
      --prefix=#{prefix}
      --disable-ns-self-contained
      --with-cairo
      --with-cocoa
      --with-gnutls
      --with-json
      --with-mailutils
      --with-modules
      --with-native-compilation=aot
      --with-ns
      --with-poll
      --with-rsvg
      --with-webp
      --with-xml2
      --with-xwidgets
      --without-compress-install
      --without-dbus
      --without-imagemagick
    ]

    ENV.append "CFLAGS", "-O3 -pipe -mtune=native -march=native -fomit-frame-pointer"
    ENV.append "CFLAGS", "-DFD_SETSIZE=10000 -DDARWIN_UNLIMITED_SELECT"

    ENV.append "CPATH", "-I#{Formula["gcc"].opt_include}"
    ENV.append "LIBRARY_PATH", "-L#{Formula["gcc"].opt_lib}"
    ENV.append "LDFLAGS", "-L#{Formula["gcc"].opt_lib}"

    ENV.append "CPATH", "-I#{Formula["libgccjit"].opt_include}"
    ENV.append "LIBRARY_PATH", "-L#{Formula["libgccjit"].opt_lib}"
    ENV.append "LDFLAGS", "-L#{Formula["libgccjit"].opt_lib}"

    ENV.append "CPATH", "-I#{Formula["gmp"].opt_include}"
    ENV.append "LIBRARY_PATH", "-L#{Formula["gmp"].opt_lib}"
    ENV.append "LDFLAGS", "-L#{Formula["gmp"].opt_lib}"


    imagemagick_lib_path = Formula["imagemagick"].opt_lib/"pkgconfig"
    ohai "ImageMagick PKG_CONFIG_PATH: ", imagemagick_lib_path
    ENV.prepend_path "PKG_CONFIG_PATH", imagemagick_lib_path


    ENV.prepend_path "PATH", Formula["gnu-sed"].opt_libexec/"gnubin"
    ENV.prepend_path "PATH", Formula["gnu-tar"].opt_libexec/"gnubin"
    ENV.prepend_path "PATH", Formula["grep"].opt_libexec/"gnubin"

    system "./autogen.sh"
    system "./configure", *args
    system "gmake","-j 10", "CC=#{cc}"
    system "gmake", "install"

    icons_dir = buildpath/"nextstep/Emacs.app/Contents/Resources"
    ICONS_CONFIG.each_key do |icon|
      next if build.without? "#{icon}-icon"

      rm "#{icons_dir}/Emacs.icns"
      resource("#{icon}-icon").stage do
        icons_dir.install Dir["*.icns*"].first => "Emacs.icns"
      end
    end

    prefix.install "nextstep/Emacs.app"
    (prefix/"Emacs.app/Contents").install "native-lisp"

    inject_path
    inject_protected_resources_usage_desc

    (bin/"emacs").unlink # Kill the existing symlink
    (bin/"emacs").write <<~EOS
      #!/bin/bash
      exec #{prefix}/Emacs.app/Contents/MacOS/Emacs "$@"
    EOS
  end

  def post_install
    emacs_info_dir = info/"emacs"
    Dir.glob(emacs_info_dir/"*.info") do |info_filename|
      system "install-info", "--info-dir=#{emacs_info_dir}", info_filename
    end
  end

  def caveats
    <<~EOS
      Emacs.app was installed to:
        #{prefix}

      To link the application to default Homebrew App location:
        ln -s #{prefix}/Emacs.app /Applications

      Your PATH value was injected into Emacs.app/Contents/Info.plist

      Report any issues to http://github.com/d12frosted/homebrew-emacs-plus
    EOS
  end

  service do
    run [opt_bin/"emacs", "--fg-daemon"]
    keep_alive true
    log_path "/tmp/homebrew.mxcl.emacs-plus.stdout.log"
    error_log_path "/tmp/homebrew.mxcl.emacs-plus.stderr.log"
  end

  test do
    assert_equal "4", shell_output("#{bin}/emacs --batch --eval=\"(print (+ 2 2))\"").strip
  end
end
