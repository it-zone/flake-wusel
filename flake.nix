{
  description = "Wusel — VFS-first virtual Nextcloud filesystem for Linux (FUSE + GNOME integration)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      # Wusel is Linux-only: the FUSE mount, the Nautilus extension and the
      # GNOME Shell search provider all depend on Linux-only libraries.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      # The overlay is applied to *the consumer's* nixpkgs instance, so a
      # NixOS system using it builds wusel against the very same package set
      # as the rest of the system.
      overlay = final: prev: {
        wusel = final.callPackage ./packages/wusel.nix { };
      };

      pkgsFor = system: import nixpkgs { inherit system; };

      # Smoke test for the NixOS module: evaluate a system with the module
      # enabled and make sure the per-account user units are created.
      moduleCheck =
        system:
        let
          evaluated = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.wusel
              {
                services.wusel.enable = true;
                services.wusel.accounts = [
                  "default"
                  "work"
                ];
              }
            ];
          };
          units = builtins.concatStringsSep " " (builtins.attrNames evaluated.config.systemd.user.services);
        in
        (pkgsFor system).runCommand "wusel-nixos-module-check" { } ''
          echo "user units: ${units}" > $out
        '';
    in
    {
      # Adds `pkgs.wusel` to any nixpkgs instance.
      overlays.default = overlay;
      overlays.wusel = overlay;

      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          wusel = pkgs.callPackage ./packages/wusel.nix { };
          default = pkgs.callPackage ./packages/wusel.nix { };
        }
      );

      # Full package set with the overlay applied.
      legacyPackages = forAllSystems (system: pkgsFor system);

      # NixOS module: `services.wusel.*`. The package defaults to the one
      # built from this flake's pinned nixpkgs; override `services.wusel.package`
      # to use a different build (e.g. one produced by the overlay above).
      nixosModules.wusel =
        { pkgs, ... }:
        {
          imports = [ ./modules/wusel.nix ];
          services.wusel.package =
            nixpkgs.lib.mkDefault
              self.packages.${pkgs.stdenv.hostPlatform.system}.wusel;
        };

      # The bare module, without the package default — import it together
      # with `overlays.default` (or set `services.wusel.package` yourself).
      nixosModules.wusel-module = import ./modules/wusel.nix;

      nixosModules.default = self.nixosModules.wusel;

      checks = forAllSystems (system: {
        wusel = self.packages.${system}.wusel;
        nixos-module = moduleCheck system;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.cargo
              pkgs.rustc
              pkgs.rustfmt
              pkgs.clippy
              pkgs.rust-analyzer
              pkgs.pkg-config
              pkgs.nixfmt
              pkgs.nixfmt-tree
            ];
          };
        }
      );

      # `nix fmt` runs the formatter without file arguments (only PRJ_ROOT is
      # set), so we need a tree formatter: nixfmt-tree walks the flake and
      # formats every *.nix file it finds.
      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);
    };
}
