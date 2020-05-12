{ system, bootstrapFiles }:

let
  # Conditional to avoid rebuild of Linux
  unpack-script = if (system == "armv5tel-linux" || system == "armv6l-linux" || system == "armv7l-linux")
                  then ./scripts/unpack-bootstrap-tools-new.sh
                  else ./scripts/unpack-bootstrap-tools.sh;

in derivation {
  name = "bootstrap-tools";

  builder = bootstrapFiles.busybox;

  args = [ "ash" "-e" unpack-script ];

  tarball = bootstrapFiles.bootstrapTools;

  inherit system;

  # Needed by the GCC wrapper.
  langC = true;
  langCC = true;
  isGNU = true;
}
