{ stdenv, fetchurl, nodejs, lib, cacert }:
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

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/node_modules/@github/copilot
    cp -r . $out/lib/node_modules/@github/copilot
    mkdir -p $out/bin
    cat > $out/bin/copilot <<EOF
    #!${stdenv.shell}
    export NPM_CONFIG_PREFIX="\''${XDG_DATA_HOME:-\$HOME/.local/share}/npm"
    export npm_config_prefix="\$NPM_CONFIG_PREFIX"
    export NPM_CONFIG_CACHE="\''${XDG_CACHE_HOME:-\$HOME/.cache}/npm"
    mkdir -p "\$NPM_CONFIG_PREFIX" "\$NPM_CONFIG_CACHE" "\$NPM_CONFIG_PREFIX/bin"
    export PATH="\$NPM_CONFIG_PREFIX/bin:\$PATH"
    export SSL_CERT_DIR="${cacert}/etc/ssl/certs"
    export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
    export NODE_EXTRA_CA_CERTS="${cacert}/etc/ssl/certs/ca-bundle.crt"

    user_copilot="\$NPM_CONFIG_PREFIX/bin/copilot"
    if [ -x "\$user_copilot" ]; then
      exec "\$user_copilot" "\$@"
    fi

    exec ${nodejs}/bin/node "$out/lib/node_modules/@github/copilot/index.js" "\$@"
    EOF
    chmod +x $out/bin/copilot
    runHook postInstall
  '';

  meta = {
    description = "Github Copilot CLI";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    homepage = "https://github.com";
  };
}
