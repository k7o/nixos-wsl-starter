{ stdenv, fetchurl, lib, autoPatchelfHook, lz4, zlib, zstd, xxhash }:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  pname = "docker-sbx";
  version = versions.version;
in
stdenv.mkDerivation rec {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/docker/sbx-releases/releases/download/v${version}/DockerSandboxes-linux-amd64.tar.gz";
    sha256 = versions.sha256;
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    lz4
    zlib
    zstd
    xxhash
    stdenv.cc.cc.lib
  ];

  sourceRoot = "docker-sbx";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec/lib

    install -m 755 sbx $out/bin/sbx

    for f in containerd-shim-nerdbox-v1; do
      install -m 755 "$f" $out/libexec/
    done

    for f in nerdbox-kernel-* nerdbox-initrd-*; do
      [ -f "$f" ] && install -m 644 "$f" $out/libexec/
    done

    install -m 755 libsailor.so $out/libexec/lib/libsailor.so

    runHook postInstall
  '';

  meta = {
    description = "Docker Sandboxes — secure, ephemeral development environments on demand";
    homepage = "https://github.com/docker/sbx-releases";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [ ];
  };
}
