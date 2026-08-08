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

        extraSettings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "noctalia-shell settings.";
        };

      };

      config = {

        programs.noctalia = {
          enable = true;
          settings = cfg.extraSettings;
        };

      };
    };
}
