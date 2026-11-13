#!/usr/bin/env bash
set -euo pipefail

manifest="overlays/registry.json"

usage() {
  echo "Usage: $0 --all | <overlay-directory-or-attribute>" >&2
  exit 1
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1" >&2
    exit 1
  fi
}

require_tool curl
require_tool jq
require_tool nix-prefetch-url
require_tool nix
require_tool tar

if [[ $# -ne 1 ]]; then
  usage
fi

render_template() {
  local template="$1"
  local tag="$2"
  local version="$3"
  local rendered="${template//\$\{tag\}/$tag}"
  rendered="${rendered//\$\{version\}/$version}"
  printf '%s\n' "$rendered"
}

compute_npm_deps_hash() {
  local tarball_url="$1"
  local output_lockfile="$2"
  local tmpdir
  local output_lockfile_abs
  tmpdir=$(mktemp -d)
  output_lockfile_abs=$(realpath -m "$output_lockfile")

  curl -fsSL "$tarball_url" -o "$tmpdir/package.tgz"
  tar -xzf "$tmpdir/package.tgz" -C "$tmpdir"

  if ! command -v npm >/dev/null 2>&1; then
    echo "Missing required tool for npm overlays: npm" >&2
    rm -rf "$tmpdir"
    exit 1
  fi

  (
    cd "$tmpdir/package"
    if [[ -f npm-shrinkwrap.json ]]; then
      mv npm-shrinkwrap.json npm-shrinkwrap.json.upstream
    fi
    npm install --package-lock-only --ignore-scripts --legacy-peer-deps >/dev/null
    if [[ ! -f package-lock.json ]]; then
      echo "Failed to generate package-lock.json for $tarball_url" >&2
      exit 1
    fi
    cp package-lock.json "$output_lockfile_abs"
    nix shell nixpkgs#prefetch-npm-deps.out -c prefetch-npm-deps package-lock.json
  )

  rm -rf "$tmpdir"
}

write_versions_file() {
  local directory="$1"
  local version="$2"
  local sha256="$3"
  local extra_fields_json="$4"

  jq -n \
    --arg version "$version" \
    --arg sha256 "$sha256" \
    --argjson extra "$extra_fields_json" \
    '$extra + {version: $version, sha256: $sha256}' \
    > "overlays/${directory}/versions.json"
}

# --- dotnet-release ---------------------------------------------------------
# .NET SDK overlays have no single install tarball: the package is built by
# nixpkgs' own binary SDK builder from Microsoft's release metadata, so the
# "version file" is a generated releases.nix (tarball urls + sha512s for every
# RID, plus the nuget pack hashes) rather than one url+hash pair. This mirrors
# pkgs/development/compilers/dotnet/binary/update.sh in its plain (non
# --vmr-bootstrap) mode, which is what nixpkgs uses for the -bin channels.
dotnet_rids=(
  linux-arm
  linux-arm64
  linux-x64
  linux-musl-arm
  linux-musl-arm64
  linux-musl-x64
  osx-arm64
  osx-x64
  win-arm64
  win-x64
  win-x86
)

dotnet_version_at_least() {
  local cur_version=$1 min_version=$2
  printf '%s\0%s' "$min_version" "$cur_version" | sort -zVC
}

dotnet_sri() {
  nix hash convert --to sri --hash-algo sha512 "$1"
}

dotnet_nupkg() {
  local pkg=$1 version=$2 indent=$3 url hash attempt
  url="https://api.nuget.org/v3-flatcontainer/${pkg,,}/${version,,}/${pkg,,}.${version,,}.nupkg"
  # nuget.org rate-limits bursts of HEAD requests; retry before giving up.
  for attempt in 1 2 3 4 5; do
    hash=$(curl -s --head --max-time 60 "$url" -o /dev/null -w '%header{x-ms-meta-sha512}' || true)
    [[ -n "$hash" ]] && break
    sleep "$((attempt * 2))"
  done
  if [[ -z "$hash" ]]; then
    echo "Failed to fetch nuget hash for $pkg $version" >&2
    exit 1
  fi
  printf '%s(fetchNupkg {\n' "$indent"
  printf '%s  pname = "%s";\n' "$indent" "$pkg"
  printf '%s  version = "%s";\n' "$indent" "$version"
  printf '%s  hash = "%s";\n' "$indent" "$(dotnet_sri "$hash")"
  printf '%s})\n' "$indent"
}

dotnet_sources() {
  local files_json=$1 rid url hash
  echo "    srcs = {"
  for rid in "${dotnet_rids[@]}"; do
    read -r url hash < <(jq -r --arg rid "$rid" '
      [ .[]
        | select(.rid == $rid)
        | select(.name | endswith(".tar.gz"))
        | select(.name | contains("-composite-") or contains("-pack-") | not)
      ] | first | "\(.url // "") \(.hash // "")"' <<<"$files_json")
    [[ -z "$url" || -z "$hash" ]] && continue
    echo "      $rid = {"
    echo "        url = \"$url\";"
    echo "        hash = \"$(dotnet_sri "$hash")\";"
    echo "      };"
  done
  echo "    };"
}

dotnet_common_packages() {
  local runtime_version=$1 aspnetcore_version=$2 pkg
  dotnet_nupkg Microsoft.AspNetCore.App.Ref "$aspnetcore_version" "    "
  if dotnet_version_at_least "$runtime_version" 10; then
    dotnet_nupkg Microsoft.AspNetCore.App.Internal.Assets "$aspnetcore_version" "    "
  fi
  dotnet_nupkg Microsoft.NETCore.DotNetAppHost "$runtime_version" "    "
  dotnet_nupkg Microsoft.NETCore.App.Ref "$runtime_version" "    "
  if ! dotnet_version_at_least "$runtime_version" 9; then
    for pkg in DotNetHost DotNetHostPolicy DotNetHostResolver; do
      dotnet_nupkg "Microsoft.NETCore.$pkg" "$runtime_version" "    "
    done
  fi
  if dotnet_version_at_least "$runtime_version" 7; then
    dotnet_nupkg Microsoft.DotNet.ILCompiler "$runtime_version" "    "
  fi
  if dotnet_version_at_least "$runtime_version" 8; then
    dotnet_nupkg Microsoft.NET.ILLink.Tasks "$runtime_version" "    "
  fi
}

dotnet_host_packages() {
  local rid=$1 runtime_version=$2 min_ilcompiler=
  dotnet_nupkg "Microsoft.NETCore.App.Crossgen2.$rid" "$runtime_version" "      "
  case "$rid" in
    linux-musl-arm | linux-arm | win-x86) ;;
    osx-arm64) min_ilcompiler=8 ;;
    *) min_ilcompiler=7 ;;
  esac
  if [[ -n "$min_ilcompiler" ]] && dotnet_version_at_least "$runtime_version" "$min_ilcompiler"; then
    dotnet_nupkg "runtime.$rid.Microsoft.DotNet.ILCompiler" "$runtime_version" "      "
  fi
}

dotnet_target_packages() {
  local rid=$1 runtime_version=$2 aspnetcore_version=$3 pkg
  dotnet_nupkg "Microsoft.AspNetCore.App.Runtime.$rid" "$aspnetcore_version" "      "
  dotnet_nupkg "Microsoft.NETCore.App.Host.$rid" "$runtime_version" "      "
  dotnet_nupkg "Microsoft.NETCore.App.Runtime.$rid" "$runtime_version" "      "
  dotnet_nupkg "runtime.$rid.Microsoft.NETCore.DotNetAppHost" "$runtime_version" "      "
  if ! dotnet_version_at_least "$runtime_version" 9; then
    for pkg in DotNetHost DotNetHostPolicy DotNetHostResolver; do
      dotnet_nupkg "runtime.$rid.Microsoft.NETCore.$pkg" "$runtime_version" "      "
    done
    case "$rid" in
      linux-musl-arm* | win-arm64) ;;
      *) dotnet_nupkg "Microsoft.NETCore.App.Runtime.Mono.$rid" "$runtime_version" "      " ;;
    esac
  fi
  if dotnet_version_at_least "$runtime_version" 10; then
    dotnet_nupkg "Microsoft.NETCore.App.Runtime.NativeAOT.$rid" "$runtime_version" "      "
  fi
}

# dotnet_generate <output> <channel> <releases.json> [sdk version] [select] [label]
# Writes a buildDotnetSdk-compatible metadata file and prints the version of the
# attribute named by <select> (sdk_*, runtime_* or aspnetcore_*; defaults to sdk).
dotnet_generate() {
  local output=$1 channel=$2 metadata=$3 wanted_sdk=${4:-} select=${5:-} label=${6:-dotnet}
  local underscore=${channel/./_} release_version runtime_version aspnetcore_version
  local support_phase sdk_version feature_band attr latest_sdk= rid tmp
  tmp=$(mktemp -t "dotnet-${label}-XXXXXX.nix")
  trap "rm -f '$tmp'" EXIT
  local -a sdk_versions

  if [[ -n "$wanted_sdk" ]]; then
    release_version=$(jq -er --arg sdk "$wanted_sdk" '
      first(.releases[] | select(.sdks[].version == $sdk) | ."release-version")' <<<"$metadata")
    sdk_versions=("$wanted_sdk")
  else
    release_version=$(jq -er '."latest-release"' <<<"$metadata")
    mapfile -t sdk_versions < <(jq -er --arg v "$release_version" '
      first(.releases[] | select(."release-version" == $v)) | .sdks[].version' <<<"$metadata" | sort -rV)
  fi

  if [[ -z "$release_version" ]]; then
    echo "dotnet-release: ${channel} metadata has no release for SDK ${wanted_sdk:-<latest>}" >&2
    exit 1
  fi

  local release_content version_var
  release_content=$(jq -er --arg v "$release_version" 'first(.releases[] | select(."release-version" == $v))' <<<"$metadata")
  runtime_version=$(jq -r '.runtime.version // ""' <<<"$release_content")
  aspnetcore_version=$(jq -r '."aspnetcore-runtime".version // ""' <<<"$release_content")
  support_phase=$(jq -r '."support-phase" // "unknown"' <<<"$metadata")
  for version_var in runtime_version aspnetcore_version; do
    if [[ -z "${!version_var}" ]]; then
      echo "dotnet-release: missing ${version_var} in ${channel} release ${release_version}" >&2
      exit 1
    fi
  done

  {
    echo "{"
    echo "  buildAspNetCore,"
    echo "  buildNetRuntime,"
    echo "  buildNetSdk,"
    echo "  fetchNupkg,"
    echo "}:"
    echo
    echo "# v${channel} (${support_phase}), generated by scripts/update-overlay.sh."
    echo "# Do not edit by hand; run 'just update-overlay ${label}' instead."
    echo
    echo "let"
    echo "  commonPackages = ["
    dotnet_common_packages "$runtime_version" "$aspnetcore_version"
    echo "  ];"
    echo
    echo "  hostPackages = {"
    for rid in "${dotnet_rids[@]}"; do
      echo "    $rid = ["
      dotnet_host_packages "$rid" "$runtime_version"
      echo "    ];"
    done
    echo "  };"
    echo
    echo "  targetPackages = {"
    for rid in "${dotnet_rids[@]}"; do
      echo "    $rid = ["
      dotnet_target_packages "$rid" "$runtime_version" "$aspnetcore_version"
      echo "    ];"
    done
    echo "  };"
    echo
    echo "in"
    echo "rec {"
    echo "  release_$underscore = \"$release_version\";"
    echo
    echo "  aspnetcore_$underscore = buildAspNetCore {"
    echo "    version = \"$aspnetcore_version\";"
    dotnet_sources "$(jq -e '."aspnetcore-runtime".files' <<<"$release_content")"
    echo "  };"; echo
    echo "  runtime_$underscore = buildNetRuntime {"
    echo "    version = \"$runtime_version\";"
    dotnet_sources "$(jq -e '.runtime.files' <<<"$release_content")"
    echo "  };"; echo
    local -A seen_bands=()
    for sdk_version in "${sdk_versions[@]}"; do
      feature_band="${sdk_version%-*}"
      feature_band="${feature_band:0:-2}xx"
      [[ -z "${seen_bands[$feature_band]:-}" ]] || continue
      seen_bands[$feature_band]=$sdk_version
      [[ -n "$latest_sdk" ]] || latest_sdk="sdk_${feature_band//./_}"
      echo "  sdk_${feature_band//./_} = buildNetSdk {"
      echo "    version = \"$sdk_version\";"
      dotnet_sources "$(jq -e --arg sdk "$sdk_version" 'first(.sdks[] | select(.version == $sdk)).files' <<<"$release_content")"
      echo "    inherit commonPackages hostPackages targetPackages;"
      echo "    runtime = runtime_$underscore;"
      echo "    aspnetcore = aspnetcore_$underscore;"
      echo "  };"; echo
    done
    echo "  sdk_$underscore = $latest_sdk;"
    echo "}"
  } > "$tmp"

  # Never leave a half-written releases.nix behind: a failed nuget/nix step
  # aborts above, and the destination is only replaced once the result parses.
  if command -v nix-instantiate >/dev/null 2>&1; then
    if ! nix-instantiate --parse "$tmp" >/dev/null; then
      echo "Generated ${output} does not parse" >&2
      rm -f "$tmp"
      exit 1
    fi
  fi
  mv "$tmp" "$output"

  case "$select" in
    "" | sdk_*) printf '%s' "${sdk_versions[0]}" ;;
    runtime_*) printf '%s' "$runtime_version" ;;
    aspnetcore_*) printf '%s' "$aspnetcore_version" ;;
    *)
      echo "Unsupported dotnet-release select: $select" >&2
      exit 1
      ;;
  esac
}

update_overlay() {
  local selector="$1"
  local overlay_json
  overlay_json=$(jq -cer --arg selector "$selector" '
    .overlays[]
    | select(.directory == $selector or .attribute == $selector)
  ' "$manifest") || {
    echo "Overlay not found in $manifest: $selector" >&2
    exit 1
  }

  local directory updater_type extra_fields version url hash hash_nix
  directory=$(jq -r '.directory' <<<"$overlay_json")
  updater_type=$(jq -r '.updater.type' <<<"$overlay_json")
  extra_fields=$(jq -c '.updater.extraVersionFields // {}' <<<"$overlay_json")

  case "$updater_type" in
    npm)
      local package registry_url metadata npm_deps_hash lockfile_path needs_npm_deps_hash
      package=$(jq -r '.updater.package' <<<"$overlay_json")
      registry_url="https://registry.npmjs.org/${package}"
      metadata=$(curl -fsSL "$registry_url")
      version=$(jq -r '."dist-tags".latest' <<<"$metadata")
      url=$(jq -r --arg version "$version" '.versions[$version].dist.tarball' <<<"$metadata")
      needs_npm_deps_hash=$(jq -r '(.updater.extraVersionFields // {}) | has("npmDepsHash")' <<<"$overlay_json")
      if [[ "$needs_npm_deps_hash" == "true" ]]; then
        lockfile_path="overlays/${directory}/package-lock.json"
        npm_deps_hash=$(compute_npm_deps_hash "$url" "$lockfile_path")
        extra_fields=$(jq -c --arg npmDepsHash "$npm_deps_hash" '. + {npmDepsHash: $npmDepsHash}' <<<"$extra_fields")
      fi
      ;;
    github-release)
      local repo latest_tag strip_prefix asset_template curl_args
      repo=$(jq -r '.updater.repo' <<<"$overlay_json")
      # GitHub API rate-limits unauthenticated requests to 60/hour; use a
      # token when the environment provides one.
      curl_args=(-fsSL)
      if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
      fi
      latest_tag=$(curl "${curl_args[@]}" "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name')
      strip_prefix=$(jq -r '.updater.stripPrefix // ""' <<<"$overlay_json")
      asset_template=$(jq -r '.updater.assetUrlTemplate' <<<"$overlay_json")
      version="$latest_tag"
      if [[ -n "$strip_prefix" && "$version" == "$strip_prefix"* ]]; then
        version="${version#"$strip_prefix"}"
      fi
      url=$(render_template "$asset_template" "$latest_tag" "$version")
      ;;
    dotnet-release)
      local channel metadata wanted_sdk select
      channel=$(jq -er '.updater.channel' <<<"$overlay_json")
      wanted_sdk=$(jq -r '.updater.sdkVersion // ""' <<<"$overlay_json")
      select=$(jq -r '.updater.select // ""' <<<"$overlay_json")
      metadata=$(curl -fsSL "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/${channel}/releases.json")
      version=$(dotnet_generate "overlays/${directory}/releases.nix" "$channel" "$metadata" "$wanted_sdk" "$select" "$directory") || exit 1
      if [[ -z "$version" || ! -s "overlays/${directory}/releases.nix" ]]; then
        echo "dotnet-release generation produced nothing for ${directory}" >&2
        exit 1
      fi
      jq -n --arg version "$version" '{version: $version}' > "overlays/${directory}/versions.json"
      echo "Updated overlays/${directory}/releases.nix and versions.json (${version})."
      return 0
      ;;
    *)
      echo "Unsupported updater type: $updater_type" >&2
      exit 1
      ;;
  esac

  hash=$(nix-prefetch-url --type sha256 "$url")
  hash_nix=$(nix hash convert --hash-algo sha256 "$hash")
  write_versions_file "$directory" "$version" "$hash_nix" "$extra_fields"
  echo "Updated overlays/${directory}/versions.json to ${version} (sha256: ${hash_nix})."
}

if [[ "$1" == "--all" ]]; then
  while IFS= read -r directory; do
    update_overlay "$directory"
  done < <(jq -r '.overlays[].directory' "$manifest")
else
  update_overlay "$1"
fi