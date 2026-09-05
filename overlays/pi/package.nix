{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  patchelf,
  glibc,
  coreutils,
  nodejs,
  cacert,
  ripgrep,
  fd,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  pname = "pi";
  version = versions.version;
in
# Upstream ships a self-contained bun-compiled binary that bundles the whole
# workspace (including @earendil-works/pi-server, which the published npm
# package forgets to declare as a dependency). We install the official
# linux-x64 release tarball and wrap it: ripgrep/fd on PATH so pi never
# downloads its own, version check and telemetry disabled, npm prefix/cache
# redirected for `pi install`, and nix CA certs for provider requests.
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/earendil-works/pi/releases/download/v${version}/pi-linux-x64.tar.gz";
    sha256 = versions.sha256;
  };

  sourceRoot = "pi";

  nativeBuildInputs = [ makeWrapper patchelf ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/pi-coding-agent
    cp -r . $out/lib/pi-coding-agent
    mkdir -p $out/bin
    makeWrapper $out/lib/pi-coding-agent/pi $out/bin/pi \
      --prefix PATH : ${lib.makeBinPath [ nodejs ripgrep fd ]} \
      --set-default PI_SKIP_VERSION_CHECK 1 \
      --set-default PI_TELEMETRY 0 \
      --run 'export NPM_CONFIG_PREFIX="''${XDG_DATA_HOME:-$HOME/.local/share}/npm"' \
      --run 'export npm_config_prefix="$NPM_CONFIG_PREFIX"' \
      --run 'export NPM_CONFIG_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/npm"' \
      --run '"${coreutils}/bin/mkdir" -p "$NPM_CONFIG_PREFIX" "$NPM_CONFIG_CACHE" "$NPM_CONFIG_PREFIX/bin"' \
      --run 'export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"' \
      --set SSL_CERT_DIR "${cacert}/etc/ssl/certs" \
      --set SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt" \
      --set NODE_EXTRA_CA_CERTS "${cacert}/etc/ssl/certs/ca-bundle.crt"
    runHook postInstall
  '';

  # The binary uses the system loader (/lib64/ld-linux-x86-64.so.2), which is
  # absent inside the build sandbox; point it at the nix glibc loader so the
  # version check can run it (and the result is self-contained on the host).
  postFixup = ''
    patchelf --set-interpreter ${glibc}/lib/ld-linux-x86-64.so.2 \
      $out/lib/pi-coding-agent/pi
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];
  versionCheckProgram = "${placeholder "out"}/bin/pi";
  versionCheckProgramArg = "--version";
  # versionCheckPhase runs with a scrubbed environment; keep HOME (provided
  # by writableTmpDirAsHomeHook) so the wrapper's npm-prefix setup works.
  versionCheckKeepEnvironment = [ "HOME" ];

  meta = {
    description = "pi AI coding assistant CLI";
    homepage = "https://github.com/earendil-works/pi";
    changelog = "https://github.com/earendil-works/pi/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [ ];
    mainProgram = "pi";
  };
}
