{ lib, stdenv, fetchFromGitHub
, curl
, jdk
, libedit
, srt
}:

stdenv.mkDerivation rec {
  pname = "tsduck";
  version = "v3.31-2761";

  src = fetchFromGitHub {
    owner = "tsduck";
    repo = pname;
    rev = version;
    sha256 = "sha256-268TKCh3naebbw+sOQ6d4N/zl7UEVtc3l3flFAYHDU4=";
  };

  buildInputs = [
    curl
    libedit
    srt
  ] ++ lib.optionals stdenv.isLinux [
    jdk
  ];

  installFlags = [
    "SYSROOT=${placeholder "out"}"
    "SYSPREFIX=/"
    "USRLIBDIR=/lib"
  ];
  installTargets = [
    "install-tools"
    "install-devel"
  ];

  enableParallelBuilding = true;
  makeFlags = [
    "NODEKTEC=1"
    "NOHIDES=1"
    "NOPCSC=1"
    "NORIST=1"
    "NOTEST=1"
    "NOVATEK=1"
  ] ++ installFlags;
  doCheck = false;

  meta = with lib; {
    description = "The MPEG Transport Stream Toolkit";
    homepage    = "https://github.com/tsduck/tsduck";
    license     = licenses.bsd2;
    maintainers = with maintainers; [ siriobalmelli ];
    platforms   = platforms.all;
  };
}
