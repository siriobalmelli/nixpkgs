{ lib
, buildPythonApplication
, fetchFromGitHub
, git
, pytest
, pyyaml
, setuptools
, installShellFiles
}:

buildPythonApplication rec {
  version = "0.15.9";
  pname = "gita";

  src = fetchFromGitHub {
    sha256 = "1c7pbwnrn11zimh3z78insam7dzvkzx6g0ca04cmk5gzz9m6bn30";
    rev = "v${version}";
    repo = "gita";
    owner = "nosarthur";
  };

  propagatedBuildInputs = [
    pyyaml
    setuptools
  ];

  nativeBuildInputs = [ installShellFiles ];

  postUnpack = ''
    for case in "\n" ""; do
        substituteInPlace source/tests/test_main.py \
         --replace "'gita$case'" "'source$case'"
    done
  '';

  checkInputs = [
    git
    pytest
  ];

  checkPhase = ''
    git init
    pytest -k "not test_integration" tests
  '';

  postInstall = ''
    installShellCompletion --bash --name gita ${src}/.gita-completion.bash
    installShellCompletion --zsh --name gita ${src}/.gita-completion.zsh
  '';

  meta = with lib; {
    description = "A command-line tool to manage multiple git repos";
    homepage = "https://github.com/nosarthur/gita";
    license = licenses.mit;
    maintainers = with maintainers; [ seqizz ];
  };
}
