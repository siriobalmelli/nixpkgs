{ stdenv, python3Packages, fetchFromGitHub }:

with python3Packages; buildPythonApplication rec {
  pname = "nrfutil";
  version = "6.1";

  src = fetchFromGitHub {
    repo = "pc-nrfutil";
    rev = "a540fe45587287be9d61c8b0d2de9ba4a1c19162";
    #rev = "v${version}";
    owner = "NordicSemiconductor";
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
