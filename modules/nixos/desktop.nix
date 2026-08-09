# Desktop host services, NixOS class — the audio / bluetooth / power / VFS
# layer any graphical host wants, independent of which compositor runs on top.
#
# Deliberately not folded into modules/nixos/niri.nix: that module wraps
# niri-flake and is compositor-specific, whereas everything here applies just
# as much to a GNOME or Hyprland host. Userland Wayland tools (wl-clipboard and
# friends) live in the home-class counterpart, modules/home/desktop.nix.
{ ... }:
{
  flake.modules.nixos.desktop =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.desktop;
    in
    {

      options.crann.desktop = {
        enable = lib.mkEnableOption "the desktop host services (audio, bluetooth, power, gvfs)";

        audio = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to enable the pipewire audio stack.";
          };
          support32Bit = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to enable 32-bit ALSA support (wanted by Steam and other 32-bit games).";
          };
          rtkit.enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether to enable rtkit, which lets pipewire acquire realtime
              scheduling priority. Without it audio can glitch under load.
            '';
          };
        };

        bluetooth = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to enable the bluetooth stack.";
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.bluez;
            defaultText = lib.literalExpression "pkgs.bluez";
            description = "The bluez package to use.";
          };
          powerOnBoot = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to power up the bluetooth controller on boot.";
          };
          experimental = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether to enable bluez's experimental features. Required for
              battery-level reporting from bluetooth devices, which is what a
              status bar reads via upower.
            '';
          };
          blueman.enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to enable the blueman applet and its dbus service.";
          };
        };

        power.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to enable upower (battery and power-device reporting).";
        };

        gvfs.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether to enable gvfs, the userspace VFS providing trash://, mtp://,
            smb:// and friends, plus removable-media mounting. This is a system
            service: the daemons must be registered on dbus, so installing the
            gvfs package into a user profile is not equivalent.
          '';
        };
      };

      config = lib.mkIf cfg.enable {

        services.pipewire = lib.mkIf cfg.audio.enable {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = cfg.audio.support32Bit;
          pulse.enable = true;
        };

        security.rtkit.enable = lib.mkIf (cfg.audio.enable && cfg.audio.rtkit.enable) true;

        hardware.bluetooth = lib.mkIf cfg.bluetooth.enable {
          enable = true;
          package = cfg.bluetooth.package;
          powerOnBoot = cfg.bluetooth.powerOnBoot;
          settings.General.Experimental = cfg.bluetooth.experimental;
        };

        services.blueman.enable = lib.mkIf (cfg.bluetooth.enable && cfg.bluetooth.blueman.enable) true;

        services.upower.enable = lib.mkIf cfg.power.enable true;

        services.gvfs.enable = lib.mkIf cfg.gvfs.enable true;
      };
    };
}
