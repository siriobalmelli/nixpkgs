{ lib
, buildPythonPackage
, fetchPypi
, pathspec
, pytestCheckHook
, pythonOlder
, pyyaml
}:

buildPythonPackage rec {
  pname = "yamllint";
  version = "1.26.0";
  disabled = pythonOlder "3.5";

  src = fetchPypi {
    inherit pname version;
    sha256 = "11qhs1jk9pwvyk5k3q5blh9sq42dh1ywdf1f3i2zixf7hncwir5h";
  };

  propagatedBuildInputs = [
    pyyaml
    pathspec
  ];

  checkInputs = [
    pytestCheckHook
  ];

  disabledTests = [
    "test_cli"
    "test_key_ordering"
  ];

  pythonImportsCheck = [ "yamllint" ];

  meta = with lib; {
    description = "A linter for YAML files";
    homepage = "https://github.com/adrienverge/yamllint";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ jonringer mikefaille ];
  };
}
