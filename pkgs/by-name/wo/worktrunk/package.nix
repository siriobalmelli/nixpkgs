{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  git,
  installShellFiles,
  testers,
  versionCheckHook,
  worktrunk,
  nix-update-script,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "worktrunk";
  version = "0.28.2";

  src = fetchFromGitHub {
    owner = "max-sixty";
    repo = "worktrunk";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ftuZP5nmdUoSZLzbHVMwNkOeVr0ZSmtXfcL5w/xXBUg=";
  };

  cargoHash = "sha256-jAf9rTKZGiNsbkj08HPzceGsXevvFjd98FNcARB7gww=";

  cargoBuildFlags = [ "--package=worktrunk" ];

  # vergen-gitcl calls `git describe` at build time; VERGEN_IDEMPOTENT makes it
  # fall back gracefully when no git history is available (Nix sandbox).
  env.VERGEN_IDEMPOTENT = "1";

  nativeBuildInputs = [
    installShellFiles
  ];

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    # wt reads config from $HOME; provide a throwaway dir so it doesn't fail.
    export HOME="$(mktemp -d)"

    installShellCompletion --cmd wt \
      --bash <($out/bin/wt config shell completions bash) \
      --fish <($out/bin/wt config shell completions fish) \
      --zsh  <($out/bin/wt config shell completions zsh)
  '';

  nativeCheckInputs = [ git ];

  checkFlags = [
    # Expects to run inside a git repository
    "--skip=git::recover::tests::test_current_or_recover_returns_repo_when_cwd_exists"
    # Insta snapshot mismatch across git versions
    "--skip=git::recover::tests::test_hint_for_repo_suggests_switch"
    # Expects `which` on PATH
    "--skip=output::commit_generation::tests::test_command_exists_known_command"
    # Integration tests use insta snapshots with environment-specific paths
    "--skip=integration_tests::"
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    tests.version = testers.testVersion { package = worktrunk; };
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Git worktree manager for parallel AI agent workflows";
    homepage = "https://github.com/max-sixty/worktrunk";
    changelog = "https://github.com/max-sixty/worktrunk/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "wt";
    maintainers = with lib.maintainers; [ siriobalmelli ];
  };
})
