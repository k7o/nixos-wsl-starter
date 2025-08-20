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
