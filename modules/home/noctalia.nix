# Noctalia shell, migrated from blueprint. Barebones for now — settings and
# wallpaper handling are being refactored for noctalia 5.
# See CLAUDE.md for the conventions this follows.
{ inputs, ... }:
{
  flake.modules.homeManager.noctalia =
    {
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.noctalia;
    in
    {
      imports = [
        inputs.noctalia.homeModules.default
      ];

      options.crann.noctalia = {

        enable = lib.mkEnableOption "the noctalia shell";

        extraSettings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "noctalia-shell settings.";
        };

      };

      config = lib.mkIf cfg.enable {

        programs.noctalia = {
          enable = true;
          settings = lib.mkMerge [
            {
              bar.default.start = [
                "launcher"
                "wallpaper"
                "screenshot"
                "workspaces"
              ];
            }
            cfg.extraSettings
          ];
        };

      };
    };
}
