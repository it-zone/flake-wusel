# flake-wusel

Standalone flake packaging [Wusel](https://github.com/itbh-at/wusel) — a
VFS-first virtual Nextcloud filesystem for Linux (FUSE + GNOME integration),
version `0.5.0`.

The package and the NixOS module used to live in a personal nixpkgs fork
(branch `wusel`, a PR against nixpkgs). This flake makes them usable on top
of an unmodified `nixpkgs` from `nixos-unstable`.

## What you get

| Output | Description |
| --- | --- |
| `packages.<system>.wusel` | the `wusel` package (Linux only) |
| `overlays.default` | adds `pkgs.wusel` to any nixpkgs instance |
| `nixosModules.wusel` | `services.wusel.*` module, package default included |
| `nixosModules.wusel-module` | the bare module (needs `pkgs.wusel` or an explicit `services.wusel.package`) |
| `checks.<system>.wusel` | builds the package |
| `checks.<system>.nixos-module` | evaluates the module and asserts the per-account user units exist |

## Usage

Build the package:

```console
nix build .#wusel
```

Use it in a dev shell:

```console
nix develop
```

Format the flake sources:

```console
nix fmt
```

`nix fmt` uses `nixfmt-tree`, which walks the whole flake and formats every
`*.nix` file it finds (the plain `nixfmt` binary cannot be used directly as a
flake formatter because `nix fmt` invokes it without file arguments).

### As a NixOS module

```nix
{
  inputs.wusel.url = "github:it-zone/flake-wusel";

  outputs = { nixpkgs, wusel, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        wusel.nixosModules.wusel
        ({ ... }: {
          services.wusel.enable = true;
          services.wusel.accounts = [ "default" "work" ];
        })
      ];
    };
  };
}
```

`nixosModules.wusel` enables the service and installs one systemd *user*
unit per entry in `services.wusel.accounts` (`wusel-default.service`,
`wusel-work.service`, …). The account must exist before the unit can mount
successfully:

```console
wusel login --account default https://cloud.example.org
systemctl --user enable --now wusel-default.service
```

The package built by this flake is used by default; override it with
`services.wusel.package` if you want a different build.

### As an overlay

```nix
{
  inputs.wusel.url = "github:it-zone/flake-wusel";

  outputs = { nixpkgs, wusel, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ ... }: {
          nixpkgs.overlays = [ wusel.overlays.default ];
          environment.systemPackages = [ wusel.packages.${system}.wusel ];
        })
      ];
    };
  };
}
```

The overlay is applied to *your* nixpkgs instance, so the package is compiled
against the same package set as the rest of your system. When using the
overlay, import the bare module (`nixosModules.wusel-module`) or point
`services.wusel.package` at `pkgs.wusel` yourself.

## Notes

- Linux only: the FUSE mount, the Nautilus extension and the GNOME Shell
  search provider all rely on Linux-only libraries.
- The Nautilus extension (`libwusel-nautilus.so`) is built from the vendored
  C sources during the package build and installed into
  `$out/lib/nautilus/extensions-4/`.
- The systemd user unit template (`wusel@.service`) is shipped in
  `$out/lib/systemd/user/`; the NixOS module generates concrete per-account
  units instead of instantiating that template.
- `meta.maintainers` is spelled out inline because upstream nixpkgs does not
  know the `ser` maintainer yet.

## License

MIT for the flake itself (see [LICENSE](LICENSE)); `wusel` itself is licensed
under ASL-2.0.
