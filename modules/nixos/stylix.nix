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
# home-manager.sharedModules injection is needed here for stylix's own options.
#
# One exception: the Nerd Font symbols-only fallback (see
# modules/home/stylix.nix for why it's needed — icon glyphs like eza --icons
# and starship live in the Private Use Area, outside stylix's four font
# categories). The home-manager-class stylix module installs it directly, but
# NixOS hosts must not import that module (it'd double-declare `stylix.*`
# options via the auto-injection above), so it has to be injected here instead.
{ inputs, ... }:
{
  flake.modules.nixos.stylix =
    {
      pkgs,
      lib,
      config,
      options,
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

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            stylix = lib.mkMerge [
              (lib.mkDefault defaults)
              { enable = true; }
              cfg.extraSettings
            ];
          }
          # Only when the host actually uses the home-manager NixOS module —
          # otherwise the `home-manager.*` options don't exist and this would
          # error.
          (lib.optionalAttrs (options ? home-manager) {
            home-manager.sharedModules = [
              {
                home.packages = [ pkgs.nerd-fonts.symbols-only ];
              }
            ];
          })
        ]
      );
    };
}
