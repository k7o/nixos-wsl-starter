{ buildNpmPackage, fetchurl, nodejs, makeWrapper, lib, cacert }:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  pname = "pi";
  version = versions.version;
in
buildNpmPackage rec {
  inherit pname version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    sha256 = versions.sha256;
  };

  npmDepsHash = versions.npmDepsHash;
  sourceRoot = "package";

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;
  npmFlags = [ "--legacy-peer-deps" ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/node_modules/@mariozechner/pi-coding-agent
    cp -r . $out/lib/node_modules/@mariozechner/pi-coding-agent
    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/pi \
      --add-flags "$out/lib/node_modules/@mariozechner/pi-coding-agent/dist/cli.js" \
      --set SSL_CERT_DIR "${cacert}/etc/ssl/certs" \
      --set SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt" \
      --set NODE_EXTRA_CA_CERTS "${cacert}/etc/ssl/certs/ca-bundle.crt"
    runHook postInstall
  '';

  meta = {
    description = "pi AI coding assistant CLI";
    homepage = "https://github.com/badlogic/pi-mono";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [ ];
    mainProgram = "pi";
  };
}