{ stdenv, lib, fetchurl, fetchpatch, pkgconfig, flex, bison, libxslt, autoconf, automake, autoreconfHook
, graphviz, glib, libiconv, libintl, libtool, expat
}:

let
  generic = lib.makeOverridable ({
    major, minor, sha256,
    extraNativeBuildInputs ? [],
    extraBuildInputs ? [],
    withGraphviz ? true
  }:
  let
    atLeast = lib.versionAtLeast "${major}.${minor}";

    # Patches from the openembedded-core project to build vala without graphviz
    # support. We need to apply an additional patch to allow building when the
    # header file isn't available at all, but that patch (./gvc-compat.patch)
    # can be shared between all versions of Vala so far.
    graphvizPatch =
      let
        fp = { commit, sha256 }: fetchpatch {
          url = "https://github.com/openembedded/openembedded-core/raw/${commit}/meta/recipes-devtools/vala/vala/disable-graphviz.patch";
          inherit sha256;
        };

      in {
        "0.38" = fp {
          commit = "2c290f7253bba5ceb0d32e7d0b0ec0d0e81cc263";
          sha256 = "056ybapfx18d7xw1k8k85nsjrc26qk2q2d9v9nz2zrcwbq5brhkp";
        };
        "0.40" = fp {
          commit = "dfbbff39cfd413510abbd60930232a9c6b35d765";
          sha256 = "19iyrljirpz63wi539bjnd06nq62dih2la3j93ckkv44jlc110s2";
        };
        "0.42" = fp {
          commit = "8553c52f174af4c8c433c543f806f5ed5c1ec48c";
          sha256 = "0qhvp3846l9jkkl894kcmriyzzfp66qwy5hcngagg6hg061wr8al";
        };
      }.${major} or (throw "no graphviz patch for this version of vala");

    disableGraphviz = atLeast "0.38" && !withGraphviz;

  in stdenv.mkDerivation rec {
    name = "vala-${version}";
    version = "${major}.${minor}";

    src = fetchurl {
      url = "mirror://gnome/sources/vala/${major}/${name}.tar.xz";
      inherit sha256;
    };

    postPatch = ''
      patchShebangs tests
    '';

    # If we're disabling graphviz, apply the patches and corresponding
    # configure flag. We also need to override the path to the valac compiler
    # so that it can be used to regenerate documentation.
    patches        = if disableGraphviz then [ graphvizPatch ./gvc-compat.patch ] else null;
    configureFlags = if disableGraphviz then "--disable-graphviz" else null;
    preBuild       = if disableGraphviz then "buildFlagsArray+=(\"VALAC=$(pwd)/compiler/valac\")" else null;

    outputs = [ "out" "devdoc" ];

    nativeBuildInputs = [
      pkgconfig flex bison libxslt
    ] ++ lib.optional (stdenv.isDarwin && (atLeast "0.38")) expat
      ++ lib.optional disableGraphviz autoreconfHook # if we changed our ./configure script, need to reconfigure
      ++ extraNativeBuildInputs;

    buildInputs = [
      glib libiconv libintl
    ] ++ lib.optional (atLeast "0.38" && withGraphviz) graphviz
      ++ extraBuildInputs;

    doCheck = false; # fails, requires dbus daemon

    meta = with stdenv.lib; {
      description = "Compiler for GObject type system";
      homepage = https://wiki.gnome.org/Projects/Vala;
      license = licenses.lgpl21Plus;
      platforms = platforms.unix;
      maintainers = with maintainers; [ antono jtojnar lethalman peterhoeg ];
    };
  });

in rec {
  vala_0_34 = generic {
    major   = "0.34";
    minor   = "17";
    sha256  = "0wd2zxww4z1ys4iqz218lvzjqjjqwsaad4x2by8pcyy43sbr7qp2";
  };

  vala_0_36 = generic {
    major   = "0.36";
    minor   = "13";
    sha256  = "0gxz7yisd9vh5d2889p60knaifz5zndgj98zkdfkkaykdfdq4m9k";
  };

  vala_0_38 = generic {
    major   = "0.38";
    minor   = "9";
    sha256  = "1dh1qacfsc1nr6hxwhn9lqmhnq39rv8gxbapdmj1v65zs96j3fn3";
    extraNativeBuildInputs = [ autoconf ] ++ lib.optional stdenv.isDarwin libtool;
  };

  vala_0_40 = generic {
    major   = "0.40";
    minor   = "6";
    sha256  = "1qjbwhifwwqbdg5zilvnwm4n76g8p7jwqs3fa0biw3rylzqm193d";
  };

  vala = vala_0_38;
}
