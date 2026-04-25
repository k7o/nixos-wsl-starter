# NixOS WSL Starter

A minimal, batteries-included starter template for running NixOS on WSL with
Home Manager for user configuration. It provides a sensible default set of
tools and a straightforward `home.nix` and `wsl.nix` you can adapt to your
workflow.

If you prefer a quick edit surface, `home.nix` is the primary place to add or
remove packages and set per-user configuration. `wsl.nix` contains WSL-specific
options (automount, interop, generateHosts, etc.) and system-level packages.

Use https://search.nixos.org/packages to look up package names when editing
`home.nix`.

Quick notes
- `unstable-packages` in this flake is for packages you want from nixpkgs
  unstable. `stable-packages` tracks the release channel used by the flake.
- Run `nix flake update` to refresh the flake inputs, then rebuild to apply
  changes.
- Read `FIXME` comments in the config files — they point to common places you
  may want to tweak.

## Quickstart

- [Install](https://nix-community.github.io/NixOS-WSL/install.html) the NixOS WSL Distribution.

- Clone the repo and edit the configuration:

```bash
git clone https://github.com/k7o/nixos-wsl-starter.git /tmp/configuration
cd /tmp/configuration
```

- Edit `wsl.nix`/`home.nix` to set your username and preferred packages.

- Apply the configuration and (optionally) restart WSL:

```bash
sudo nixos-rebuild switch --flake /tmp/configuration
# From Windows you can run: wsl --shutdown
```

- After reconnecting, move the configuration to your home directory if desired:

```bash
mv /tmp/configuration ~/configuration
sudo nixos-rebuild switch --flake ~/configuration
```

## Quick commands (Justfile)

This repository includes a minimal `Justfile` with a few Nix-focused recipes. It lives at the repo root and provides convenient wrappers for common operations. Examples:

- `just rebuild` — apply the system configuration from `~/configuration` (default)
- `just flake-update` — update flake inputs (recreates the lock file)
- `just update-and-rebuild` — update inputs then rebuild
- `just gc` — aggressive garbage collect of old store paths (destructive)

Run `just` with no arguments to list available recipes.

## Defaults in this template

- Editor: Neovim (`neovim` is included in `unstable-packages`) — set the
  `sessionVariables.EDITOR` in `home.nix` if you prefer something else.
- Shell: Bash (Home Manager installs `bashInteractive` by default here).
- Starship prompt is configured in `home.nix`.
- Docker (Linux) integration and Docker Desktop passthrough are available via
  `wsl.nix` options.

## Project layout

- `flake.nix` — flake inputs and packages (nixpkgs, nixpkgs-unstable, home-manager, etc.)
- `wsl.nix` — system-level and WSL-specific configuration
- `home.nix` — Home Manager configuration for your user (packages, dotfiles,
  environment variables, aliases)

## Managing Disk Space

NixOS keeps old generations of your configuration, and WSL2 uses a Virtual Hard Disk (`.vhdx`) that expands dynamically but does not shrink automatically. Over time, you may notice a significant loss of host disk space.

To reclaim this space, perform these two steps:

**1. Clean up the Nix Store (Inside WSL)**
Remove old, unreferenced generations using the included Justfile recipe:
```bash
just gc
```

**2. Compact the WSL Virtual Disk (On Windows)**
To return the freed space to your Windows host, you must compact the `.vhdx` file.
1. Open PowerShell as **Administrator**.
2. Shut down WSL completely:
   ```powershell
   wsl --shutdown
   ```
3. Use `diskpart` to select and compact your NixOS vhdx file (search for the file by executing `Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss | ForEach-Object { Get-ItemProperty $_.PSPath } | Select-Object DistributionName, BasePath
` , then find the entry for your NixOS distribution):
   ```powershell
   diskpart
   # In the diskpart prompt:
   select vdisk file="C:\Users\<YourUser>\AppData\Local\Packages\<NixOS_Package_Name>\LocalState\ext4.vhdx"
   compact vdisk
   exit
   ```
   *(Note: If Hyper-V is enabled, you can also use `Optimize-VHD -Path "C:\..." -Mode Full` instead of diskpart.)*
