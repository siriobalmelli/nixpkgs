{ stdenv, python37Packages, fetchFromGitHub }:

with python37Packages; buildPythonApplication rec {
  pname = "nrfutil";
  version = "6.1";

  src = fetchFromGitHub {
    repo = "pc-nrfutil";
    #rev = "v${version}";
    #owner = "NordicSemiconductor";
    #sha256 = "0g43lf5jmk0qxb7r4h68wr38fli6pjjk67w8l2cpdm9rd8jz4lpn";
    rev = "master";
    owner = "siriobalmelli-foss";
    sha256 = "0sqik1g74ghpn8b2sh7mzlwf796l95pzshgb51ihsil00mv5nyd6";
  };
  #src = ~/repos/foss/pc-nrfutil;

  propagatedBuildInputs = [ pc-ble-driver-py six pyserial enum34  click ecdsa
    protobuf tqdm piccata pyspinel intelhex pyyaml crcmod libusb1 ipaddress ];

  checkInputs = [ nose behave ];

  postPatch = ''
    mkdir test-reports
  '';

  meta = with stdenv.lib; {
    description = "Device Firmware Update tool for nRF chips";
    homepage = "https://github.com/NordicSemiconductor/pc-nrfutil";
    license = licenses.unfreeRedistributable;
    platforms = platforms.unix;
    maintainers = with maintainers; [ gebner ];
  };
}
