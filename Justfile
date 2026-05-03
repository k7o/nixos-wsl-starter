# Minimal Justfile with only nix-related recipes
set shell := ['bash', '-lc']

# Default task
default := "rebuild"

# Update one overlay version from the shared manifest
update-overlay name:
  bash ./scripts/update-overlay.sh {{name}}

# Update all overlay versions from the shared manifest
update-all-overlays:
  bash ./scripts/update-overlay.sh --all

# Apply the system configuration from ~/configuration
rebuild: update-all-overlays
  sudo nixos-rebuild switch --flake "path:$PWD"

# Build and set as boot default without switching (use if switch fails)
boot:
  sudo nixos-rebuild boot --flake "path:$PWD"

# Build the system derivation without switching
build:
  sudo nixos-rebuild build --flake "path:$PWD"

# Update flake inputs (recreate lock file)
flake-update:
  nix flake update

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
  nix flake show --json "path:$PWD"
