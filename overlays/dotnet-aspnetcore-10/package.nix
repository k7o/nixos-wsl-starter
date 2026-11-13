# Official Microsoft ASP.NET Core 10 shared framework, built from upstream
# binaries by nixpkgs' own binary SDK builder.
#
# Why this exists: nothing else provides it. The .NET 10 SDK/runtime packages
# only carry Microsoft.NETCore.App, so a `net10.0` ASP.NET Core app fails at
# startup with "framework 'Microsoft.AspNetCore.App' version '10.0.x' was not
# found" without this. The 11.0 SDK bundles the 11.0.0 ASP.NET Core framework,
# hence only the 10.0 channel needs an overlay.
#
# ./releases.nix is the generated 10.0 channel metadata, same content as in
# overlays/dotnet-runtime-10; `just update-all-overlays` regenerates both from
# one metadata fetch. Only the selected attribute differs (aspnetcore_10_0).
{
  unstable,
}:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  aspnetcore = (unstable.dotnetCorePackages.buildDotnetSdk ./releases.nix).aspnetcore_10_0;
in
  if aspnetcore.version == versions.version
  then aspnetcore
  else throw ''
    overlays/dotnet-aspnetcore-10 is inconsistent: releases.nix builds ${aspnetcore.version}
    while versions.json says ${versions.version}.
    Run `just update-overlay dotnet-aspnetcore-10` to regenerate it.''
