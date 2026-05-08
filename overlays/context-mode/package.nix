{ buildNpmPackage, fetchurl, nodejs, makeWrapper, lib, cacert, python3 }:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  pname = "context-mode";
  version = versions.version;
in
buildNpmPackage rec {
  inherit pname version;

  src = fetchurl {
    url = "https://registry.npmjs.org/context-mode/-/context-mode-${version}.tgz";
    sha256 = versions.sha256;
  };

  npmDepsHash = versions.npmDepsHash;
  sourceRoot = "package";

  nativeBuildInputs = [ makeWrapper python3 ];

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;
  npmFlags = [ "--legacy-peer-deps" ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/node_modules/context-mode
    cp -r . $out/lib/node_modules/context-mode
    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/context-mode \
      --add-flags "$out/lib/node_modules/context-mode/cli.bundle.mjs" \
      --set SSL_CERT_DIR "${cacert}/etc/ssl/certs" \
      --set SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt" \
      --set NODE_EXTRA_CA_CERTS "${cacert}/etc/ssl/certs/ca-bundle.crt"
    runHook postInstall
  '';

  meta = {
    description = "Context window optimization for AI coding agents";
    homepage = "https://github.com/mksglu/context-mode";
    license = lib.licenses.elastic20;
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [ ];
    mainProgram = "context-mode";
  };
}
