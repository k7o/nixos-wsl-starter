{ stdenv, fetchurl, nodejs, makeWrapper, lib, cacert }:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  pname = "github-copilot-cli";
  version = versions.version;
in
stdenv.mkDerivation rec {
  inherit pname version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz";
    sha256 = versions.sha256;
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/node_modules/@github/copilot
    cp -r . $out/lib/node_modules/@github/copilot
    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/copilot \
      --add-flags "$out/lib/node_modules/@github/copilot/index.js" \
      --run 'export NPM_CONFIG_PREFIX="''${XDG_DATA_HOME:-$HOME/.local/share}/npm"' \
      --run 'export npm_config_prefix="$NPM_CONFIG_PREFIX"' \
      --run 'export NPM_CONFIG_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/npm"' \
      --run 'mkdir -p "$NPM_CONFIG_PREFIX" "$NPM_CONFIG_CACHE" "$NPM_CONFIG_PREFIX/bin"' \
      --run 'export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"' \
      --set SSL_CERT_DIR "${cacert}/etc/ssl/certs" \
      --set SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt" \
      --set NODE_EXTRA_CA_CERTS "${cacert}/etc/ssl/certs/ca-bundle.crt"
    runHook postInstall
  '';

  meta = {
    description = "Github Copilot CLI";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    homepage = "https://github.com";
  };
}
