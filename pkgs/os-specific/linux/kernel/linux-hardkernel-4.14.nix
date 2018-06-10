{ stdenv, hostPlatform, fetchurl, perl, buildLinux, ... } @ args:

with stdenv.lib;

import ./generic.nix (args // rec {
  version = "4.14.47-139";

  # modDirVersion needs to be x.y.z.
  modDirVersion = head (splitString "-" version);

  # branchVersion needs to be x.y.
  extraMeta.branch = concatStrings (intersperse "." (take 2 (splitString "." modDirVersion)));

  extraConfig = ''
    # Fix a compilation error where we can't find the correct headers. Gator is
    # an agent for the ARM Streamline performance analyzer, which we don't
    # currently want to use anyway.
    # If we ever want to enable this, we need to set the following:
    #     GATOR_MALI_MIDGARD_PATH "drivers/gpu/arm/midgard"
    #
    # and somehow fix the include path for "mali_kbase_backend_config.h"
    GATOR n

    # Enable things that the defconfig does and seem to not get set properly.
    CRYPTO_DEV_EXYNOS_HASH y
    DRM_EXYNOS_G2D y
  '';

  src = fetchurl {
    url = "https://github.com/hardkernel/linux/archive/${version}.tar.gz";
    sha256 = "1n43a3rhpjq851qrn17r1dkibv6sqlmwxvl3hras4qr391x61y6n";
  };
} // (args.argsOverride or {}))
