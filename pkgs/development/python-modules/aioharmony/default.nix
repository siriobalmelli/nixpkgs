{
  lib,
  aiohttp,
  async-timeout,
  buildPythonPackage,
  fetchPypi,
  pythonOlder,
  slixmpp,
}:

buildPythonPackage rec {
  pname = "aioharmony";
  version = "0.2.10";
  format = "setuptools";

  disabled = pythonOlder "3.6";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-18+38QunEdEGdirQOT+528vYqiqDuUr/CWRQtXKf4rs=";
  };

  propagatedBuildInputs = [
    aiohttp
    async-timeout
    slixmpp
  ];

  # aioharmony does not seem to include tests
  doCheck = false;

  pythonImportsCheck = [
    "aioharmony.harmonyapi"
    "aioharmony.harmonyclient"
  ];

  meta = with lib; {
    homepage = "https://github.com/ehendrix23/aioharmony";
    description = "Python library for interacting the Logitech Harmony devices";
    mainProgram = "aioharmony";
    license = licenses.asl20;
    maintainers = with maintainers; [ oro ];
  };
}
