{ lib
, boost
, buildPythonPackage
, cmake
, cryptography
, fetchFromGitHub
, git
, pc-ble-driver
, pythonAtLeast
, pythonOlder
, scikit-build
, setuptools
, swig
, wrapt
}:

buildPythonPackage rec {
  pname = "pc-ble-driver-py";
  version = "0.17.0";

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "NordicSemiconductor";
    repo = "pc-ble-driver-py";
    rev = "v${version}";
    sha256 = "0f41sy5lrf7kwkv00ar7jzm9y0mismdr4sqpvg8ss9pnmbfvgc3f";
  };

  nativeBuildInputs = [
    cmake
    swig
    git
    setuptools
    scikit-build
  ];

  buildInputs = [
    boost
    pc-ble-driver
  ];

  propagatedBuildInputs = [
    cryptography
    wrapt
  ];

  dontUseCmakeConfigure = true;

  # doCheck tries to write to the global python directory to install things
  doCheck = false;

  pythonImportsCheck = [
    "pc_ble_driver_py"
  ];

  meta = with lib; {
    description = "Bluetooth Low Energy nRF5 SoftDevice serialization";
    homepage = "https://github.com/NordicSemiconductor/pc-ble-driver-py";
    license = licenses.unfreeRedistributable;
    platforms = platforms.unix;
    maintainers = with maintainers; [ gebner ];
  };
}
