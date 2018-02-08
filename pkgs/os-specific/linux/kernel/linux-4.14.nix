{ stdenv, hostPlatform, fetchurl, perl, buildLinux, ... } @ args:

with stdenv.lib;

import ./generic.nix (args // rec {
  version = "4.14.20";

  # branchVersion needs to be x.y
  extraMeta.branch = concatStrings (intersperse "." (take 2 (splitString "." version)));

  src = fetchurl {
    url = "https://github.com/hardkernel/linux/archive/4.14.20-108.tar.gz";
    sha256 = "180zf9zg33ssa2lg1vpp8pw6yzjff4f0wmwrpmpmv9mbr483xhcs";
  };
} // (args.argsOverride or {}))
