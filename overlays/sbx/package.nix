# Recipe adopted from nixpkgs (pkgs/by-name/do/docker-sbx), with the version
# wired to versions.json so `just update-overlay sbx` keeps bumping it without
# waiting on nixpkgs. Linux-only for now: the updater tracks a single asset
# (DockerSandboxes-linux-amd64.tar.gz).
{
  lib,
  fetchurl,
  stdenvNoCC,
  installShellFiles,
  autoPatchelfHook,
  makeWrapper,
  gccForLibs,
  e2fsprogs,
  lz4,
  xxhash,
  zlib,
  zstd,
  versionCheckHook,
}:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  pname = "docker-sbx";
  version = versions.version;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/docker/sbx-releases/releases/download/v${finalAttrs.version}/DockerSandboxes-linux-amd64.tar.gz";
    sha256 = versions.sha256;
  };

  # install.sh sits inside the single top-level directory of the tarball.
  sourceRoot = "docker-sbx";

  nativeBuildInputs = [
    installShellFiles
    versionCheckHook
    autoPatchelfHook
    makeWrapper
    # install.sh refuses to run without mkfs.ext4 on PATH.
    e2fsprogs
  ];

  buildInputs = [
    lz4
    zlib
    zstd
    xxhash
    gccForLibs
  ];

  dontBuild = true;
  doInstallCheck = true;
  versionCheckProgramArg = "version";
  versionCheckKeepEnvironment = [ "HOME" ];
  preVersionCheck = ''
    export HOME=$TMPDIR
  '';

  installPhase = ''
    runHook preInstall

    PREFIX=$out bash ./install.sh

    wrapProgram $out/bin/sbx \
      --prefix PATH : ${lib.makeBinPath [ e2fsprogs ]}

    # Generate shell completions by running the installed binary; only
    # possible when building natively.
    ${lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
      export HOME=$TMPDIR
      $out/bin/sbx completion bash > sbx.bash
      $out/bin/sbx completion fish > sbx.fish
      $out/bin/sbx completion zsh > sbx.zsh
      installShellCompletion sbx.{bash,fish,zsh}
    ''}

    runHook postInstall
  '';

  meta = {
    description = "Safe environments for agents";
    longDescription = ''
      Docker Sandboxes provides sandboxes with controlled access to your
      filesystem, network, and tools. This means your agents can work
      autonomously without putting your machine or data at risk.
    '';
    homepage = "https://docs.docker.com/reference/cli/sbx/";
    changelog = "https://github.com/docker/sbx-releases/releases/tag/v${finalAttrs.version}";
    mainProgram = "sbx";
    platforms = [ "x86_64-linux" ];
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ ];
  };
})
