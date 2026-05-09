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

  # If the fetched source is already the final executable, replace `sourceRoot`
  # with `unpackPhase = ''true'';` and install `$src` directly.
  # Keep this enabled for Bun-compiled single-file executables.
  # Nix stripping removes the embedded program payload and leaves Bun help.
  # Remove it only when the upstream binary does not rely on that layout.
  dontStrip = true;

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