{ inputs, ... }:
{
  flake.modules.homeManager.nix-utils =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.nix-utils;
    in
    {
      options.crann.nix-utils = {
        enable = lib.mkEnableOption "nix-utils";

        packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = with pkgs; [
            cachix
            deploy-rs
            nixos-rebuild-ng
            nixos-anywhere
          ];
          defaultText = lib.literalExpression "[ cachix deploy-rs nixos-rebuild-ng nixos-anywhere ]";
          description = "The nix-utils tools to install. Replaces crann's default set.";
        };

        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          example = lib.literalExpression "[ pkgs.disko ]";
          description = "Extra packages installed alongside `packages`.";
        };

        nh = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to install and configure nh (Nix Helper).";
          };

          flakePath = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "/home/user/my-flake";
            description = ''
              Path to the flake nh should operate on, used for both
              `programs.nh.flake` (NixOS) and `programs.nh.darwinFlake`
              (nix-darwin). Left unset (null) if not provided.
            '';
          };
        };
      };
      config = lib.mkIf cfg.enable {

        home.packages = cfg.packages ++ cfg.extraPackages;

        programs.nh = {
          enable = cfg.nh.enable;
          flake = cfg.nh.flakePath;
          darwinFlake = cfg.nh.flakePath;
        };

      };
    };
}
