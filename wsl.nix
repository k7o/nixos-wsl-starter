{
  username,
  hostname,
  pkgs,
  inputs,
  ...
}: {
  time.timeZone = "Europe/Amsterdam";

  networking.hostName = hostname;

  environment.variables.PYTHONWARNINGS = "ignore::FutureWarning";
  environment.pathsToLink = [ "/share/bash-completion" ];

  # Provide glibc-style dynamic loader behaviour for bundled native ELF binaries
  # (enables running glibc-linked executables that expect /lib64/ld-linux-x86-64.so.2)
  programs.nix-ld.enable = true;

  security.sudo.wheelNeedsPassword = false;

  users.users.${username} = {
    isNormalUser = true;
    linger = true;
    shell = pkgs.bashInteractive;
    extraGroups = [ "wheel" ];
  };

  users.users.root.linger = true;

  home-manager.users.${username} = {
    imports = [
      ./home.nix
    ];
  };

  system.stateVersion = "26.05";

  wsl = {
    enable = true;
    defaultUser = username;
    startMenuLaunchers = true;
    wslConf = {
      automount.root = "/mnt";
      interop.appendWindowsPath = true;
      network.generateHosts = false;
    };
    docker-desktop.enable = true;
    extraBin = [
      { src = "${pkgs.coreutils}/bin/install"; }
      { src = "${pkgs.coreutils}/bin/mv"; }
      # Docker Desktop probes the backend socket with `wsl -e test -s ...`.
      # That runs on the distro's default PATH, which includes /bin, so
      # coreutils' test must exist there or the WSL integration never comes up.
      { src = "${pkgs.coreutils}/bin/test"; }
    ];
  };

  nix = {
    settings = {
      trusted-users = [username];
      accept-flake-config = true;
      auto-optimise-store = true;
      download-buffer-size = "500000000";
    };

    registry = {
      nixpkgs = {
        flake = inputs.nixpkgs;
      };
    };

    package = pkgs.nixVersions.stable;
    extraOptions = ''experimental-features = nix-command flakes'';

    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 2d";
    };
  };
}
