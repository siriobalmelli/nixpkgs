{ lib, stdenv, fetchpatch, fetchFromGitHub
, cmake, git
, asio, catch2, spdlog
, IOKit, udev
}:

stdenv.mkDerivation rec {
  pname = "pc-ble-driver";
  version = "4.1.4";

  src = fetchFromGitHub {
    owner = "NordicSemiconductor";
    repo = pname;
    rev = "c0ffd419";
    sha256 = "sha256-E3yadc/OdinWtDyPd14vmBGDF2+OwO+Ar5RqYD3srvI=";
  };

  cmakeFlags = [
    "-DNRF_BLE_DRIVER_VERSION=${version}"
  ] ++ lib.optionals (stdenv.isDarwin && stdenv.isAarch64) [
    "-DARCH=arm64"
  ];

  nativeBuildInputs = [ cmake git ];
  buildInputs = [ asio catch2 spdlog ];

  propagatedBuildInputs = [

  ] ++ lib.optionals stdenv.isDarwin [
    IOKit
  ] ++ lib.optionals stdenv.isLinux [
    udev
  ];

  meta = with lib; {
    description = "Desktop library for Bluetooth low energy development";
    homepage = "https://github.com/NordicSemiconductor/pc-ble-driver";
    license = licenses.unfreeRedistributable;
    platforms = platforms.unix;
  };
}
