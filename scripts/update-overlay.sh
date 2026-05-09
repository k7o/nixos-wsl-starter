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
    npm install --package-lock-only --ignore-scripts --legacy-peer-deps >/dev/null
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
      local repo latest_tag strip_prefix asset_template
      repo=$(jq -r '.updater.repo' <<<"$overlay_json")
      latest_tag=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name')
      strip_prefix=$(jq -r '.updater.stripPrefix // ""' <<<"$overlay_json")
      asset_template=$(jq -r '.updater.assetUrlTemplate' <<<"$overlay_json")
      version="$latest_tag"
      if [[ -n "$strip_prefix" && "$version" == "$strip_prefix"* ]]; then
        version="${version#"$strip_prefix"}"
      fi
      url=$(render_template "$asset_template" "$latest_tag" "$version")
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