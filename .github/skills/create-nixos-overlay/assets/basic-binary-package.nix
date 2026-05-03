{ stdenv, fetchurl, lib }:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  pname = "name";
  version = versions.version;
in
stdenv.mkDerivation rec {
  inherit pname version;

  src = fetchurl {
    url = "https://example.invalid/download/${version}/name-linux-amd64.tar.gz";
    sha256 = versions.sha256;
  };

  sourceRoot = ".";

  installPhase = ''
    install -m755 -D name $out/bin/name
  '';

  meta = {
    description = "Tool description";
    homepage = "https://example.invalid";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [ ];
  };
}