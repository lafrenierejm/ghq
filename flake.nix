{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-root.flakeModule
        inputs.git-hooks.flakeModule
        inputs.treefmt-nix.flakeModule
      ];
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      perSystem =
        {
          config,
          system,
          ...
        }:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              inputs.gomod2nix.overlays.default
            ];
          };
          version = inputs.self.shortRev or "development";
          ghq = pkgs.buildGoApplication {
            inherit version;
            go = pkgs.go_1_23;
            pname = "ghq";
            pwd = ./.;
            src = ./.;
            ldflags = [
              "-s"
              "-w"
              "-X main.revision=${version}"
            ];
            meta = with pkgs.lib; {
              description = "Manage remote repository clones";
              homepage = "https://github.com/x-motemen/ghq";
              license = licenses.mit;
              maintainers = with maintainers; [ lafrenierejm ];
            };
            nativeBuildInputs = with pkgs; [ git ];
            runtimeInputs = with pkgs; [ git ];
          };
        in
        {
          # Per-system attributes can be defined here. The self' and inputs'
          # module parameters provide easy access to attributes of the same
          # system.
          packages = {
            inherit ghq;
            default = ghq;
          };

          apps.default = ghq;

          # Auto formatters. This also adds a flake check to ensure that the
          # source tree was auto formatted.
          treefmt.config = {
            projectRootFile = ".git/config";
            flakeCheck = false; # use pre-commit's check instead
            programs = {
              gofmt.enable = true;
              nixfmt.enable = true;
            };
          };

          pre-commit = {
            check.enable = true;
            settings.hooks = {
              editorconfig-checker.enable = true;
              markdownlint.enable = true;
              treefmt.enable = true;
              typos.enable = true;
            };
          };

          devShells.default = pkgs.mkShell {
            inherit (config.pre-commit.devShell) shellHook nativeBuildInputs;
            # inputsFrom = builtins.attrValues config.pre-commit.devShell;
            packages = with pkgs; [
              (mkGoEnv { pwd = ./.; })
              gomod2nix
              go-tools
              godef
              gopls
              gotools
            ];
          };
        };
    };
}
