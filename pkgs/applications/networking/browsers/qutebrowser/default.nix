{ stdenv, lib, fetchurl, fetchzip, python3Packages
, makeWrapper, wrapGAppsHook, qtbase, glib-networking
, asciidoc, docbook_xml_dtd_45, docbook_xsl, libxml2
, libxslt, gst_all_1 ? null
, withPdfReader        ? true
, withMediaPlayback    ? true
}:

assert withMediaPlayback -> gst_all_1 != null;

let
  pdfjs = let
    version = "1.10.100";
  in
  fetchzip rec {
    name = "pdfjs-${version}";
    url = "https://github.com/mozilla/pdf.js/releases/download/v${version}/${name}-dist.zip";
    sha256 = "04df4cf6i6chnggfjn6m1z9vb89f01a0l9fj5rk21yr9iirq9rkq";
    stripRoot = false;
  };

in python3Packages.buildPythonApplication rec {
  pname = "qutebrowser";
  version = "1.6.3";

  # the release tarballs are different from the git checkout!
  src = fetchurl {
    url = "https://github.com/qutebrowser/qutebrowser/releases/download/v${version}/${pname}-${version}.tar.gz";
    sha256 = "0z9an14vlv0r48x7fk0mk7465gnhh19dx1w63lyhsgnfqy5pzlhy";
  };

  # Needs tox
  doCheck = false;

  buildInputs = [
    qtbase
    glib-networking
  ] ++ lib.optionals withMediaPlayback (with gst_all_1; [
    gst-plugins-base gst-plugins-good
    gst-plugins-bad gst-plugins-ugly gst-libav
  ]);

  nativeBuildInputs = [
    makeWrapper wrapGAppsHook asciidoc
    docbook_xml_dtd_45 docbook_xsl libxml2 libxslt
  ];

  propagatedBuildInputs = with python3Packages; [
    pyyaml pyqt5 pyqtwebengine jinja2 pygments
    pypeg2 cssutils pyopengl attrs
    # scripts and userscripts libs
    tldextract beautifulsoup4
    pyreadability pykeepass stem
  ];

  patches = [
    ./fix-restart.patch
  ];

  postPatch = ''
    substituteInPlace qutebrowser/app.py --subst-var-by qutebrowser "$out/bin/qutebrowser"

    sed -i "s,/usr/share/,$out/share/,g" qutebrowser/utils/standarddir.py
  '' + lib.optionalString withPdfReader ''
    sed -i "s,/usr/share/pdf.js,${pdfjs},g" qutebrowser/browser/pdfjs.py
  '';

  postBuild = ''
    a2x -f manpage doc/qutebrowser.1.asciidoc
  '';

  postInstall = ''
    install -Dm644 doc/qutebrowser.1 "$out/share/man/man1/qutebrowser.1"
    install -Dm644 misc/qutebrowser.desktop \
        "$out/share/applications/qutebrowser.desktop"

    # Install icons
    for i in 16 24 32 48 64 128 256 512; do
        install -Dm644 "icons/qutebrowser-''${i}x''${i}.png" \
            "$out/share/icons/hicolor/''${i}x''${i}/apps/qutebrowser.png"
    done
    install -Dm644 icons/qutebrowser.svg \
        "$out/share/icons/hicolor/scalable/apps/qutebrowser.svg"

    # Install scripts
    sed -i "s,/usr/bin/,$out/bin/,g" scripts/open_url_in_instance.sh
    install -Dm755 -t "$out/share/qutebrowser/scripts/" $(find scripts -type f)
    install -Dm755 -t "$out/share/qutebrowser/userscripts/" misc/userscripts/*

    # Patch python scripts
    buildPythonPath "$out $propagatedBuildInputs"
    scripts=$(grep -rl python "$out"/share/qutebrowser/{user,}scripts/)
    for i in $scripts; do
      patchPythonScript "$i"
    done
  '';

  meta = with stdenv.lib; {
    homepage    = https://github.com/The-Compiler/qutebrowser;
    description = "Keyboard-focused browser with a minimal GUI";
    license     = licenses.gpl3Plus;
    maintainers = with maintainers; [ jagajaga rnhmjoj ];
  };
}
