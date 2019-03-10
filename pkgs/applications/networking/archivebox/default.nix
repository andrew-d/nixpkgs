{ stdenv
, lib
, fetchFromGitHub
, makeWrapper

, coreutils
, curl
, git
, gnused
, python3
, wget
, which
, youtube-dl

, withChrome ? true, google-chrome
}:

stdenv.mkDerivation rec {
  name = "archivebox-${version}";
  version = "0.2.4";

  src = fetchFromGitHub {
    owner = "pirate";
    repo = "ArchiveBox";
    rev = "v${version}";
    sha256 = "1si7wh6n9vdhkfm2ggzr1w3v85pcfmszfsl0kpnvpizdv1mplwpd";
  };

  nativeBuildInputs = [ gnused makeWrapper ];
  buildInputs = [ python3 ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib $out/bin

    cp -R archivebox $out/lib
    ln -s $out/lib/archivebox/archive.py $out/bin/archivebox
    ln -s $out/lib/archivebox/purge.py $out/bin/archivebox-purge

    patchShebangs $out/lib/archivebox
    sed -Ei \
      -e 's|GIT_SHA = run\(.*|GIT_SHA = "${version}"|g' \
      "$out/lib/archivebox/config.py" \

    for prog in "$out/bin/"*; do
      wrapProgram "$prog" \
        --prefix PYTHONPATH : "$PYTHONPATH" \
        --prefix PATH : "${lib.makeBinPath [ coreutils which ]}" \
        --set-default WGET_BINARY      "${wget}/bin/wget" \
        --set-default GIT_BINARY       "${git}/bin/git" \
        --set-default CURL_BINARY      "${curl}/bin/curl" \
        --set-default YOUTUBEDL_BINARY "${youtube-dl}/bin/youtube-dl" \
        ${if withChrome then "--set-default CHROME_BINARY \"${google-chrome}/bin/\"google-chrome*" else ""}
    done

    runHook postInstall
  '';

  meta = with stdenv.lib; {
    description = "The open source self-hosted web archive.";
    homepage    = https://github.com/pirate/ArchiveBox;
    license     = licenses.mit;
    maintainers = with maintainers; [ andrew-d ];
    platforms   = platforms.unix;
  };
}
