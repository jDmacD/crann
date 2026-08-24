# gdm, NixOS-class module — enables GDM as the system display manager.
#
# Ported from blueprint's nix/modules/nixos/gdm.nix. The source module also
# carried a `defaultSession = "hyprland-uwsm"` plus a `programs.uwsm`
# Hyprland-compositor registration; both were dropped here as stale —
# blueprint moved off Hyprland to niri (crann.niri.enable) and nothing in its
# tree registers a Hyprland login session anymore. `defaultSession` here
# defaults to niri's own session instead and stays overridable for consumers
# that do run a different compositor.
{ ... }:
{
  flake.modules.nixos.gdm =
    {
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.gdm;
    in
    {
      options.crann.gdm = {
        enable = lib.mkEnableOption "gdm as the system display manager";

        defaultSession = lib.mkOption {
          type = lib.types.str;
          default = "niri";
          description = "The session name GDM preselects on the login screen.";
        };
      };

      config = lib.mkIf cfg.enable {
        services.displayManager = {
          gdm.enable = true;
          defaultSession = cfg.defaultSession;
        };
      };
    };
}
