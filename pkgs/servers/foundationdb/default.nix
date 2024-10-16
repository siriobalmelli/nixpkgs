{ gccStdenv, llvmPackages
, lib, fetchFromGitHub, fetchpatch

, cmake, ninja, python3, openjdk8, mono, openssl, boost178
, pkg-config, msgpack-cxx, toml11
, nixosTests
}@args:

let
  cmakeBuild = import ./cmake.nix args;
in {
  foundationdb71 = cmakeBuild {
    version = "7.1.62";
    hash    = "sha256-4IsOx691EFrSbOx4cpmhPyOam4tbx0BSScKMfE3qBV0=";
    boost   = boost178;
    ssl     = openssl;

    patches = [
      ./patches/disable-flowbench.patch
      ./patches/don-t-run-tests-requiring-doctest.patch
      ./patches/don-t-use-static-boost-libs.patch
      ./patches/fix-open-with-O_CREAT.patch
      # GetMsgpack: add 4+ versions of upstream
      # https://github.com/apple/foundationdb/pull/10935
      (fetchpatch {
        url = "https://github.com/apple/foundationdb/commit/c35a23d3f6b65698c3b888d76de2d93a725bff9c.patch";
        hash = "sha256-bneRoZvCzJp0Hp/G0SzAyUyuDrWErSpzv+ickZQJR5w=";
      })
    ];
  } // {
    passthrough.tests = {
      inherit (nixosTests) foundationdb;
    };
  };
}
