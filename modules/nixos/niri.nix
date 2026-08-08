# niri, NixOS-class module. Wraps niri-flake's own `nixosModules.niri`, which
# provides the system layer that the home-manager module (modules/home/niri.nix)
# deliberately cannot: `xdg.portal.enable` + the gnome portal (required by
# nix-flatpak's assertion and screencast), the display-manager session entry,
# polkit + a polkit agent, gnome-keyring, dconf, and the niri binary cache.
#
# Use this alongside `flake.modules.homeManager.niri` on a NixOS host: this
# module is the system layer, that one is the per-user config. They live in
# different option trees (NixOS vs home-manager), so the shared `crann.niri`
# namespace does not collide.
#
# The package default is pulled straight from the niri input (niri-unstable,
# same rationale as the home module) rather than via an overlay, keeping the
# module portable — see CLAUDE.md.
{ inputs, ... }:
{
  flake.modules.nixos.niri =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.niri;
    in
    {
      imports = [
        inputs.niri.nixosModules.niri
      ];

      options.crann.niri = {

        enable = lib.mkEnableOption "the niri NixOS system layer (portal, session, polkit, keyring)" // {
          default = true;
        };

        package = lib.mkOption {
          type = lib.types.package;
          # niri-unstable, matching the home module: niri-stable (25.08) fails to
          # build against nixpkgs' libdisplay-info 0.3. Pulled from the input so
          # this module never touches the consumer's nixpkgs.*.
          default = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
          defaultText = lib.literalExpression "inputs.niri.packages.\${system}.niri-unstable";
          description = "The niri package to use (system-level).";
        };

      };

      config = lib.mkIf cfg.enable {
        programs.niri = {
          enable = true;
          package = cfg.package;
        };
      };
    };
}
