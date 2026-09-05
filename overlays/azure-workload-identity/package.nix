{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  pname = "azure-workload-identity";
  version = versions.version;
in
# Upstream ships a statically linked Go binary; nothing to patch or build.
stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/Azure/azure-workload-identity/releases/download/v${finalAttrs.version}/azwi-v${finalAttrs.version}-linux-amd64.tar.gz";
    sha256 = versions.sha256;
  };

  sourceRoot = ".";

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -m755 -D azwi $out/bin/azwi
    runHook postInstall
  '';

  meta = {
    description = "Azure AD Workload Identity CLI (azwi)";
    homepage = "https://azure.github.io/azure-workload-identity/docs/installation/mutating-admission-webhook.html";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [ ];
    mainProgram = "azwi";
  };
})
