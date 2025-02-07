{ stdenv, buildGoModule, fetchFromGitHub, lib, nix-update-script, go }:

buildGoModule rec {
  pname = "jx";
  version = "3.11.27";

  src = fetchFromGitHub {
    owner = "jenkins-x";
    repo = "jx";
    rev = "v${version}";
    sha256 = "sha256-Qh7Mjo4fwB3FF83GARLgYbQfwLmzJcOvqTAWe9XN/0I=";
  };

  vendorHash = "sha256-MJ8gYB8MQADQbhfyWHdGoGzyKPTk7LrltI3Hd2xBN0k=";

  subPackages = [ "cmd" ];

  env.CGO_ENABLED = 0;

  ldflags = [
    "-s"
    "-X github.com/jenkins-x/jx/pkg/cmd/version.Version=${version}"
    "-X github.com/jenkins-x/jx/pkg/cmd/version.Revision=${src.rev}"
    "-X github.com/jenkins-x/jx/pkg/cmd/version.GoVersion=${go.version}"
    "-X github.com/jenkins-x/jx/pkg/cmd/version.GitTreeState=clean"
    "-X github.com/jenkins-x/jx/pkg/cmd/version.BuildDate=''"
  ];

  postInstall = ''
    mv $out/bin/cmd $out/bin/jx
  '';

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    broken = stdenv.hostPlatform.isDarwin;
    description = "Command line tool for installing and using Jenkins X";
    mainProgram = "jx";
    homepage = "https://jenkins-x.io";
    changelog = "https://github.com/jenkins-x/jx/releases/tag/v${version}";
    longDescription = ''
      Jenkins X provides automated CI+CD for Kubernetes with Preview
      Environments on Pull Requests using using Cloud Native pipelines
      from Tekton.
    '';
    license = licenses.asl20;
    maintainers = with maintainers; [ kalbasit ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
