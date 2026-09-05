# Thunar, NixOS class — a GUI file manager companion for graphical crann
# hosts. Independently opt-in from crann.desktop: gvfs is turned on here too
# (not just there) so this module works even on a host that skips
# crann.desktop for some reason. nixpkgs' own `programs.thunar` module
# already sets `programs.xfconf.enable` unconditionally, so — unlike what the
# NixOS wiki's Thunar page still says to add by hand for a non-Xfce
# compositor — nothing extra is needed here to persist preferences on niri.
{ ... }:
{
  flake.modules.nixos.thunar =
    {
      pkgs,
      lib,
      config,
      options,
      ...
    }:
    let
      cfg = config.crann.thunar;
    in
    {
      options.crann.thunar = {
        enable = lib.mkEnableOption "Thunar (GUI file manager)";

        plugins = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = with pkgs; [
            thunar-archive-plugin
            thunar-volman
          ];
          defaultText = lib.literalExpression "[ pkgs.thunar-archive-plugin pkgs.thunar-volman ]";
          description = "Thunar plugins to install (archive create/extract, removable-volume automount).";
        };

        thumbnails.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to enable tumbler, so Thunar can show file thumbnails.";
        };

        setAsDefaultFileManager = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether to set Thunar as the default handler for `inode/directory`
            for home-manager users on this host (via
            `xdg.mimeApps.defaultApplications`).
          '';
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            programs.thunar = {
              enable = true;
              plugins = cfg.plugins;
            };

            services.gvfs.enable = true;
            services.tumbler.enable = cfg.thumbnails.enable;
          }
          (lib.optionalAttrs (options ? home-manager) {
            home-manager.sharedModules = lib.mkIf cfg.setAsDefaultFileManager [
              {
                xdg.mimeApps.defaultApplications."inode/directory" = [ "thunar.desktop" ];
              }
            ];
          })
        ]
      );
    };
}
