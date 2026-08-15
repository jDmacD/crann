{ inputs, ... }:
{
  flake.modules.homeManager.obsidian =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.obsidian;
    in
    {
      options.crann.obsidian = {
        enable = lib.mkEnableOption "obsidian";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.obsidian;
          defaultText = lib.literalExpression "pkgs.obsidian";
          description = "The obsidian package to use.";
        };

        extraSettings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Extra obsidian settings merged over crann's defaults.";
        };

        extraVaults = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Extra obsidian vaults merged over crann's defaults.";
        };

      };
      config = lib.mkIf cfg.enable {

        programs.obsidian = {
          enable = cfg.enable;
          package = cfg.package;
          defaultSettings = lib.mkMerge [
            { }
            cfg.extraSettings
          ];
          vaults = lib.mkMerge [
            { 
              technodrome = {
                enable = true;
                target = "../../spinner/technodrome"
              };
            }
            cfg.extraVaults
          ];
          cli.enable = true;
        };

      };
    };
}
