# Standalone home-manager niri module. Use this on non-NixOS home-manager
# (where there's no NixOS layer to configure niri). On a NixOS host, use
# flake.modules.nixos.niri instead — it sets up the system layer AND injects
# these same default settings into home-manager users, so importing this
# module there too would double-declare niri's `programs.niri.*` options.
{ inputs, ... }: {
  flake.modules.homeManager.niri =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.niri;
      defaultSettings = import ../_lib/niri-settings.nix;
    in
    {
      imports = [
        inputs.niri.homeModules.niri
      ];

      options.crann.niri = {

        package = lib.mkOption {
          type = lib.types.package;
          # Pull niri straight from the niri-flake input rather than via an
          # overlay, so this module is portable to any consumer (standalone HM,
          # useGlobalPkgs, flake-parts, plain flake) without touching their
          # nixpkgs.*. niri-unstable is used because niri-stable (25.08) fails
          # to build against nixpkgs' libdisplay-info 0.3.
          default = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
          defaultText = lib.literalExpression "inputs.niri.packages.\${system}.niri-unstable";
          description = "The niri package to use.";
        };
        extraSettings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Extra per-host niri settings merged in.";
        };

      };
      config = {

        programs.niri = {
          enable = true;
          package = cfg.package;
          settings = lib.mkMerge [
            defaultSettings
            cfg.extraSettings
          ];
        };

      };
    };
}
