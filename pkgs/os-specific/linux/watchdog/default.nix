{ stdenv
, fetchurl

, runDir ? "/run"
}:

stdenv.mkDerivation rec {
  pname = "watchdog";
  version = "5.15";
  name = "${pname}-${version}";

  src = fetchurl {
    url = "mirror://sourceforge/${pname}/${pname}-${version}.tar.gz";
    sha256 = "0z4l306aylnb401p4dj63dni7jp69nnjpljbcr9qwpdd6x8qdp7z";
  };

  configureFlags = [
    "--with-configfile=/etc/watchdog.conf"
    "--with-pidfile=${runDir}/watchdog.pid"
    "--with-ka_pidfile=${runDir}/wd_keepalive.pid"
    "--with-randomseed=${runDir}/wd_random_seed"
    "--with-test-bin-path=/var/empty" # can be set in config file
  ];

  # Avoid attempting to install the default `/etc/watchdog.conf` file, which is
  # run by `make install-data` and `make install`.
  installTargets = [ "install-exec" "install-man" ];

  meta = with stdenv.lib; {
    description = "Software watchdog for Linux";
    homepage = https://sourceforge.net/projects/watchdog/;
    license = licenses.gpl2;
    maintainers = [ maintainers.andrew-d ];
    platforms = platforms.linux;
  };
}
