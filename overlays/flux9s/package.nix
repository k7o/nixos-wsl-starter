{ stdenv, fetchurl, lib, autoPatchelfHook, openssl }:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  pname = "flux9s";
  version = versions.version;
in
stdenv.mkDerivation rec {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/dgunzy/flux9s/releases/download/v${version}/flux9s-linux-x86_64-gnu.tar.gz";
    sha256 = versions.sha256;
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  
  buildInputs = [
    openssl
    stdenv.cc.cc.lib
  ];

  sourceRoot = ".";

  installPhase = ''
    install -m755 -D flux9s $out/bin/flux9s
  '';

  meta = {
    description = "Flux9s - A terminal UI for Flux";
    homepage = "https://github.com/dgunzy/flux9s";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [ ];
  };
}
