{ inputs, ... }:
{
  flake.modules.homeManager.obsidian =
    {
      pkgs,
      lib,
      config,
      options,
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
      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
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
                    target = "obsidian/technodrome";
                  };
                }
                cfg.extraVaults
              ];
              cli.enable = true;
            };
          }

          # Stylix's obsidian target (enabled by crann.stylix's autoEnable)
          # symlinks its settings into each vault's .obsidian/ from the Nix store.
          # claude-obsidian rejects any vault path that resolves outside the
          # vault, so adopt/init and every write fail with PATH_OUTSIDE_VAULT.
          # Off by default; a host without claude-obsidian can turn it back on.
          (lib.optionalAttrs (options ? stylix.targets.obsidian) {
            stylix.targets.obsidian.enable = lib.mkDefault false;
          })
        ]
      );
    };
}
