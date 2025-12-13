{
  username,
  hostname,
  pkgs,
  inputs,
  ...
}: {
  time.timeZone = "Europe/Amsterdam";

  networking.hostName = "${hostname}";

  environment.variables.PYTHONWARNINGS = "ignore::FutureWarning";
  environment.enableAllTerminfo = true;
  environment.pathsToLink = [ "/share/bash-completion" ];
  
  # Provide glibc-style dynamic loader behaviour for bundled native ELF binaries
  # (enables running glibc-linked executables that expect /lib64/ld-linux-x86-64.so.2)
  programs.nix-ld.enable = true;

  security.sudo.wheelNeedsPassword = false;

  users.users.${username} = {
    isNormalUser = true;
    shell = pkgs.bashInteractive;
    extraGroups = [
      "wheel"
      # uncomment the next line if you want to run docker without sudo
      "docker"
    ];
  };

  home-manager.users.${username} = {
    imports = [
      ./home.nix
    ];
  };

  system.stateVersion = "25.11";

  wsl = {
    enable = true;
    defaultUser = username;
    startMenuLaunchers = true;
    wslConf = {
      automount.root = "/mnt";
      interop.appendWindowsPath = true;
      network.generateHosts = false;
    };
    # Enable integration with Docker Desktop (needs to be installed)
    docker-desktop.enable = true;
  };

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune.enable = true;
  };

  nix = {
    settings = {
      trusted-users = [username];
      accept-flake-config = true;
      auto-optimise-store = true;
      download-buffer-size = 1024; # MiB; bump to avoid buffer-full warnings
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
      options = "--delete-older-than 7d";
    };
  };
}
