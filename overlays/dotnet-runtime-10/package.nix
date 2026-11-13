# Official Microsoft .NET 10 runtime, built from upstream binaries by nixpkgs'
# own binary SDK builder.
#
# Why this exists: `dotnetCorePackages.runtime_10_0-bin` from a pinned nixpkgs
# is whatever patch was current at the pinned revision (10.0.14 for the current
# lock, while 10.0.15 is out). Generating the release metadata here means
# `just update-all-overlays` tracks the latest 10.0 patch without touching
# nixpkgs.
#
# The metadata in ./releases.nix is the generated 10.0 channel data; it is the
# same content as in overlays/dotnet-aspnetcore-10 (one file per overlay keeps
# each directory self-contained) and `just update-all-overlays` regenerates both
# from a single metadata fetch. The ASP.NET Core 10 framework lives next door in
# overlays/dotnet-aspnetcore-10, same channel, same patch.
{
  unstable,
}:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  runtime = (unstable.dotnetCorePackages.buildDotnetSdk ./releases.nix).runtime_10_0;
in
  if runtime.version == versions.version
  then runtime
  else throw ''
    overlays/dotnet-runtime-10 is inconsistent: releases.nix builds ${runtime.version}
    while versions.json says ${versions.version}.
    Run `just update-overlay dotnet-runtime-10` to regenerate it.''
