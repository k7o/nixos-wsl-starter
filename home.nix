{
  pkgs,
  lib,
  username,
  nix-index-database,
  ...
}: let
  custom-packages = with pkgs.custom; [
    copilot-cli
    flux9s
    azure-workload-identity
    sbx
    pi
    # archon
    # some-package
  ];

  stable-packages = with pkgs; [
    aks-mcp-server
    basez
    bat
    bottom
    cacert
    coreutils
    curl
    deadnix
    dust
    e2fsprogs
    envsubst
    erofs-utils
    eza
    fd
    findutils
    fx
    gcc
    ginkgo
    git-crypt
    git-filter-repo
    gnome-keyring
    gnumake
    gnutar
    hostname-debian
    htop
    httpie
    just
    jq
    k3d
    killall
    kubeconform
    libsecret
    mkcert
    mosh
    neovim
    nil
    prettier
    vscode-langservers-extracted # html, css, json, eslint
    yaml-language-server
    operator-sdk
    procs
    (python314.withPackages (ps: [ ps.pip ]))
    ranger
    ripgrep
    rsync
    sd
    shellcheck
    shfmt
    socat
    statix
    stern
    tmux
    tree
    unzip
    wget
    yamllint
    yarn
    yq-go
    zip
  ];

  unstable-packages = with pkgs.unstable; [
    # cloud, k8s and CLI tools requested (from unstable)
    azure-cli
    azure-storage-azcopy
    bun
    crane
    fluxcd-operator-mcp
    git
    gnupg
    istioctl
    herdr
    hubble
    k6
    kubectl
    kubelogin
    kubernetes-helm
    kustomize
    kind
    k9s
    kube-bench
    kubebuilder
    kubectx
    open-policy-agent
    fluxcd
    docker
    regal
    openssl
    cilium-cli
    oras
    sops
    step-cli
    trivy
    powershell
    (with dotnetCorePackages; combinePackages [
      sdk_10_0
      runtime_9_0-bin
      runtime_8_0-bin
    ])
    # .NET development - use latest from unstable
    # dotnetCorePackages.sdk_10_0-bin
    go
    golangci-lint
    nodejs_24
  ];

in {
  imports = [
    nix-index-database.homeModules.nix-index
  ];

  home.stateVersion = "26.05";

  home = {
    username = username;
    homeDirectory = "/home/${username}";

    sessionVariables.EDITOR = "nvim";
    sessionVariables.SHELL = "/etc/profiles/per-user/${username}/bin/bash";

    shell.enableBashIntegration = true;
  };

  home.packages =
    custom-packages
    ++ stable-packages
    ++ unstable-packages;

  # Auto-start gnome-keyring secret service
  services.gnome-keyring = {
    enable = true;
    components = [ "secrets" ];
  };

  programs = {
    home-manager.enable = true;
    nix-index.enable = true;
    nix-index-database.comma.enable = true;

    bash = {
      enable = true;
      enableCompletion = true;
      initExtra = ''
        if command -v kubectl >/dev/null 2>&1; then
          # generate and source the kubectl completion function, ignore errors
          source <(kubectl completion bash) 2>/dev/null || true
          complete -o default -F __start_kubectl k
        fi
      '';
      sessionVariables = {
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        NODE_EXTRA_CA_CERTS = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
      shellAliases = {
        vi = "nvim";
        vim = "nvim";
        jvim = "nvim";
        lvim = "nvim";
        pbcopy = "/mnt/c/Windows/System32/clip.exe";
        pbpaste = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -command \"Get-Clipboard\"";
        explorer = "/mnt/c/Windows/explorer.exe";
        k = "kubectl";
        agent = "just -d \"$(pwd)\" -f ~/.sbx-justfile";
        ls = "eza -lh --group-directories-first --icons=auto";
        lsa = "ls -a";
        lt = "eza --tree --level=2 --long --icons --git";
        lta = "lt -a";
      };
    };

    starship = {
      enable = true;
      settings = {
        azure.disabled = false;
        aws.disabled = true;
        gcloud.disabled = true;
        kubernetes.disabled = false;
        git_branch.style = "242";
        directory.style = "blue";
        directory.truncate_to_repo = false;
        directory.truncation_length = 8;
        python.disabled = true;
        ruby.disabled = true;
        hostname.ssh_only = false;
        hostname.style = "bold green";
      };
    };
    delta = {
      enable = true;
      options = {
        line-numbers = true;
        side-by-side = true;
        navigate = true;
      };
    };
    git = {
      enable = true;
      package = pkgs.unstable.git;
      settings = {
        # Personal identity (user.name, user.email, ...) lives in an untracked
        # ~/.gitconfig.local so it never lands in this public repo. Create the
        # file with contents like:
        #
        #   [user]
        #       name  = Eric
        #       email = someone@example.com
        #
        # Git silently ignores the include when the file is absent.
        include = {
          path = "~/.gitconfig.local";
        };
        credential = {
          helper = "/mnt/c/Program\\ Files/Git/mingw64/bin/git-credential-manager.exe";
          "https://dev.azure.com" = {
            useHttpPath = true;
          };
        };
        push = {
          default = "current";
          autoSetupRemote = true;
        };
        merge = {
          conflictstyle = "diff3";
        };
        diff = {
          colorMoved = "default";
        };
        init = {
          defaultBranch = "main";
        };
      };
    };
    gh = {
      enable = true;
      gitCredentialHelper = {
        enable = false;
      };
    };
  };
}
