# Minimal Justfile with only nix-related recipes
set shell := ['bash', '-lc']

# Default task
default := "rebuild"

# Apply the system configuration from ~/configuration
rebuild:
  sudo nixos-rebuild switch --flake ~/configuration

# Build the system derivation without switching
build:
  sudo nixos-rebuild build --flake ~/configuration

# Update flake inputs (recreate lock file)
flake-update:
  nix flake update
# Update copilot versions.json to the latest upstream tarball (version + sha256)
update-copilot-version:
  @set -e
  data=$(curl -sSf 'https://registry.npmjs.org/@github/copilot') || { echo "Failed to fetch npm registry"; exit 1; }
  if command -v jq >/dev/null 2>&1; then
    version=$(printf '%s' "$data" | jq -r '(.["dist-tags"]? // {}) .latest // empty')
  else
    version=$(printf '%s' "$data" | sed -n 's/.*"latest"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  fi
  [ -n "$version" ] || { echo "Failed to detect latest copilot version"; exit 1; }
  url="https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz"
  echo "Fetching $url"
  hash=$(nix-prefetch-url --unpack "$url")
  printf '{\n  "version": "%s",\n  "sha256": "%s",\n  "npmDepsHash": ""\n}\n' "$version" "$hash" > overlays/copilot/versions.json
  git add overlays/copilot/versions.json
  git commit -m "overlays/copilot: update to copilot @$version" || true
  echo "Updated overlays/copilot/versions.json to $version (sha256: $hash)."
# Update inputs then rebuild
update-and-rebuild:
  just flake-update
  just rebuild

# Garbage collect old store paths (destructive)
gc:
  sudo nix-collect-garbage -d

# Verify store contents (quick integrity check)
verify-store:
  nix store verify

# Show flake information in JSON
flake-info:
  nix flake show --json
