# Stylix, NixOS-class module. Wraps stylix's own nixosModule and layers crann's
# shared theming defaults (fonts, cursor, scheme, opacity — see
# _lib/stylix-settings.nix) on top. A host tweaks or extends the theme through
# `crann.stylix.extraSettings`, which is merged last and overrides the defaults;
# that's also how a host supplies a wallpaper, e.g.
#
#   crann.stylix.extraSettings.image = pkgs.fetchurl { url = "..."; sha256 = "..."; };
#
# When enabled, stylix's nixosModule auto-injects stylix's home-manager module
# into every home-manager user, which is what makes `stylix.targets.niri.enable`
# (declared by niri-flake's injected home stylix.nix) resolve. So no manual
# home-manager.sharedModules injection is needed here.
{ inputs, ... }:
{
  flake.modules.nixos.stylix =
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
        inputs.stylix.nixosModules.stylix
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
          { enable = true; }
          cfg.extraSettings
        ];
      };
    };
}
