{
  bash,
  bbe,
  binutils,
  coreutils,
  darwin, # darwin.DarwinTools provides sw_vers
  fetchFromGitHub,
  fetchurl,
  lib,
  libxml2,
  llvmPackages_22, # seed binary uses LLVM 22 APIs
  makeWrapper,
  nix-update-script,
  patchelf,
  replaceVars,
  runCommandCC,
  stdenv,
  symlinkJoin,
  zig,
  zlib,
  zstd,
}:

let
  llvmPackages = llvmPackages_22;

  gccDir = "${stdenv.cc.cc}/lib/gcc/${stdenv.hostPlatform.config}/${stdenv.cc.cc.version}";
  libcIncludeDir = "${lib.getDev stdenv.cc.libc}/include";
  libcLibDir = "${lib.getLib stdenv.cc.libc}/lib";

  # build hard-requires LLVM_PREFIX/lib/libclang.a (static).
  libclangStatic = llvmPackages.libclang.override {
    devExtraCmakeFlags = [ (lib.cmakeBool "LIBCLANG_BUILD_STATIC" true) ];
  };
  # Build variants that produce static archives alongside the shared libs:
  # - libxml2 with enableStatic = true exposes libxml2.a in the 'static' output.
  # - zstd with enableStatic = true builds libzstd.a in the default 'out' output.
  # - zlib already ships libz.a in its 'static' output.
  libxml2Static = libxml2.override { enableStatic = true; };
  zstdStatic = zstd.override { enableStatic = true; };

  # Inject static archives into the LLVM link RSP so libLLVM*.a's
  # references to compress2/uncompress/crc32/xml* resolve at link time.
  # Inject absolute static archive paths immediately before -lm
  # so that ld64.lld resolves zlib/zstd/libxml2 symbols pulled in from libLLVM*.a
  # statically (no dynamic library dependency in the final binary).
  # The build/compiler.w generator does not emit -lz/-lzstd/-lxml2
  # because upstream expects a static LLVM SDK built without those features;
  # nixpkgs LLVM has them enabled, so we patch them in.
  linkRSPinjectionDarwin = lib.concatStringsSep "\\n" [
    "${zlib.static}/lib/libz.a"
    "${zstdStatic.out}/lib/libzstd.a" # lib.getLib resolves to 'bin' output
    "${libxml2Static.static}/lib/libxml2.a"
    "-L${lib.getLib llvmPackages.libcxx}/lib" # -L for libcxx so the unwrapped ld64.lld can resolve -lc++
    "-lm"
  ];
  linkRSPinjectionLinux = lib.concatStringsSep "\\n" [
    "${zlib.static}/lib/libz.a"
    "${zstdStatic.out}/lib/libzstd.a" # lib.getLib resolves to 'bin' output
    "${libxml2Static.static}/lib/libxml2.a"
  ];
  linkRSPinjectionLinuxLd = lib.concatStringsSep "\\n" [
    "-Bstatic"
    "${stdenv.cc.cc}/lib/libstdc++.a"
    "${gccDir}/libgcc.a"
    "${gccDir}/libgcc_eh.a"
    "-Bdynamic"
    "-lpthread"
    "-ldl"
    "-lm"
    "${zlib.static}/lib/libz.a"
    "${zstdStatic.out}/lib/libzstd.a" # lib.getLib resolves to 'bin' output
    "${libxml2Static.static}/lib/libxml2.a"
  ];

  # The build graph expects a single LLVM_PREFIX with bin/, lib/, and include/.
  # In nixpkgs, clang, llvm, lld, and libclang are split across separate store paths.
  llvmPrefix = symlinkJoin {
    name = "llvm-prefix-for-withlang";
    paths = with llvmPackages; [
      clang-unwrapped # bin/clang
      lld # bin/lld, bin/ld64.lld
      llvm.dev # bin/llvm-config, include/
      llvm # bin/llc, bin/opt etc.
      llvm.lib # lib/libLLVM*.a static archives
      libclangStatic.lib # lib/libclang.a + libclang.dylib + libclang*.a
    ];
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "withlang";
  version = "0.14.7";

  src = fetchFromGitHub {
    owner = "withlang-dev";
    repo = "with";
    rev = "v${finalAttrs.version}";
    hash = "sha256-jTmP/1PUlTCsJjpK9bXz0hKwu+LqTOw16gw9BgNP/24=";
  };

  nativeBuildInputs = [
    llvmPackages.lld # -fuse-ld=lld for linking compiler stages
    makeWrapper # wrap bin/with with LLVM_PREFIX so the shipped binary works standalone
    zig # emit-c test compiles emitted C with 'zig cc'
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    bbe
    binutils
    patchelf
  ];

  # 'with' invokes the unwrapped clang from LLVM_PREFIX/bin/clang to link user programs.
  # That clang needs cc-wrapper's setup-hook (and the apple-sdk it transitively propagates)
  # to find SDKROOT and friends.
  propagatedNativeBuildInputs = lib.optionals stdenv.hostPlatform.isDarwin [
    llvmPackages.clang
  ];

  # libcxx needed so ld64.lld resolves the bare -lc++ that build/compiler.w emits.
  # Static libraries are injected via patches.
  buildInputs = lib.optionals stdenv.hostPlatform.isDarwin [
    llvmPackages.libcxx
  ];

  strictDeps = true;
  __structuredAttrs = true;

  # Makefile uses a serial lock; parallel make will deadlock.
  enableParallelBuilding = false;

  # zig is a build dependency for the emit-c test ('zig cc');
  # we don't want zig's setup-hook to replace make build/check/install phases.
  # zigConfigurePhase is left enabled to set ZIG_GLOBAL_CACHE_DIR for 'zig cc'.
  dontUseZigBuild = true;
  dontUseZigCheck = true;
  dontUseZigInstall = true;

  # Upstream Makefile's first target is $(OUT_TMP_DIR), not 'all';
  # so 'make' with no target builds nothing useful: spell out targets.
  buildFlags = [ "build" ];

  patches = [
    ./skip-conan-test.patch
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    (replaceVars ./compiler-w-link-rsp-darwin.patch {
      inherit linkRSPinjectionDarwin;
    })
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    (replaceVars ./compiler-w-link-rsp-linux.patch {
      inherit linkRSPinjectionLinuxLd linkRSPinjectionLinux;
    })
    (replaceVars ./link-w-linux-paths.patch {
      inherit gccDir libcLibDir;
      ccLibDir = "${stdenv.cc.cc}/lib";
      dynamicLinker = stdenv.cc.bintools.dynamicLinker;
    })
    (replaceVars ./clang-bridge-w-isystem.patch {
      inherit libcIncludeDir;
    })
    (replaceVars ./cimport-w-isystem.patch {
      inherit libcIncludeDir;
    })
  ]
  ++ [
    (replaceVars ./test-paths.patch {
      inherit bash coreutils;
    })
  ];

  postUnpack =
    lib.optionalString stdenv.hostPlatform.isDarwin ''
      # The compiler emits objects via LLVMGetDefaultTargetTriple;
      # on Darwin this embeds the host's kernel version (e.g. darwin24.6.0)
      # and ignores MACOSX_DEPLOYMENT_TARGET:
      # set our deployment target to the build host's macOS version so ld does
      # not warn about a mismatch (and break tests that match stderr exactly).
      export MACOSX_DEPLOYMENT_TARGET=$(${lib.getExe' darwin.DarwinTools "sw_vers"} -productVersion)
    ''
    + ''
      install -m0755 ${finalAttrs.passthru.seedBin} $sourceRoot/src/main
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      # The Linux seed hardcodes FHS linker paths. Patch exact-length aliases
      # for bootstrap only; postInstall verifies the final compiler has none.
      patchelf \
        --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
        --set-rpath ${lib.makeLibraryPath [ stdenv.cc.libc ]} \
        $sourceRoot/src/main

      seed_size_before_bbe=$(stat -c%s $sourceRoot/src/main)
      bbe \
        -e 's|/lib64/ld-linux-x86-64.so.2|/build/ld-linux-x86-64.so.2|' \
        -e 's|/usr/lib/x86_64-linux-gnu/|/build/glibc-link-objects/|' \
        -e 's|/usr/lib/gcc/x86_64-linux-gnu/14|/build/gcc-crt-and-libgcc-dir-01|' \
        -e 's|-L/usr/lib/x86_64-linux-gnu|-L/build/glibc-link-objects|' \
        -o $sourceRoot/src/main.patched \
        $sourceRoot/src/main
      mv $sourceRoot/src/main.patched $sourceRoot/src/main
      chmod +x $sourceRoot/src/main
      seed_size_after_bbe=$(stat -c%s $sourceRoot/src/main)
      if [ "$seed_size_before_bbe" != "$seed_size_after_bbe" ]; then
        echo "FAIL: Linux seed size changed during byte patch" >&2
        exit 1
      fi

      mkdir -p /build/gcc-crt-and-libgcc-dir-01 /build/glibc-link-objects
      ln -s ${stdenv.cc.bintools.dynamicLinker} /build/ld-linux-x86-64.so.2
      ln -s ${libcLibDir}/crt1.o /build/glibc-link-objects/crt1.o
      ln -s ${libcLibDir}/crti.o /build/glibc-link-objects/crti.o
      ln -s ${libcLibDir}/crtn.o /build/glibc-link-objects/crtn.o
      ln -s ${libcLibDir}/libc.so /build/glibc-link-objects/libc.so
      ln -s ${libcLibDir}/libdl.so /build/glibc-link-objects/libdl.so
      ln -s ${libcLibDir}/libm.so /build/glibc-link-objects/libm.so
      ln -s ${libcLibDir}/libpthread.so /build/glibc-link-objects/libpthread.so
      ln -s ${gccDir}/crtbegin.o /build/gcc-crt-and-libgcc-dir-01/crtbegin.o
      ln -s ${gccDir}/crtend.o /build/gcc-crt-and-libgcc-dir-01/crtend.o
      ln -s ${gccDir}/libgcc.a /build/gcc-crt-and-libgcc-dir-01/libgcc.a
      ln -s ${gccDir}/libgcc_eh.a /build/gcc-crt-and-libgcc-dir-01/libgcc_eh.a
      ln -s ${stdenv.cc.cc}/lib/libstdc++.a /build/gcc-crt-and-libgcc-dir-01/libstdc++.a
    '';

  preBuild = ''
    mkdir -p .deps
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    ln -s ${llvmPrefix} .deps/llvm-22.1.6-darwin-arm64
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    ln -s ${llvmPrefix} .deps/llvm-22.1.6-linux-x86_64
  ''
  + ''
    export LLVM_PREFIX="${llvmPrefix}"
    export WITH_VERSION="v${finalAttrs.version}" # TODO: remove when rectified
    export HOME=$(mktemp -d) # compiler clears ~/.cache/with during stage transitions
  '';

  doCheck = true;
  checkTarget = "test"; # full test suite

  # Upstream BuildGraphOps.w reads PREFIX (defaults to /usr/local).
  installFlags = [ "PREFIX=$(out)" ];

  # Match upstream's release packaging gate (scripts/package-darwin-aarch64.sh):
  # the produced binary must not load clang/LLVM/libz/libxml2/zstd dynamically.
  # Run before fixup so we inspect the unwrapped Mach-O binary.
  postInstall =
    lib.optionalString stdenv.hostPlatform.isDarwin ''
      if otool -L $out/bin/with | grep -E 'clang|LLVM|libz|libxml2|zstd' >/dev/null 2>&1; then
        echo "FAIL: $out/bin/with has forbidden dynamic dependencies:" >&2
        otool -L $out/bin/with >&2
        exit 1
      fi
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      if readelf -d $out/bin/with | grep NEEDED | grep -E 'clang|LLVM|libz|libxml2|zstd|libstdc|libgcc_s' >/dev/null 2>&1; then
        echo "FAIL: $out/bin/with has forbidden dynamic dependencies:" >&2
        readelf -d $out/bin/with | grep NEEDED >&2
        exit 1
      fi
      if strings $out/bin/with | grep -E '^/build/(ld-linux|glibc-link|gcc-crt)' >/dev/null 2>&1; then
        echo "FAIL: $out/bin/with contains Linux seed paths:" >&2
        strings $out/bin/with | grep -E '^/build/(ld-linux|glibc-link|gcc-crt)' >&2
        exit 1
      fi
    '';

  # Wrap so the shipped 'with' resolves clang/lld via our LLVM tree by default.
  # End users can still override with WITH_LLVM_CC or LLVM_PREFIX in their own environment.
  postFixup = ''
    wrapProgram $out/bin/with --set-default LLVM_PREFIX "${llvmPrefix}"
  '';

  passthru = {
    updateScript = nix-update-script { };

    # Seed binaries are pre-built compilers used to bootstrap stage1.
    seedBase = "https://github.com/withlang-dev/with/releases/download/v${finalAttrs.version}";
    seedBin =
      {
        aarch64-darwin = fetchurl {
          url = "${finalAttrs.passthru.seedBase}/with-darwin-aarch64";
          hash = "sha256-c0NYEVzFFmMQ/mUh1xf707mNM1fDlHHWDFnXj3ytf+M=";
        };
        x86_64-linux = fetchurl {
          url = "${finalAttrs.passthru.seedBase}/with-linux-x86_64";
          hash = "sha256-L55Pwzh8aGJzN0UTLcdDUz0YFDLrziHsZovxfU/RhTI=";
        };
      }
      .${stdenv.hostPlatform.system};

    # 'with -e' compiles and runs the snippet as a top-level statement.
    tests.smoke = runCommandCC "${finalAttrs.pname}-smoke-test" { } ''
      # TODO: remove 2>/dev/null when upstream:
      # - stops attempting to write .a files into the install prefix
      # - emits objects whose macOS minos doesn't mismatch the link target
      ${lib.getExe finalAttrs.finalPackage} -e 'print("hello, with")' 2>/dev/null >$out
      diff $out <(echo "hello, with")
    '';
  };

  meta = {
    description = "Systems programming language with a self-hosted compiler";
    homepage = "https://github.com/withlang-dev/with";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ siriobalmelli ];
    mainProgram = "with";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
  };
})
