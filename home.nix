{
  pkgs,
  username,
  nix-index-database,
  ...
}: let
  unstable-packages = with pkgs.unstable; [
    # cloud, k8s and CLI tools requested (from unstable)
    azure-cli
    azure-storage-azcopy
    crane
    git
    istioctl
    k6
    kubectl
    kubelogin
    kubernetes-helm
    kustomize
    kind
    k3d
    k9s
    kube-bench
    kubebuilder
    kubectx
    open-policy-agent
    fluxcd
    docker
    gh
    ginkgo
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

  stable-packages = with pkgs; [
    alejandra
    bat
    bottom
    cacert
    coreutils
    curl
    deadnix
    dust
    envsubst
    fd
    findutils
    fx
    gcc
    git-credential-manager
    git-crypt
    gnumake
    gnutar
    hostname-debian
    htop
    httpie
    just
    jq
    killall
    mkcert
    mosh
    neovim
    nil
    nodePackages.prettier
    nodePackages.vscode-langservers-extracted # html, css, json, eslint
    nodePackages.yaml-language-server
    operator-sdk
    procs
    python314
    ranger
    ripgrep
    rsync
    sd
    shellcheck
    shfmt
    statix
    stern
    tmux
    tree
    unzip
    wget
    yamllint
    zip
  ];
in {
  imports = [
    nix-index-database.homeModules.nix-index
  ];

  home.stateVersion = "25.11";

  home = {
    username = "${username}";
    homeDirectory = "/home/${username}";

    sessionVariables.EDITOR = "nvim";
    # FIXME: set your preferred $SHELL
    sessionVariables.SHELL = "/etc/profiles/per-user/${username}/bin/bash";

    shell.enableBashIntegration = true;
  };

  home.packages =
    stable-packages
    ++ unstable-packages
    ++
    [
      # pkgs.some-package
      # pkgs.unstable.some-other-package
    ];

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
        user = {
          email = "eric@example.com"; # FIXME: set your git email
          name = "eric"; #FIXME: set your git username
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
      };
    };
  };
}
