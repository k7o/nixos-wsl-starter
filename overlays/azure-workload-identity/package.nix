{ stdenv, fetchurl, lib }:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  pname = "azure-workload-identity";
  version = versions.version;
in
stdenv.mkDerivation rec {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/Azure/azure-workload-identity/releases/download/v${version}/azwi-v${version}-linux-amd64.tar.gz";
    sha256 = versions.sha256;
  };

  sourceRoot = ".";

  installPhase = ''
    install -m755 -D azwi $out/bin/azwi
  '';

  meta = {
    description = "Azure AD Workload Identity CLI (azwi)";
    homepage = "https://azure.github.io/azure-workload-identity/docs/installation/mutating-admission-webhook.html";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [ ];
  };
}