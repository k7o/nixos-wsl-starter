---
name: create-nixos-overlay
description: 'Create a new Nix overlay package under overlays/, register it in overlays/registry.json, and keep updates flowing through the generic Justfile updater. Use when adding another packaged tool to this repository.'
argument-hint: 'Overlay name, upstream source, binary/package details, and manifest metadata for overlays/registry.json'
user-invocable: true
disable-model-invocation: false
---

# Create NixOS Overlay

Use this skill when you need to add another packaged tool under `overlays/`, register it in `overlays/registry.json`, and keep the update workflow in `Justfile` consistent through the shared updater script.

## Outcome

This skill should produce:
- A new `overlays/<name>/package.nix`
- A new `overlays/<name>/versions.json`
- A new manifest entry in `overlays/registry.json`
- A generic update path in `Justfile` that can update one overlay or all overlays
- Reusable templates for `package.nix`, `versions.json`, and updater metadata
- Validation that the manifest-driven wiring still evaluates cleanly

## Inputs To Gather

Collect these before editing:
- Overlay attribute name and directory name
- Upstream source type: GitHub release asset, npm tarball, or direct download URL
- Installed binary name or package entry point
- Runtime/build inputs needed by the derivation
- Manifest updater metadata for `overlays/registry.json`

If any of those are missing, ask only for the missing values.

## Procedure

1. Inspect `overlays/registry.json`, at least one neighboring overlay directory, and the shared updater flow in `Justfile` plus `scripts/update-overlay.sh`.
2. Pick the closest existing packaging pattern for the new overlay.
3. Create `overlays/<name>/versions.json` with the fields required by the upstream source, using the bundled template as the starting point.
4. Create `overlays/<name>/package.nix` using the smallest derivation shape that matches the artifact and the bundled template that best fits:
   - Use `fetchurl` for direct release assets or tarballs.
   - Use `sourceRoot = ".";` when the archive extracts into the working directory.
   - Add `autoPatchelfHook`, `openssl`, `nodejs`, `makeWrapper`, or other inputs only when the artifact actually needs them.
5. Add one entry to `overlays/registry.json` with the overlay attribute, directory, updater type, and updater-specific metadata.
6. Keep the generic updater command in `Justfile` and extend manifest metadata only when the new overlay needs more information:
  - `just update-overlay <name>` updates a single overlay.
  - `just update-all-overlays` iterates over manifest entries.
7. Validate the touched files with the narrowest available check.
8. End with a brief note if the new overlay required extending the generic updater.

## Decision Points

### Source Type

- GitHub release asset:
  - Pull the latest tag from the GitHub releases API.
  - Normalize the version string if the tag has a leading `v`.
  - Prefetch the release asset and convert the hash with `nix hash convert`.
- npm package tarball:
  - Pull the latest version from the npm registry.
  - Fetch the tarball URL for that version.
  - Add wrapper logic if the package is executed via `node`.
- Other direct download:
  - Use the upstream endpoint that returns a stable latest version or explicit version metadata.
  - Store only the fields needed to reproduce the fetch.

### Packaging Shape

- Single extracted binary: install with `install -m755 -D binary $out/bin/<name>`.
- Node CLI tarball: copy into `$out/lib/node_modules/...` and wrap the entry point.
- Dynamically linked binary: add `autoPatchelfHook` and runtime libraries only when required.

### Better Way?

This repository already uses the better way: a shared manifest and generic updater.

Use this structure:

```json
{
  "overlays": [
    {
      "attribute": "copilot-cli",
      "directory": "copilot",
      "updater": {
        "type": "npm",
        "package": "@github/copilot",
        "extraVersionFields": {
          "npmDepsHash": ""
        }
      }
    }
  ]
}
```

`flake.nix` derives custom overlays from that registry, and `scripts/update-overlay.sh` uses the same metadata to update `versions.json`.

## Completion Checks

The task is complete when all of these are true:
- `overlays/<name>/package.nix` and `overlays/<name>/versions.json` exist and match an existing repo pattern
- `overlays/registry.json` contains the new overlay entry
- `flake.nix` still evaluates successfully from the manifest-driven overlay list
- `Justfile` still routes through the generic updater path
- Validation for the touched slice has been run, or the environment limitation is stated explicitly
- The response notes any new updater metadata or generic updater extension that was required

## Repository Notes

Load [repo-patterns](./references/repo-patterns.md) for the current conventions before editing.

## Templates

Start from these bundled templates when creating new files:
- [Basic binary package](./assets/basic-binary-package.nix)
- [Node CLI package](./assets/node-cli-package.nix)
- [Versions template](./assets/versions.json)
- [Overlay manifest entry](./assets/overlay-registry-entry.json)
- [Generic updater recipe](./assets/update-overlay.just)