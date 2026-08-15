{ inputs, ... }:
{
  flake.modules.homeManager.optnix =
    {
      options,
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.optnix;
      optnixLib = inputs.optnix.mkLib pkgs;
    in
    {
      imports = [
        inputs.optnix.homeModules.optnix
      ];

      options.crann.optnix = {
        enable = lib.mkEnableOption "optnix";

        description = lib.mkOption {
          type = lib.types.str;
          default = "home-manager configuration for ${config.home.username}";
          description = "Description shown for this scope in optnix.";
        };

        extraSettings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Extra optnix settings merged over crann's defaults (e.g. min_score, additional scopes).";
        };
      };

      config = lib.mkIf cfg.enable {

        programs.optnix = {
          enable = true;
          settings = lib.mkMerge [
            {
              # HM options are only prefixed with `home-manager.users.<name>.`
              # when this module runs through the NixOS integration
              # (useGlobalPkgs); removePrefix is a no-op in the standalone
              # case where that prefix is never present.
              scopes.home-manager = import ../_lib/optnix-scope.nix {
                inherit lib optnixLib options;
                inherit (cfg) description;
                transform =
                  o:
                  o
                  // {
                    name = lib.removePrefix "home-manager.users.${config.home.username}." o.name;
                  };
              };
            }
            cfg.extraSettings
          ];
        };

      };
    };
}
