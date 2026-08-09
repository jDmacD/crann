# Stylix, home-manager-class module. Use this on standalone (non-NixOS)
# home-manager. On a NixOS host, use flake.modules.nixos.stylix instead — its
# stylix nixosModule injects stylix's home module into home-manager users, so
# importing this one there too would double-declare the stylix.* options.
#
# It carries the same shared theming defaults as the nixos module (see
# _lib/stylix-settings.nix) and layers `crann.stylix.extraSettings` last, so a
# host can override any leaf or add a wallpaper via
# `crann.stylix.extraSettings.image`.
#
# It also imports niri-flake's home stylix module explicitly: on standalone
# home-manager there is no NixOS layer to inject it, and it is a separate module
# from `niri.homeModules.niri` (it declares `stylix.targets.niri.*`).
{ inputs, ... }:
{
  flake.modules.homeManager.stylix =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.stylix;
      defaults = import ../_lib/stylix-settings.nix { inherit pkgs; };
    in
    {

      imports = [
        inputs.stylix.homeModules.stylix
        inputs.niri.homeModules.stylix
      ];

      options.crann.stylix = {
        enable = lib.mkEnableOption "Stylix";
        extraSettings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Extra stylix settings merged over crann's defaults (e.g. `image`, `base16Scheme`).";
        };
      };

      config = lib.mkIf cfg.enable {
        stylix = lib.mkMerge [
          (lib.mkDefault defaults)
          {
            enable = true;
            # autoEnable turns on every target regardless of whether the program
            # is present; we run niri, so keep stylix out of hyprland's options.
            targets.hyprland.enable = lib.mkDefault false;
            targets.niri.enable = lib.mkDefault true;
          }
          cfg.extraSettings
        ];
      };
    };
}
