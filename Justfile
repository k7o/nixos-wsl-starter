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
  #!/usr/bin/env bash
  version=$(curl -s 'https://registry.npmjs.org/@github/copilot' | jq -r '."dist-tags".latest')
  url="https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz"
  hash=$(nix-prefetch-url --type sha256 "$url")
  hash_nix=$(nix hash convert --hash-algo sha256 $hash)
  printf '{\n  "version": "%s",\n  "sha256": "%s",\n  "npmDepsHash": ""\n}\n' "$version" "$hash_nix" > overlays/copilot/versions.json
  echo "Updated overlays/copilot/versions.json to $version (sha256: $hash_nix)."

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
