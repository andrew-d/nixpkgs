{ stdenv
, fetchFromGitHub
, gradle_5
, jre
, perl
, git
, protobuf3_6
, writeText
, runtimeShell
}:

let
  pname = "mirror";
  version = "1.3.9";

  src = fetchFromGitHub {
    owner = "stephenh";
    repo = "mirror";
    rev = "${version}";
    sha256 = "04aaiz35bq49q2wf3m8411cszn7l77pwibwgxzq8f53sf8lnhpnn";
  };

  # Needs to match the version specified in build.gradle
  protoc-gen-grpc-java = stdenv.mkDerivation rec {
    pname = "protoc-gen-java";
    version = "1.22.1";

    src = fetchFromGitHub {
      owner = "grpc";
      repo = "grpc-java";
      rev = "v${version}";
      sha256 = "04l7a345b564hw4ys1v8jliis22mr4wkb39ns2sjcfsz2ywj519w";
    };

    sourceRoot = "source/compiler/src/java_plugin/cpp";

    buildInputs = [ protobuf3_6 ];

    buildPhase = ''
      mkdir -p "$out/bin"

      set -x

      for f in *.cpp; do
        $CXX \
          -std=c++0x \
          -DGRPC_VERSION=${version} \
          -c -o "''${f%.cpp}.o" \
          "$f"
      done

      $CXX \
        -L${protobuf3_6}/lib \
        -lprotoc -lprotobuf -lpthread \
        -s \
        -o "$out/bin/protoc-gen-grpc-java" \
        *.o
    '';

    installPhase = "true";

    meta = with stdenv.lib; {
      description = "protobuf plugin for gRPC in Java";
      homepage = "https://github.com/grpc/grpc-java/";
      license = licenses.asl20;
      maintainers = with maintainers; [ andrew-d ];
    };
  };

  patchPhase = ''
    sed -i \
      -e 's|artifact = "com.google.protobuf:protoc.*$|path = "${protobuf3_6}/bin/protoc"|g' \
      -e 's|artifact = "io.grpc:protoc-gen-grpc-java.*$|path = "${protoc-gen-grpc-java}/bin/protoc-gen-grpc-java"|g' \
      -e "/archiveVersion = /a baseName = 'mirror'" \
      build.gradle
  '';

  nativeBuildInputs = [
    gradle_5
    perl
    git
    protobuf3_6
    protoc-gen-grpc-java
  ];

  buildInputs = [
    protobuf3_6
  ];

  deps = stdenv.mkDerivation {
    pname = "${pname}-deps";
    inherit src version;

    inherit patchPhase nativeBuildInputs buildInputs;

    buildPhase = ''
      export GRADLE_USER_HOME=$(mktemp -d)
      gradle -Dfile.encoding=utf-8 shadowJar;
    '';

    # Mavenize dependency paths
    # e.g. org.codehaus.groovy/groovy/2.4.0/{hash}/groovy-2.4.0.jar -> org/codehaus/groovy/groovy/2.4.0/groovy-2.4.0.jar
    installPhase = ''
      find $GRADLE_USER_HOME/caches/modules-2 -type f -regex '.*\.\(jar\|pom\)' \
        | perl -pe 's#(.*/([^/]+)/([^/]+)/([^/]+)/[0-9a-f]{30,40}/([^/\s]+))$# ($x = $2) =~ tr|\.|/|; "install -Dm444 $1 \$out/$x/$3/$4/$5" #e' \
        | sh
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "0g2zvypicm7l463ai89sdlwyglb06cl2sn6gp0p66lwsjzrysqqs";
  };

  # Point to our local deps repo
  gradleInit = writeText "init.gradle" ''
    logger.lifecycle 'Replacing Maven repositories with ${deps}...'
    gradle.projectsLoaded {
      rootProject.allprojects {
        buildscript {
          repositories {
            clear()
            maven { url '${deps}' }
          }
        }
        repositories {
          clear()
          maven { url '${deps}' }
        }
      }
    }

    settingsEvaluated { settings ->
      settings.pluginManagement {
        repositories {
          maven { url '${deps}' }
        }
      }
  }
  '';

in stdenv.mkDerivation rec {
  inherit pname version src;

  inherit patchPhase nativeBuildInputs buildInputs;

  buildPhase = ''
    export GRADLE_USER_HOME=$(mktemp -d)
    gradle --offline --no-daemon --info --init-script ${gradleInit} shadowJar
  '';

  installPhase = ''
    mkdir -p $out/bin $out/share/mirror
    cp build/libs/mirror-all.jar $out/share/mirror/mirror.jar

    cat  << EOF > $out/bin/mirror
    #!${runtimeShell}
    exec ${jre}/bin/java -Xmx2G -XX:+HeapDumpOnOutOfMemoryError -cp "$out/share/mirror/mirror.jar" mirror.Mirror "\$@"
    EOF
    chmod a+x "$out/bin/mirror"
  '';

  meta = with stdenv.lib; {
    description = "A tool for real-time, two-way sync for remote (e.g. desktop/laptop) development";
    homepage = "https://github.com/stephenh/mirror";
    license = licenses.asl20;
    maintainers = with maintainers; [ andrew-d ];
    platforms = platforms.unix;
  };
}
