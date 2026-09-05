# Run the CLI on nixpkgs nodejs from the release's platform npm package —
# the same approach as nixpkgs' github-copilot-cli, adapted to the current
# release layout:
#
# - copilot-linux-x64.tar.gz is a bun-compiled SEA binary; it segfaults when
#   autoPatchelf rewrites its interpreter to the nix glibc, and exits
#   silently inside the build sandbox. Not usable.
# - github-copilot-<version>.tgz (the "universal" package) is since ~1.0.7x
#   just an npm-loader.js that spawns a platform package.
# - github-copilot-<version>-linux-x64.tgz is the full app (index.js,
#   prebuilt native modules needing only core glibc, bundled ripgrep) —
#   exactly what the loader spawns. Running it directly on nixpkgs nodejs
#   avoids both problems.
{
  lib,
  fetchurl,
  stdenvNoCC,
  makeWrapper,
  nodejs,
  bash,
  cacert,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  pname = "github-copilot-cli";
  version = versions.version;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/github/copilot-cli/releases/download/v${finalAttrs.version}/github-copilot-${finalAttrs.version}-linux-x64.tgz";
    sha256 = versions.sha256;
  };

  sourceRoot = "package";

  dontBuild = true;

  nativeBuildInputs = [
    makeWrapper
    versionCheckHook
    writableTmpDirAsHomeHook
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/github-copilot-cli
    cp -r . $out/lib/github-copilot-cli

    # --no-auto-update: the store is immutable, so `just update-overlay
    # copilot` owns upgrades (the built-in updater would fail anyway).
    makeWrapper ${nodejs}/bin/node $out/bin/copilot \
      --add-flag $out/lib/github-copilot-cli/index.js \
      --add-flag --no-auto-update \
      --set-default NODE_NO_WARNINGS 1 \
      --set SSL_CERT_DIR "${cacert}/etc/ssl/certs" \
      --set SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt" \
      --set NODE_EXTRA_CA_CERTS "${cacert}/etc/ssl/certs/ca-bundle.crt" \
      --prefix PATH : ${lib.makeBinPath [ bash ]}
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckProgramArg = "--version";
  versionCheckKeepEnvironment = [ "HOME" ];

  meta = {
    description = "GitHub Copilot CLI";
    homepage = "https://github.com/github/copilot-cli";
    changelog = "https://github.com/github/copilot-cli/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [ ];
    mainProgram = "copilot";
  };
})
