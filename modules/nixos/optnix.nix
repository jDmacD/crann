{ inputs, ... }:
{
  flake.modules.nixos.optnix =
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
        inputs.optnix.nixosModules.optnix
      ];

      options.crann.optnix = {
        enable = lib.mkEnableOption "optnix";

        description = lib.mkOption {
          type = lib.types.str;
          default = "NixOS configuration for ${config.networking.hostName}";
          description = "Description shown for this scope in optnix.";
        };

        evaluator = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "nix eval /path/to/flake#nixosConfigurations.myhost.config.{{ .Option }}";
          description = ''
            optnix evaluator command template used to preview live option
            values. Left as the empty string (the upstream default) to
            disable live evaluation.
          '';
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
              scopes.nixos = import ../_lib/optnix-scope.nix {
                inherit lib optnixLib options;
                inherit (cfg) description evaluator;
              };
            }
            cfg.extraSettings
          ];
        };

      };
    };
}
