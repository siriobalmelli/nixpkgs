{
  lib,

  buildPythonApplication,
  fetchPypi,
  pythonOlder,

  dashing,
  psutil,
}:

buildPythonApplication rec {
  pname = "asitop";
  version = "0.0.24";
  format = "setuptools";

  disabled = pythonOlder "3.7";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-Xfe1kwRXKpSPcc+UuHrcYThpqKh6kzWVsbPia/QsPjc=";
  };

  # has no tests
  doCheck = false;

  propagatedBuildInputs = [
    dashing
    psutil
  ];

  meta = with lib; {
    homepage = "https://github.com/tlkh/asitop";
    description = "Perf monitoring CLI tool for Apple Silicon";
    platforms = platforms.darwin;
    license = licenses.mit;
    maintainers = with maintainers; [ juliusrickert ];
  };
}
