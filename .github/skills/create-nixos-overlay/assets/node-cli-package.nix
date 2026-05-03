{ stdenv, fetchurl, nodejs, makeWrapper, lib, cacert }:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  pname = "name";
  version = versions.version;
in
stdenv.mkDerivation rec {
  inherit pname version;

  src = fetchurl {
    url = "https://registry.npmjs.org/name/-/name-${version}.tgz";
    sha256 = versions.sha256;
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/lib/node_modules/name
    cp -r . $out/lib/node_modules/name
    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/name \
      --add-flags "$out/lib/node_modules/name/index.js" \
      --set SSL_CERT_DIR "${cacert}/etc/ssl/certs" \
      --set SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt" \
      --set NODE_EXTRA_CA_CERTS "${cacert}/etc/ssl/certs/ca-bundle.crt"
  '';

  meta = {
    description = "Node CLI description";
    homepage = "https://example.invalid";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
  };
}