# Repository Overlay Patterns

Current repository conventions:

- Each overlay lives in `overlays/<name>/`.
- Each overlay directory currently contains `package.nix` and `versions.json`.
- `overlays/registry.json` is the source of truth for overlay attributes, directories, and updater metadata.
- `flake.nix` derives the custom overlay list from `overlays/registry.json`.
- `Justfile` routes updates through `scripts/update-overlay.sh`, which reads `overlays/registry.json`.

Existing examples:

- `copilot` packages an npm tarball and wraps a Node entry point.
- `flux9s` packages a release tarball and uses `autoPatchelfHook` plus runtime libraries.
- `azure-workload-identity` packages a release tarball with a direct binary install.

Interpretation guidance:

- Match the nearest existing example instead of inventing a new packaging style.
- Keep naming consistent across `directory`, `attribute`, and the selector passed to `just update-overlay <name>`.
- Prefer a minimal derivation and minimal manifest metadata; only extend `scripts/update-overlay.sh` when the upstream artifact requires it.