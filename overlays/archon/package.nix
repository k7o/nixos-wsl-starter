{ stdenv, fetchurl, lib }:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  pname = "archon";
  version = versions.version;
in
stdenv.mkDerivation rec {
  inherit pname version;

  # Upstream distributes a Bun-compiled single-file executable. Bun runtime
  # strings inside the ELF are expected and do not indicate the wrong asset was
  # fetched.
  src = fetchurl {
    url = "https://github.com/coleam00/Archon/releases/download/v${version}/archon-linux-x64";
    sha256 = versions.sha256;
  };

  # upstream provides a single-file binary (not an archive). Skip the
  # default unpack phase and install the fetched file directly.
  unpackPhase = ''true'';
  # Bun-compiled binaries embed the program payload in the executable, so
  # stripping the file turns it back into plain Bun help output.
  dontStrip = true;

  installPhase = ''
    install -m755 -D "$src" $out/bin/archon
  '';

  meta = {
    description = "Archon - releases from the Archon project";
    homepage = "https://github.com/coleam00/Archon";
    longDescription = "Packages the upstream prebuilt Linux binary. The published release artifact is a Bun-compiled executable, so embedded Bun runtime strings are expected.";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [ ];
  };
}
